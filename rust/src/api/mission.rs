use anyhow::anyhow;
use flutter_rust_bridge::frb;
use futures_util::SinkExt;
use nalgebra::Vector3;
use postcard::to_allocvec;
use rerun::Color;
use std::{sync::Arc, time::Duration};
use tokio::{select, sync::watch, time::sleep};
use tracing_subscriber::filter::LevelFilter;
use zenoh::{prelude::r#async::*, publication::Publisher};

use argus_common::{
    ControlRequest, ControlResponse, GlobalPosition, LocalPosition, MissionNode, Waypoint,
};

use crate::{frb_generated::StreamSink, visualize};

use super::util::{publisher, watch_stream, SubscriptionManager};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    tracing_subscriber::fmt()
        .with_max_level(LevelFilter::DEBUG)
        .init();
    visualize::init();
}

pub struct CoreConnection {
    mission: Publisher<'static>,
    control: Publisher<'static>,
    _manager: SubscriptionManager,
    control_stream: watch::Receiver<FlutterControlResponse>,
    global_pos_stream: watch::Receiver<PositionTriple>,
    _local_pos_stream: watch::Receiver<PositionTriple>,
    yaw_stream: watch::Receiver<f64>,
    online_stream: watch::Receiver<bool>,
    step_stream: watch::Receiver<i32>,
}

impl CoreConnection {
    pub async fn init(machine: String) -> anyhow::Result<Self> {
        let t = |o: &str| format!("{machine}/{o}");
        let zconfig = zenoh::config::default();

        let session = Arc::new(zenoh::open(zconfig).res().await.map_err(|e| anyhow!(e))?);

        let (kalive_snd, mut keepalive_rcv) = watch::channel(());

        let mut sm = SubscriptionManager::new(session.clone(), &kalive_snd);

        let global_pos_rcv = sm
            .subscriber::<GlobalPosition, PositionTriple>(t("global_position"))
            .await?;
        let local_pos_rcv = sm
            .subscriber::<LocalPosition, PositionTriple>(t("local_position"))
            .await?;
        let yaw_rcv = sm.subscriber::<f32, f64>(t("yaw")).await?;
        let step_rcv = sm.subscriber::<i32, i32>(t("mission/step")).await?;
        let control_rcv = sm
            .subscriber::<ControlResponse, FlutterControlResponse>(t("control/out"))
            .await?;

        let mission_upd_pub = publisher(session.clone(), &t("mission/update")).await?;
        let control_pub = publisher(session, &t("control/in")).await?;

        let (online_snd, online_rcv) = watch::channel(false);

        let mut lpr: watch::Receiver<PositionTriple> = local_pos_rcv.clone();
        tokio::spawn(async move {
            loop {
                visualize::send_grid();
                select! {
                    Ok(_) = lpr.changed() => {
                        let p = lpr.borrow().to_owned();
                        visualize::log_pos(
                            "/position",
                            Vector3::new(p.x, p.y, p.z),
                            Color::from_rgb(100, 100, 0),
                        );
                    }
                    Ok(_) = keepalive_rcv.changed() => {
                        let _ = online_snd.send(true);
                    }
                    _ = sleep(Duration::from_secs(1)) => {
                        let _ = online_snd.send(false);
                    },
                }
            }
        });

        Ok(Self {
            mission: mission_upd_pub,
            control: control_pub,
            _manager: sm,
            global_pos_stream: global_pos_rcv,
            _local_pos_stream: local_pos_rcv,
            yaw_stream: yaw_rcv,
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

    #[frb(stream_dart_await)]
    pub async fn get_pos(&self, sink: StreamSink<PositionTriple>) -> anyhow::Result<()> {
        watch_stream(self.global_pos_stream.clone(), sink).await;
        Ok(())
    }

    #[frb(stream_dart_await)]
    pub async fn get_yaw(&self, sink: StreamSink<f64>) -> anyhow::Result<()> {
        watch_stream(self.yaw_stream.clone(), sink).await;
        Ok(())
    }

    #[frb(stream_dart_await)]
    pub async fn get_step(&self, sink: StreamSink<i32>) -> anyhow::Result<()> {
        watch_stream(self.step_stream.clone(), sink).await;
        Ok(())
    }

    #[frb(stream_dart_await)]
    pub async fn get_control(
        &self,
        sink: StreamSink<FlutterControlResponse>,
    ) -> anyhow::Result<()> {
        watch_stream(self.control_stream.clone(), sink).await;
        Ok(())
    }

    #[frb(stream_dart_await)]
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

impl Default for FlutterControlResponse {
    fn default() -> Self {
        Self::SendMissionPlan(vec![])
    }
}

#[derive(Default, Debug, Clone)]
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

impl From<LocalPosition> for PositionTriple {
    fn from(value: LocalPosition) -> Self {
        Self {
            x: value.x.into(),
            y: value.y.into(),
            z: value.z.into(),
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
