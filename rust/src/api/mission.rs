use anyhow::anyhow;
use argus_common::{GlobalPosition, MissionNode, Waypoint};
use futures_util::SinkExt;
use nalgebra::Vector3;
use postcard::to_allocvec;
use std::{sync::Arc, time::Duration};
use tokio::{select, sync::watch, time::sleep};

use zenoh::{prelude::r#async::*, publication::Publisher};

use crate::frb_generated::{SseEncode, StreamSink};

use super::util::{publisher, subscriber};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub struct CoreConnection {
    mission: Publisher<'static>,
    pos_stream: watch::Receiver<PositionTriple>,
    online_stream: watch::Receiver<bool>,
    step_stream: watch::Receiver<usize>,
}

impl CoreConnection {
    pub async fn init() -> anyhow::Result<Self> {
        let zconfig = zenoh::config::default();

        let session = Arc::new(zenoh::open(zconfig).res().await.map_err(|e| anyhow!(e))?);

        let pos_sub = subscriber(session.clone(), "position").await?;
        let step_sub = subscriber(session.clone(), "mission/step").await?;
        let mission_upd_pub = publisher(session, "mission/update").await?;

        let (pos_snd, pos_rcv) = watch::channel(PositionTriple {
            x: 50.0,
            y: 30.0,
            z: 10.0,
        });

        let (step_snd, step_rcv) = watch::channel(0);

        let (online_snd, online_rcv) = watch::channel(false);

        tokio::spawn(async move {
            loop {
                select! {
                    pos = pos_sub.recv_async() => {
                        match pos {
                            Ok(sample) => {
                                let buf = sample.value.payload.contiguous();
                                let Ok(msg) = postcard::from_bytes::<GlobalPosition>(&buf) else {
                                    continue;
                                };

                                let _ = online_snd.send(true);

                                let Ok(_) = pos_snd.send(PositionTriple {
                                    x: msg.lat,
                                    y: msg.lon,
                                    z: msg.alt as f64,
                                }) else {
                                    println!("nobody listening");
                                    break;
                                };
                            }
                            Err(e) => {
                                println!("error {e}");
                                continue;
                            }
                        }
                    }
                    step = step_sub.recv_async() => {
                        match step {
                            Ok(sample) => {
                                let buf = sample.value.payload.contiguous();
                                let Ok(msg) = postcard::from_bytes::<usize>(&buf) else {
                                    continue;
                                };

                                let _ = online_snd.send(true);

                                let Ok(_) = step_snd.send(msg) else {
                                    println!("nobody listening");
                                    break;
                                };
                            }
                            Err(e) => {
                                println!("error {e}");
                                continue;
                            }
                        }
                    }
                    _ = sleep(Duration::from_secs(1)) => {
                        let _ = online_snd.send(false);
                    },
                }
            }
        });

        Ok(Self {
            mission: mission_upd_pub,
            pos_stream: pos_rcv,
            online_stream: online_rcv,
            step_stream: step_rcv,
        })
    }

    pub async fn send_mission_plan(&mut self, plan: Vec<FlutterMissionNode>) -> anyhow::Result<()> {
        let plan: Vec<MissionNode> = plan.into_iter().map(Into::into).collect();

        let plan = to_allocvec(&plan)?;

        self.mission.send(&*plan).await.map_err(|e| anyhow!(e))?;

        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_pos(&self, sink: StreamSink<PositionTriple>) -> anyhow::Result<()> {
        Self::watch_stream(self.pos_stream.clone(), sink).await;
        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_step(&self, sink: StreamSink<usize>) -> anyhow::Result<()> {
        Self::watch_stream(self.step_stream.clone(), sink).await;
        Ok(())
    }

    #[flutter_rust_bridge::frb(stream_dart_await)]
    pub async fn get_online(&self, sink: StreamSink<bool>) -> anyhow::Result<()> {
        Self::watch_stream(self.online_stream.clone(), sink).await;
        Ok(())
    }

    async fn watch_stream<T>(mut stream: watch::Receiver<T>, sink: StreamSink<T>)
    where
        T: SseEncode + Clone + Send + Sync + 'static,
    {
        tokio::spawn(async move {
            loop {
                match stream.changed().await {
                    Ok(_) => {
                        let Ok(_) = sink.add(stream.borrow().to_owned()) else {
                            println!("t stream closed");
                            break;
                        };
                    }
                    Err(_) => {
                        let _ = sink.add_error(());
                        break;
                    }
                }
            }
        });
    }
}

#[derive(Debug, Clone)]
pub struct PositionTriple {
    pub x: f64,
    pub y: f64,
    pub z: f64,
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
