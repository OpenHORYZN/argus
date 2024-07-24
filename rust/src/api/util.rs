use anyhow::anyhow;
use std::sync::Arc;

use zenoh::{prelude::r#async::*, publication::Publisher, subscriber::FlumeSubscriber, Session};

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
