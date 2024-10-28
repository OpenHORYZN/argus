use flutter_rust_bridge::frb;
use nalgebra::Vector3;
use rerun::Color;
use std::{sync::Arc, time::Duration};
use tokio::{select, sync::watch, time::sleep};
use tracing::info;
use uuid::Uuid;
use zenoh::config::EndPoint;

use argus_common::{
    interface::{
        IControlRequest, IControlResponse, IGlobalPosition, ILocalPosition, IMissionStep,
        IMissionUpdate, IVelocity, IYaw,
    },
    ControlRequest, ControlResponse, GlobalPosition, LocalPosition, MissionItem, MissionNode,
    MissionParams, MissionPlan, Waypoint,
};

use crate::{frb_generated::StreamSink, visualize};

use crate::util::{publisher, watch_stream, MapErr, Pub, SubscriptionManager};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    tracing_subscriber::fmt()
        .with_env_filter("rust_lib_argus=debug")
        .init();
    visualize::init();
}

pub struct CoreConnection {
    mission: Pub<IMissionUpdate>,
    control: Pub<IControlRequest>,
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
        let mut zconfig = zenoh::config::Config::default();

        let interface = "tailscale0";

        zconfig
            .listen
            .endpoints
            .set(vec![EndPoint::new("tcp", "0.0.0.0:0", "", "").emap()?])
            .emap()?;

        let session = Arc::new(zenoh::open(zconfig).await.emap()?);

        let zid = session.zid();

        info!("Singularity Link: Searching on interface {interface}, Identity {zid}");

        let (kalive_snd, mut keepalive_rcv) = watch::channel(());

        let mut sm = SubscriptionManager::new(session.clone(), &kalive_snd, machine.clone());

        let global_pos_rcv = sm.subscriber::<IGlobalPosition, PositionTriple>().await?;
        let local_pos_rcv = sm.subscriber::<ILocalPosition, PositionTriple>().await?;
        let yaw_rcv = sm.subscriber::<IYaw, f64>().await?;
        let velocity_rcv = sm.subscriber::<IVelocity, Vector3<f64>>().await?;
        let step_rcv = sm.subscriber::<IMissionStep, i32>().await?;
        let control_rcv = sm
            .subscriber::<IControlResponse, FlutterControlResponse>()
            .await?;

        let mission_upd_pub = publisher::<IMissionUpdate>(session.clone(), &machine).await?;
        let control_pub = publisher::<IControlRequest>(session, &machine).await?;

        let (online_snd, online_rcv) = watch::channel(false);

