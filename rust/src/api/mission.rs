use anyhow::anyhow;
use futures_util::SinkExt;
use nalgebra::Vector3;
use postcard::to_allocvec;
use std::{sync::Arc, time::Duration};
use tokio::{select, sync::watch, time::sleep};
use tracing_subscriber::filter::LevelFilter;
use zenoh::{prelude::r#async::*, publication::Publisher};

use argus_common::{ControlRequest, ControlResponse, GlobalPosition, MissionNode, Waypoint};

use crate::{api::util::ingest, frb_generated::StreamSink};

use super::util::{publisher, subscriber, watch_stream, PrintError};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    tracing_subscriber::fmt()
        .with_max_level(LevelFilter::INFO)
        .init();
}

pub struct CoreConnection {
    mission: Publisher<'static>,
    control: Publisher<'static>,
    control_stream: watch::Receiver<FlutterControlResponse>,
    pos_stream: watch::Receiver<PositionTriple>,
    online_stream: watch::Receiver<bool>,
    step_stream: watch::Receiver<i32>,
}

impl CoreConnection {
    pub async fn init(machine: String) -> anyhow::Result<Self> {
        let t = |o: &str| format!("{machine}/{o}");
        let zconfig = zenoh::config::default();

        let session = Arc::new(zenoh::open(zconfig).res().await.map_err(|e| anyhow!(e))?);

        let pos_sub = subscriber(session.clone(), &t("position")).await?;
        let step_sub = subscriber(session.clone(), &t("mission/step")).await?;
        let control_sub = subscriber(session.clone(), &t("control/out")).await?;
        let mission_upd_pub = publisher(session.clone(), &t("mission/update")).await?;
        let control_pub = publisher(session, &t("control/in")).await?;

        let (pos_snd, pos_rcv) = watch::channel(PositionTriple {
            x: 50.0,
            y: 30.0,
            z: 10.0,
        });

        let (step_snd, step_rcv) = watch::channel(0);
        let (online_snd, online_rcv) = watch::channel(false);
        let (control_snd, control_rcv) =
            watch::channel(FlutterControlResponse::SendMissionPlan(vec![]));

        tokio::spawn(async move {
            loop {
                select! {
                    pos = pos_sub.recv_async() => {
                        ingest::<GlobalPosition, PositionTriple>(pos, &pos_snd, &online_snd).print_error();
                    }
                    step = step_sub.recv_async() => {
                        ingest::<i32, i32>(step, &step_snd, &online_snd).print_error();
                    }
                    control = control_sub.recv_async() => {
                        ingest::<ControlResponse, FlutterControlResponse>(control, &control_snd, &online_snd).print_error();
                    }
                    _ = sleep(Duration::from_secs(1)) => {
                        let _ = online_snd.send(false);
                    },
                }
                sleep(Duration::from_millis(10)).await;
            }
        });

        Ok(Self {
            mission: mission_upd_pub,
            control: control_pub,
            pos_stream: pos_rcv,
            online_stream: online_rcv,
            step_stream: step_rcv,
            control_stream: control_rcv,
        })
    }

    pub async fn send_mission_plan(&mut self, plan: Vec<FlutterMissionNode>) -> anyhow::Result<()> {
        let plan: Vec<MissionNode> = plan.into_iter().map(Into::into).collect();

        let plan = to_allocvec(&plan)?;

        self.mission.send(&*plan).await.map_err(|e| anyhow!(e))?;

        Ok(())
    }

