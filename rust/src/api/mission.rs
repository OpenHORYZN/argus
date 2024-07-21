use std::{net::UdpSocket, time::Duration};

use argus_common::{MissionNode, Waypoint};
use nalgebra::Vector3;
use postcard::to_vec;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub async fn send_mission_plan(plan: Vec<FlutterMissionNode>) -> anyhow::Result<()> {
    let plan: Vec<MissionNode> = plan.into_iter().map(Into::into).collect();

    let udp = UdpSocket::bind("0.0.0.0:0")?;
    udp.connect("127.0.0.1:4444")?;

    udp.send(&to_vec::<_, 2000>(&plan)?)?;
    Ok(())
}

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
