use anyhow::{anyhow, bail};
use serde::Deserialize;
use std::{fmt::Display, sync::Arc};
use tokio::sync::watch;

use zenoh::{prelude::r#async::*, publication::Publisher, subscriber::FlumeSubscriber, Session};

use crate::frb_generated::{SseEncode, StreamSink};

#[flutter_rust_bridge::frb(ignore)]
pub async fn subscriber(
    session: Arc<Session>,
    topic: &str,
) -> anyhow::Result<FlumeSubscriber<'static>> {
    Ok(session
        .declare_subscriber(topic)
        .best_effort()
        .res()
        .await
        .map_err(|e| anyhow!(e))?)
}

#[flutter_rust_bridge::frb(ignore)]
pub async fn publisher(session: Arc<Session>, topic: &str) -> anyhow::Result<Publisher<'static>> {
    let topic = topic.to_owned();
    Ok(session
        .declare_publisher(topic)
        .res()
        .await
        .map_err(|e| anyhow!(e))?)
}

pub fn ingest<T, U>(
    value: Result<Sample, flume::RecvError>,
    target: &watch::Sender<U>,
    online: &watch::Sender<bool>,
) -> anyhow::Result<()>
where
    for<'a> T: Deserialize<'a>,
    U: From<T>,
{
    match value {
        Ok(sample) => {
            let buf = sample.value.payload.contiguous().to_vec();
            let Ok(msg) = postcard::from_bytes::<T>(&buf) else {
                bail!("failed to decode");
            };

            let _ = online.send(true);

            let Ok(_) = target.send(msg.into()) else {
                bail!("nobody listening");
            };
        }
        Err(e) => {
            bail!("error {e}");
        }
    }
    Ok(())
}

pub async fn watch_stream<T>(mut stream: watch::Receiver<T>, sink: StreamSink<T>)
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

pub trait PrintError {
    fn print_error(self);
}

impl<T, E: Display> PrintError for Result<T, E> {
    fn print_error(self) {
        match self {
            Ok(_) => (),
            Err(e) => {
                println!("error: {e}");
                ()
            }
        }
    }
}
