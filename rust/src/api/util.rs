use anyhow::anyhow;
use serde::Deserialize;
use std::{fmt::Debug, sync::Arc};
use tokio::sync::watch;
use zenoh::subscriber::Subscriber;

use zenoh::{prelude::r#async::*, publication::Publisher, Session};

use crate::frb_generated::{SseEncode, StreamSink};

use crate::visualize;

#[flutter_rust_bridge::frb(ignore)]
pub struct SubscriptionManager {
    session: Arc<Session>,
    keepalive: watch::Sender<()>,
    subs: Vec<Subscriber<'static, ()>>,
}

impl SubscriptionManager {
    pub fn new(session: Arc<Session>, keepalive: &watch::Sender<()>) -> Self {
        Self {
            session,
            keepalive: keepalive.clone(),
            subs: vec![],
        }
    }
    pub async fn subscriber<T, U>(&mut self, topic: String) -> anyhow::Result<watch::Receiver<U>>
    where
        for<'a> T: Deserialize<'a>,
        U: From<T> + Debug + Clone + Default + Send + Sync + 'static,
    {
        let (target_snd, target_rcv) = watch::channel(U::default());
        let keepalive = self.keepalive.clone();
        let sub = self
            .session
            .declare_subscriber(topic)
            .best_effort()
            .callback(move |sample| {
                if let Some(ts) = sample.timestamp {
                    visualize::set_time(ts.get_time().as_secs_f64());
                }
                let buf = sample.value.payload.contiguous().to_vec();
                let Ok(msg) = postcard::from_bytes::<T>(&buf) else {
                    println!("failed to decode");
                    return;
                };

                let _ = keepalive.send_replace(());
                let conv: U = msg.into();

                let Ok(_) = target_snd.send(conv.clone()) else {
                    println!("nobody listening");
                    return;
                };
            })
            .res()
            .await
            .map_err(|e| anyhow!(e))?;
        self.subs.push(sub);
        Ok(target_rcv)
    }
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

#[flutter_rust_bridge::frb(ignore)]
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
