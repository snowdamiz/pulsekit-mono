//! PulseKit SDK for Rust - Error tracking and event monitoring.
//!
//! # Quick Start
//!
//! ```no_run
//! use pulsekit::{PulseKit, Config, Event, Level};
//!
//! #[tokio::main]
//! async fn main() {
//!     // Initialize the client
//!     let client = PulseKit::new(Config {
//!         endpoint: "https://your-pulsekit-instance.com".to_string(),
//!         api_key: "pk_your_api_key".to_string(),
//!         environment: Some("production".to_string()),
//!         release: Some("1.0.0".to_string()),
//!         ..Default::default()
//!     });
//!
//!     // Capture an error
//!     client.capture_error("Something went wrong");
//!
//!     // Send a custom event
//!     client.capture(Event {
//!         event_type: "payment.success".to_string(),
//!         level: Level::Info,
//!         message: Some("Payment completed".to_string()),
//!         ..Default::default()
//!     });
//!
//!     // Flush before exit
//!     client.flush().await;
//! }
//! ```

use chrono::{DateTime, Utc};
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

/// Event severity level.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Level {
    Debug,
    #[default]
    Info,
    Warning,
    Error,
    Fatal,
}

/// Stack frame information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StackFrame {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub line: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub function: Option<String>,
}

/// An event to be sent to PulseKit.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Event {
    /// Event type identifier (e.g., "error", "payment.success")
    #[serde(rename = "type")]
    pub event_type: String,

    /// Event severity level
    #[serde(skip_serializing_if = "Option::is_none")]
    pub level: Option<Level>,

    /// Human-readable message
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    /// Additional structured data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, serde_json::Value>>,

    /// Stack trace information
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stacktrace: Option<Vec<StackFrame>>,

    /// Custom tags for filtering
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tags: Option<HashMap<String, String>>,

    /// Event timestamp
    #[serde(skip_serializing_if = "Option::is_none")]
    pub timestamp: Option<String>,

    /// Unique fingerprint for grouping similar events
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fingerprint: Option<String>,

    /// Environment name
    #[serde(skip_serializing_if = "Option::is_none")]
    pub environment: Option<String>,

    /// Release/version identifier
    #[serde(skip_serializing_if = "Option::is_none")]
    pub release: Option<String>,
}

/// Configuration for the PulseKit client.
#[derive(Debug, Clone)]
pub struct Config {
    /// The PulseKit server endpoint URL
    pub endpoint: String,
    /// Your project API key
    pub api_key: String,
    /// Environment name (e.g., "production", "staging")
    pub environment: Option<String>,
    /// Release/version identifier
    pub release: Option<String>,
    /// Maximum events to batch before sending
    pub batch_size: usize,
    /// Enable debug logging
    pub debug: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            endpoint: String::new(),
            api_key: String::new(),
            environment: Some("production".to_string()),
            release: None,
            batch_size: 10,
            debug: false,
        }
    }
}

/// PulseKit client for sending events.
pub struct PulseKit {
    config: Config,
    queue: Arc<Mutex<Vec<Event>>>,
    client: reqwest::Client,
}

impl PulseKit {
    /// Create a new PulseKit client.
    pub fn new(config: Config) -> Self {
        Self {
            config,
            queue: Arc::new(Mutex::new(Vec::new())),
            client: reqwest::Client::new(),
        }
    }

    /// Capture an error with automatic stack trace.
    pub fn capture_error(&self, message: &str) {
        self.capture_error_with_options(message, None, None);
    }

    /// Capture an error with options.
    pub fn capture_error_with_options(
        &self,
        message: &str,
        tags: Option<HashMap<String, String>>,
        metadata: Option<HashMap<String, serde_json::Value>>,
    ) {
        let stacktrace = capture_backtrace();

        let event = Event {
            event_type: "error".to_string(),
            level: Some(Level::Error),
            message: Some(message.to_string()),
            stacktrace: Some(stacktrace),
            tags,
            metadata,
            ..Default::default()
        };

        self.capture(event);
    }