        let mut lpr = local_pos_rcv.clone();
        let mut vlr = velocity_rcv.clone();
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
                    Ok(_) = vlr.changed() => {
                        let v = vlr.borrow().to_owned();
                        visualize::log_xyz(
                            "/velocity",
                            Vector3::new(v.x, v.y, v.z),
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

    pub async fn send_mission_plan(&mut self, plan: FlutterMissionPlan) -> anyhow::Result<()> {
        let nodes: Vec<MissionNode> = plan.nodes.into_iter().map(Into::into).collect();
        self.mission
            .send(MissionPlan {
                id: plan.id,
                nodes,
                params: plan.params.into(),
            })
            .await
    }

    pub async fn send_control(&mut self, req: FlutterControlRequest) -> anyhow::Result<()> {
        let control: ControlRequest = req.into();
        self.control.send(control).await
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
    PauseResume(bool),
}

impl From<FlutterControlRequest> for ControlRequest {
    fn from(value: FlutterControlRequest) -> Self {
        match value {
            FlutterControlRequest::FetchMissionPlan => ControlRequest::FetchMissionPlan,
            FlutterControlRequest::PauseResume(pause) => ControlRequest::PauseResume(pause),
        }
    }
}

#[derive(Debug, Clone)]
pub enum FlutterControlResponse {
    SendMissionPlan(FlutterMissionPlan),
    PauseResume(bool),
}

impl From<ControlResponse> for FlutterControlResponse {
    fn from(value: ControlResponse) -> Self {
        match value {
            ControlResponse::SendMissionPlan(plan) => {
                FlutterControlResponse::SendMissionPlan(FlutterMissionPlan {
                    id: plan.id,
                    nodes: plan.nodes.into_iter().map(Into::into).collect(),
                    params: plan.params.into(),
                })
            }
            ControlResponse::PauseResume(pause) => FlutterControlResponse::PauseResume(pause),
        }
    }
}

impl Default for FlutterControlResponse {
    fn default() -> Self {
        Self::SendMissionPlan(FlutterMissionPlan {
            id: Uuid::default(),
            nodes: vec![],
            params: FlutterMissionParams {
                target_velocity: Vector3::zeros().into(),
                target_acceleration: Vector3::zeros().into(),
                target_jerk: Vector3::zeros().into(),
                disable_yaw: false,
            },
        })
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
pub struct FlutterVector3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl From<nalgebra::Vector3<f64>> for FlutterVector3 {
    fn from(value: nalgebra::Vector3<f64>) -> Self {
        Self {
            x: value.x,
            y: value.y,
            z: value.z,
        }
    }
}

impl From<FlutterVector3> for nalgebra::Vector3<f64> {
    fn from(value: FlutterVector3) -> Self {
        Self::new(value.x, value.y, value.z)
    }
}

#[derive(Debug, Clone)]
pub struct FlutterMissionPlan {
    pub id: Uuid,
    pub nodes: Vec<FlutterMissionNode>,
    pub params: FlutterMissionParams,
}

#[derive(Debug, Clone)]
pub struct FlutterMissionParams {
    pub target_velocity: FlutterVector3,
    pub target_acceleration: FlutterVector3,
    pub target_jerk: FlutterVector3,
    pub disable_yaw: bool,
}

impl FlutterMissionParams {
    #[frb(sync)]
    pub fn copy(&self) -> Self {
        self.clone()
    }
}

impl From<MissionParams> for FlutterMissionParams {
    fn from(value: MissionParams) -> Self {
        Self {
            target_velocity: value.target_velocity.into(),
            target_acceleration: value.target_acceleration.into(),
            target_jerk: value.target_jerk.into(),
            disable_yaw: value.disable_yaw,
        }
    }
}

impl From<FlutterMissionParams> for MissionParams {
    fn from(value: FlutterMissionParams) -> Self {
        Self {
            target_velocity: value.target_velocity.into(),
            target_acceleration: value.target_acceleration.into(),
            target_jerk: value.target_jerk.into(),
            disable_yaw: value.disable_yaw,
        }
    }
}

#[derive(Debug, Clone)]
pub struct FlutterMissionNode {
    pub id: Uuid,
    pub item: FlutterMissionItem,
}

impl FlutterMissionNode {
    #[frb(sync)]
    pub fn random(item: FlutterMissionItem) -> Self {
        Self {
            id: Uuid::new_v4(),
            item,
        }
    }
}

impl From<MissionNode> for FlutterMissionNode {
    fn from(value: MissionNode) -> Self {
        Self {
            id: value.id,
            item: value.item.into(),
        }
    }
}

impl From<FlutterMissionNode> for MissionNode {
    fn from(value: FlutterMissionNode) -> Self {
        Self {
            id: value.id,
            item: value.item.into(),
        }
    }
}

#[derive(Debug, Clone)]
pub enum FlutterMissionItem {
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

impl From<FlutterMissionItem> for MissionItem {
    fn from(value: FlutterMissionItem) -> Self {
        match value {
            FlutterMissionItem::Init => MissionItem::Init,
            FlutterMissionItem::Takeoff { altitude } => MissionItem::Takeoff { altitude },
            FlutterMissionItem::Waypoint(w) => MissionItem::Waypoint(w.into()),
            FlutterMissionItem::Delay(s) => MissionItem::Delay(Duration::from_secs_f64(s)),
            FlutterMissionItem::FindSafeSpot => MissionItem::FindSafeSpot,
            FlutterMissionItem::Transition => MissionItem::Transition,
            FlutterMissionItem::Land => MissionItem::Land,
            FlutterMissionItem::PrecLand => MissionItem::PrecLand,
            FlutterMissionItem::End => MissionItem::End,
        }
    }
}

impl From<MissionItem> for FlutterMissionItem {
    fn from(value: MissionItem) -> Self {
        match value {
            MissionItem::Init => FlutterMissionItem::Init,
            MissionItem::Takeoff { altitude } => FlutterMissionItem::Takeoff { altitude },
            MissionItem::Waypoint(wp) => FlutterMissionItem::Waypoint(wp.into()),
            MissionItem::Delay(d) => FlutterMissionItem::Delay(d.as_secs_f64()),
            MissionItem::FindSafeSpot => FlutterMissionItem::FindSafeSpot,
            MissionItem::Transition => FlutterMissionItem::Transition,
            MissionItem::Land => FlutterMissionItem::Land,
            MissionItem::PrecLand => FlutterMissionItem::PrecLand,
            MissionItem::End => FlutterMissionItem::End,
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