    pub async fn send_control(&mut self, req: FlutterControlRequest) -> anyhow::Result<()> {
        let control: ControlRequest = req.into();
        let control = to_allocvec(&control)?;

        self.control.send(&*control).await.map_err(|e| anyhow!(e))?;

        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_pos(&self, sink: StreamSink<PositionTriple>) -> anyhow::Result<()> {
        watch_stream(self.pos_stream.clone(), sink).await;
        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_step(&self, sink: StreamSink<i32>) -> anyhow::Result<()> {
        watch_stream(self.step_stream.clone(), sink).await;
        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_control(
        &self,
        sink: StreamSink<FlutterControlResponse>,
    ) -> anyhow::Result<()> {
        watch_stream(self.control_stream.clone(), sink).await;
        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_online(&self, sink: StreamSink<bool>) -> anyhow::Result<()> {
        watch_stream(self.online_stream.clone(), sink).await;
        Ok(())
    }
}

#[derive(Debug, Clone)]
pub enum FlutterControlRequest {
    FetchMissionPlan,
}

impl From<FlutterControlRequest> for ControlRequest {
    fn from(value: FlutterControlRequest) -> Self {
        match value {
            FlutterControlRequest::FetchMissionPlan => ControlRequest::FetchMissionPlan,
        }
    }
}

#[derive(Debug, Clone)]
pub enum FlutterControlResponse {
    SendMissionPlan(Vec<FlutterMissionNode>),
}

impl From<ControlResponse> for FlutterControlResponse {
    fn from(value: ControlResponse) -> Self {
        match value {
            ControlResponse::SendMissionPlan(plan) => {
                FlutterControlResponse::SendMissionPlan(plan.into_iter().map(Into::into).collect())
            }
        }
    }
}

#[derive(Debug, Clone)]
pub struct PositionTriple {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl From<GlobalPosition> for PositionTriple {
    fn from(value: GlobalPosition) -> Self {
        Self {
            x: value.lat,
            y: value.lon,
            z: value.alt as f64,
        }
    }
}

#[derive(Debug, Clone)]
pub enum FlutterMissionNode {
    Init,
    Takeoff { altitude: f64 },
    Waypoint(FlutterWaypoint),
    Delay(f64),
    FindSafeSpot,
    Transition,
    Land,
    PrecLand,
    End,
}

impl From<FlutterMissionNode> for MissionNode {
    fn from(value: FlutterMissionNode) -> Self {
        match value {
            FlutterMissionNode::Init => MissionNode::Init,
            FlutterMissionNode::Takeoff { altitude } => MissionNode::Takeoff { altitude },
            FlutterMissionNode::Waypoint(w) => MissionNode::Waypoint(w.into()),
            FlutterMissionNode::Delay(s) => MissionNode::Delay(Duration::from_secs_f64(s)),
            FlutterMissionNode::FindSafeSpot => MissionNode::FindSafeSpot,
            FlutterMissionNode::Transition => MissionNode::Transition,
            FlutterMissionNode::Land => MissionNode::Land,
            FlutterMissionNode::PrecLand => MissionNode::PrecLand,
            FlutterMissionNode::End => MissionNode::End,
        }
    }
}

impl From<MissionNode> for FlutterMissionNode {
    fn from(value: MissionNode) -> Self {
        match value {
            MissionNode::Init => FlutterMissionNode::Init,
            MissionNode::Takeoff { altitude } => FlutterMissionNode::Takeoff { altitude },
            MissionNode::Waypoint(wp) => FlutterMissionNode::Waypoint(wp.into()),
            MissionNode::Delay(d) => FlutterMissionNode::Delay(d.as_secs_f64()),
            MissionNode::FindSafeSpot => FlutterMissionNode::FindSafeSpot,
            MissionNode::Transition => FlutterMissionNode::Transition,
            MissionNode::Land => FlutterMissionNode::Land,
            MissionNode::PrecLand => FlutterMissionNode::PrecLand,
            MissionNode::End => FlutterMissionNode::End,
        }
    }
}

#[derive(Debug, Clone)]
pub enum FlutterWaypoint {
    LocalOffset(f64, f64, f64),
    GlobalFixedHeight {
        lat: f64,
        lon: f64,
        alt: f64,
    },
    GlobalRelativeHeight {
        lat: f64,
        lon: f64,
        height_diff: f64,
    },
}

impl From<FlutterWaypoint> for Waypoint {
    fn from(value: FlutterWaypoint) -> Self {
        match value {
            FlutterWaypoint::LocalOffset(x, y, z) => Waypoint::LocalOffset(Vector3::new(x, y, z)),
            FlutterWaypoint::GlobalFixedHeight { lat, lon, alt } => {
                Waypoint::GlobalFixedHeight { lat, lon, alt }
            }
            FlutterWaypoint::GlobalRelativeHeight {
                lat,
                lon,
                height_diff,
            } => Waypoint::GlobalRelativeHeight {
                lat,
                lon,
                height_diff,
            },
        }
    }
}

impl From<Waypoint> for FlutterWaypoint {
    fn from(value: Waypoint) -> Self {
        match value {
            Waypoint::LocalOffset(v) => FlutterWaypoint::LocalOffset(v.x, v.y, v.z),
            Waypoint::GlobalFixedHeight { lat, lon, alt } => {
                FlutterWaypoint::GlobalFixedHeight { lat, lon, alt }
            }
            Waypoint::GlobalRelativeHeight {
                lat,
                lon,
                height_diff,
            } => FlutterWaypoint::GlobalRelativeHeight {
                lat,
                lon,
                height_diff,
            },
        }
    }
}
