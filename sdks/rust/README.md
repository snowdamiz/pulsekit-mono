# PulseKit Rust SDK

Official PulseKit SDK for Rust applications.

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
pulsekit = "1.0"
```

## Quick Start

```rust
use pulsekit::{PulseKit, Config, Event, Level};

#[tokio::main]
async fn main() {
    // Initialize the client
    let client = PulseKit::new(Config {
        endpoint: "https://your-pulsekit-instance.com".to_string(),
        api_key: "pk_your_api_key".to_string(),
        environment: Some("production".to_string()),
        release: Some("1.0.0".to_string()),
        ..Default::default()
    });

    // Capture an error
    client.capture_error("Something went wrong");

    // Capture with options
    let mut tags = std::collections::HashMap::new();
    tags.insert("user_id".to_string(), "123".to_string());
    client.capture_error_with_options("Error occurred", Some(tags), None);

    // Send a custom event
    client.capture(Event {
        event_type: "payment.success".to_string(),
        level: Some(Level::Info),
        message: Some("Payment completed".to_string()),
        metadata: Some({
            let mut m = std::collections::HashMap::new();
            m.insert("amount".to_string(), serde_json::json!(99.99));
            m.insert("currency".to_string(), serde_json::json!("USD"));
            m
        }),
        tags: Some({
            let mut t = std::collections::HashMap::new();
            t.insert("customer_id".to_string(), "cust_123".to_string());
            t
        }),
        ..Default::default()
    });

    // Flush before exit
    client.flush().await;
}
```

## Configuration

```rust
let config = Config {
    // Required
    endpoint: "https://your-pulsekit-instance.com".to_string(),
    api_key: "pk_your_api_key".to_string(),

    // Optional
    environment: Some("production".to_string()), // Default: "production"
    release: Some("1.0.0".to_string()),          // Your app version
    batch_size: 10,                               // Events to batch before sending
    debug: false,                                 // Enable debug logging
};
```

## Event Levels

- `Level::Debug` - Detailed debugging information
- `Level::Info` - General information
- `Level::Warning` - Warning conditions
- `Level::Error` - Error conditions
- `Level::Fatal` - Critical errors

## Features

- `async` (default) - Async support with tokio
- `blocking` - Blocking HTTP client

```toml
# Use blocking only
[dependencies]
pulsekit = { version = "1.0", default-features = false, features = ["blocking"] }
```

## License

MIT