    /// Capture a custom event.
    pub fn capture(&self, mut event: Event) {
        // Enrich event with config values
        event.timestamp = Some(Utc::now().to_rfc3339());
        event.environment = event.environment.or_else(|| self.config.environment.clone());
        event.release = event.release.or_else(|| self.config.release.clone());

        if event.level.is_none() {
            event.level = Some(Level::Info);
        }

        let mut queue = self.queue.lock();
        queue.push(event);

        if self.config.debug {
            println!("[PulseKit] Event queued, queue size: {}", queue.len());
        }

        if queue.len() >= self.config.batch_size {
            let events: Vec<Event> = queue.drain(..).collect();
            drop(queue);
            self.send_events_sync(events);
        }
    }

    /// Capture a simple message.
    pub fn capture_message(&self, message: &str, level: Level) {
        self.capture_message_with_options(message, level, None, None);
    }

    /// Capture a message with options.
    pub fn capture_message_with_options(
        &self,
        message: &str,
        level: Level,
        tags: Option<HashMap<String, String>>,
        metadata: Option<HashMap<String, serde_json::Value>>,
    ) {
        let event = Event {
            event_type: "message".to_string(),
            level: Some(level),
            message: Some(message.to_string()),
            tags,
            metadata,
            ..Default::default()
        };

        self.capture(event);
    }

    /// Flush all queued events (async).
    #[cfg(feature = "async")]
    pub async fn flush(&self) {
        let events: Vec<Event> = {
            let mut queue = self.queue.lock();
            queue.drain(..).collect()
        };

        if events.is_empty() {
            return;
        }

        self.send_events_async(events).await;
    }

    /// Flush all queued events (blocking).
    pub fn flush_blocking(&self) {
        let events: Vec<Event> = {
            let mut queue = self.queue.lock();
            queue.drain(..).collect()
        };

        if events.is_empty() {
            return;
        }

        self.send_events_sync(events);
    }

    #[cfg(feature = "async")]
    async fn send_events_async(&self, events: Vec<Event>) {
        let (url, body) = self.prepare_request(&events);

        match self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("X-PulseKit-Key", &self.config.api_key)
            .json(&body)
            .send()
            .await
        {
            Ok(resp) => {
                if self.config.debug {
                    println!(
                        "[PulseKit] Sent {} event(s), status: {}",
                        events.len(),
                        resp.status()
                    );
                }
            }
            Err(e) => {
                if self.config.debug {
                    println!("[PulseKit] Failed to send events: {}", e);
                }
            }
        }
    }

    fn send_events_sync(&self, events: Vec<Event>) {
        let (url, body) = self.prepare_request(&events);

        let client = reqwest::blocking::Client::new();
        match client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("X-PulseKit-Key", &self.config.api_key)
            .json(&body)
            .send()
        {
            Ok(resp) => {
                if self.config.debug {
                    println!(
                        "[PulseKit] Sent {} event(s), status: {}",
                        events.len(),
                        resp.status()
                    );
                }
            }
            Err(e) => {
                if self.config.debug {
                    println!("[PulseKit] Failed to send events: {}", e);
                }
            }
        }
    }

    fn prepare_request(&self, events: &[Event]) -> (String, serde_json::Value) {
        if events.len() == 1 {
            let url = format!("{}/api/v1/events", self.config.endpoint);
            let body = serde_json::to_value(&events[0]).unwrap_or_default();
            (url, body)
        } else {
            let url = format!("{}/api/v1/events/batch", self.config.endpoint);
            let body = serde_json::json!({ "events": events });
            (url, body)
        }
    }
}

fn capture_backtrace() -> Vec<StackFrame> {
    let backtrace = backtrace::Backtrace::new();
    let mut frames = Vec::new();

    for frame in backtrace.frames().iter().skip(3) {
        for symbol in frame.symbols() {
            frames.push(StackFrame {
                file: symbol.filename().map(|p| p.to_string_lossy().to_string()),
                line: symbol.lineno(),
                function: symbol.name().map(|n| n.to_string()),
            });
        }
    }

    frames
}

impl Drop for PulseKit {
    fn drop(&mut self) {
        self.flush_blocking();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_event_serialization() {
        let event = Event {
            event_type: "test".to_string(),
            level: Some(Level::Info),
            message: Some("Test message".to_string()),
            ..Default::default()
        };

        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("\"type\":\"test\""));
        assert!(json.contains("\"level\":\"info\""));
    }

    #[test]
    fn test_config_default() {
        let config = Config::default();
        assert_eq!(config.batch_size, 10);
        assert_eq!(config.environment, Some("production".to_string()));
    }
}

