# PulseKit

<div align="center">
  <img src="server/priv/static/images/logo.svg" alt="PulseKit Logo" width="80" />
  <h3>Open-source error tracking and event monitoring</h3>
  <p>A self-hosted alternative to Datadog and Sentry</p>
</div>

---

## Features

- **Error Tracking** - Capture and track errors from your applications with full stack traces
- **Custom Events** - Log any event type (payments, signups, deployments, etc.)
- **Workspaces** - Organize projects into workspaces for multi-tenant/multi-team environments
- **Real-time Dashboard** - Live-updating dashboard built with Phoenix LiveView
- **Multi-language SDKs** - TypeScript, Elixir, Go, and Rust SDKs included
- **Webhook Alerts** - Get notified when important events occur
- **Self-hosted** - Deploy on your own infrastructure with Docker
- **SQLite Storage** - Simple, zero-config database that runs anywhere

## Quick Start

### Using Docker (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/snowdamiz/pulsekit-mono
cd pulsekit
```

2. Generate a secret key:
```bash
cd server && mix phx.gen.secret
```

3. Create your environment file:
```bash
cp docker/env.example docker/.env
# Edit docker/.env and add your SECRET_KEY_BASE
```

4. Start PulseKit:
```bash
cd docker
docker-compose up -d
```

5. Open http://localhost:4000 in your browser

### Manual Installation

Requirements:
- Elixir 1.15+
- Erlang/OTP 26+
- Node.js 18+ (for asset compilation)

```bash
# Clone and enter the server directory
cd server

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start the server
mix phx.server
```

## SDK Installation

### TypeScript/JavaScript

```bash
npm install @120356aa/pulsekit-sdk
```

```typescript
import { PulseKit } from '@120356aa/pulsekit-sdk';

const pulse = new PulseKit({
  endpoint: 'https://your-pulsekit-instance.com',
  apiKey: 'pk_your_api_key',
  environment: 'production',
});

// Auto-capture errors (enabled by default)
// Or manually capture:
pulse.captureException(error);

// Custom events
pulse.capture({
  type: 'payment.success',
  level: 'info',
  message: 'Payment completed',
  metadata: { amount: 99.99, currency: 'USD' },
  tags: { customer_id: 'cust_123' },
});
```

### Elixir

```elixir
# mix.exs
{:pulsekit, "~> 1.0"}

# config/config.exs
config :pulsekit,
  endpoint: "https://your-pulsekit-instance.com",
  api_key: "pk_your_api_key",
  environment: "production"
```

```elixir
# Capture exceptions
try do
  raise "Something went wrong"
rescue
  e -> PulseKit.capture_exception(e, __STACKTRACE__)
end

# Custom events
PulseKit.capture(%{
  type: "payment.success",
  level: :info,
  message: "Payment completed",
  metadata: %{amount: 99.99, currency: "USD"},
  tags: %{customer_id: "cust_123"}
})
```

### Go

```bash
go get github.com/pulsekit/go
```

```go
import "github.com/pulsekit/go"

func main() {
    pulsekit.Init(pulsekit.Config{
        Endpoint:    "https://your-pulsekit-instance.com",
        APIKey:      "pk_your_api_key",
        Environment: "production",
    })
    defer pulsekit.Close()

    // Capture errors
    pulsekit.CaptureException(err)

    // Custom events
    pulsekit.Capture(pulsekit.Event{
        Type:    "payment.success",
        Level:   pulsekit.LevelInfo,
        Message: "Payment completed",
        Metadata: map[string]interface{}{"amount": 99.99},
        Tags:    map[string]string{"customer_id": "cust_123"},
    })
}
```

### Rust

```toml
# Cargo.toml
[dependencies]
pulsekit = "1.0"
```

```rust
use pulsekit::{PulseKit, Config, Event, Level};

