use anyhow::anyhow;
use argus_common::interface::Interface;
use futures_util::SinkExt;
use postcard::to_allocvec;
use std::marker::PhantomData;
use std::{fmt::Debug, sync::Arc};
use tokio::sync::watch;
use zenoh::subscriber::Subscriber;

use zenoh::{prelude::r#async::*, publication::Publisher, Session};

use crate::frb_generated::{SseEncode, StreamSink};

use crate::visualize;

pub struct SubscriptionManager {
    session: Arc<Session>,
    machine: String,
    keepalive: watch::Sender<()>,
    subs: Vec<Subscriber<'static, ()>>,
}

impl SubscriptionManager {
    pub fn new(session: Arc<Session>, keepalive: &watch::Sender<()>, machine: String) -> Self {
        Self {
            session,
            keepalive: keepalive.clone(),
            machine,
            subs: vec![],
        }
    }
    pub async fn subscriber<I, U>(&mut self) -> anyhow::Result<watch::Receiver<U>>
    where
        I: Interface,
        U: From<I::Message> + Debug + Clone + Default + Send + Sync + 'static,
    {
        let (target_snd, target_rcv) = watch::channel(U::default());
        let keepalive = self.keepalive.clone();
        let sub = self
            .session
            .declare_subscriber(format!("{}/{}", self.machine, I::topic()))
            .best_effort()
            .callback(move |sample| {
                if let Some(ts) = sample.timestamp {
                    visualize::set_time(ts.get_time().as_secs_f64());
                }
                let buf = sample.value.payload.contiguous().to_vec();
                let Ok(msg) = postcard::from_bytes::<I::Message>(&buf) else {
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

pub struct Pub<I> {
    publisher: Publisher<'static>,
    _phantom: PhantomData<I>,
}

impl<I: Interface> Pub<I> {
    pub async fn send(&mut self, msg: I::Message) -> anyhow::Result<()> {
        let data = to_allocvec(&msg)?;

        self.publisher.send(&*data).await.map_err(|e| anyhow!(e))?;
        Ok(())
    }
}

pub async fn publisher<I: Interface>(
    session: Arc<Session>,
    machine: &str,
) -> anyhow::Result<Pub<I>> {
    let topic = format!("{machine}/{}", I::topic());
    let res = session
        .declare_publisher(topic)
        .res()
        .await
        .map_err(|e| anyhow!(e))?;
    Ok(Pub {
        publisher: res,
        _phantom: PhantomData,
    })
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

pub trait MapErr<T> {
    fn emap(self) -> anyhow::Result<T>;
}

impl<T, E: Debug> MapErr<T> for Result<T, E> {
    fn emap(self) -> anyhow::Result<T> {
        self.map_err(|e| anyhow::anyhow!("{e:?}"))
    }
}