#[tokio::main]
async fn main() {
    let client = PulseKit::new(Config {
        endpoint: "https://your-pulsekit-instance.com".to_string(),
        api_key: "pk_your_api_key".to_string(),
        environment: Some("production".to_string()),
        ..Default::default()
    });

    // Capture errors
    client.capture_error("Something went wrong");

    // Custom events
    client.capture(Event {
        event_type: "payment.success".to_string(),
        level: Some(Level::Info),
        message: Some("Payment completed".to_string()),
        ..Default::default()
    });

    client.flush().await;
}
```

## API Reference

### Event Ingestion

**POST** `/api/v1/events`

Headers:
- `Content-Type: application/json`
- `X-PulseKit-Key: pk_your_api_key`

Body:
```json
{
  "type": "error",
  "level": "error",
  "message": "Something went wrong",
  "metadata": {},
  "stacktrace": [],
  "tags": {},
  "environment": "production",
  "release": "1.0.0"
}
```

**POST** `/api/v1/events/batch`

Body:
```json
{
  "events": [
    { "type": "error", "message": "Error 1" },
    { "type": "info", "message": "Info event" }
  ]
}
```

### Health Check

**GET** `/api/v1/health`

Returns:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Event Levels

| Level | Description |
|-------|-------------|
| `debug` | Detailed debugging information |
| `info` | General information |
| `warning` | Warning conditions |
| `error` | Error conditions |
| `fatal` | Critical errors |

## Alert Types

- **Threshold** - Trigger when event count exceeds N in a time window
- **New Error** - Trigger on first occurrence of an error type
- **Pattern Match** - Trigger when event message matches a regex pattern

## Workspaces

PulseKit supports organizing your projects into **Workspaces** (also called Organizations). This is useful when you:

- Have multiple teams or clients
- Want to group related microservices together
- Need to manage tens or hundreds of services across different environments

### Creating Workspaces

1. Navigate to **Workspaces** in the sidebar
2. Click **New Workspace**
3. Give it a name and optional description

### Organizing Projects

Each project belongs to a workspace. When you create a new project, it's automatically added to your currently selected workspace. You can:

- Switch between workspaces using the dropdown in the sidebar
- View all projects in a workspace from the workspace detail page
- Filter the dashboard, events, and alerts by the active workspace

### Example Organization

```
├── Production Services (Workspace)
│   ├── api-gateway (Project)
│   ├── user-service (Project)
│   ├── payment-service (Project)
│   └── notification-service (Project)
│
├── Staging (Workspace)
│   ├── api-gateway-staging (Project)
│   └── user-service-staging (Project)
│
└── Client Portal (Workspace)
    ├── client-web (Project)
    └── client-api (Project)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Your Applications                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │   TS     │  │  Elixir  │  │    Go    │  │   Rust   │        │
│  │   SDK    │  │   SDK    │  │   SDK    │  │   SDK    │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
└───────┼─────────────┼─────────────┼─────────────┼───────────────┘
        │             │             │             │
        └─────────────┴──────┬──────┴─────────────┘
                             │
                    HTTP POST /api/v1/events
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PulseKit Server                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Phoenix    │  │  LiveView   │  │   Webhook   │              │
│  │    API      │  │  Dashboard  │  │  Dispatcher │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│         └────────────────┴────────────────┘                      │
│                          │                                       │
│                    ┌─────┴─────┐                                 │
│                    │  SQLite   │                                 │
│                    │  Database │                                 │
│                    └───────────┘                                 │
│                                                                  │
│  Data Model:                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │ Workspace   │───▶│  Project    │───▶│   Events    │          │
│  │ (Org)       │    │ (+ API Key) │    │ (Logs/Errs) │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Phoenix secret key (required) | - |
| `DATABASE_PATH` | Path to SQLite database | `/app/data/pulsekit.db` |
| `PHX_HOST` | Hostname for the server | `localhost` |
| `PORT` | HTTP port | `4000` |
| `PHX_SERVER` | Enable HTTP server | `true` |

## Development

```bash
cd server

# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start development server
mix phx.server

# Run tests
mix test

# Format code
mix format
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">
  <p>Built with ❤️ using Phoenix, LiveView, and Tailwind CSS</p>
</div>

