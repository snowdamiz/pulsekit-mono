# PulseKit

Official PulseKit SDK for Elixir applications.

## Installation

Add `pulsekit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pulsekit, "~> 1.0"}
  ]
end
```

## Configuration

Add to your `config/config.exs`:

```elixir
config :pulsekit,
  endpoint: "https://your-pulsekit-instance.com",
  api_key: "pk_your_api_key",
  environment: "production",
  release: "1.0.0"
```

## Usage

### Capture Exceptions

```elixir
try do
  raise "Something went wrong"
rescue
  e -> PulseKit.capture_exception(e, __STACKTRACE__)
end

# With additional context
PulseKit.capture_exception(error, stacktrace,
  tags: %{user_id: "123"},
  metadata: %{request_id: "abc"}
)
```

### Custom Events

```elixir
PulseKit.capture(%{
  type: "payment.success",
  level: :info,
  message: "Payment completed",
  metadata: %{amount: 99.99, currency: "USD"},
  tags: %{customer_id: "cust_123"}
})
```

### Simple Messages

```elixir
PulseKit.capture_message("User signed up", :info)
PulseKit.capture_message("Warning!", :warning, tags: %{user_id: "123"})
```

### Plug Integration

Add to your Phoenix endpoint or router:

```elixir
defmodule MyAppWeb.ErrorHandler do
  def handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    PulseKit.capture_exception(reason, stack,
      metadata: %{
        request_path: conn.request_path,
        method: conn.method
      }
    )
  end
end
```

## Event Levels

- `:debug` - Detailed debugging information
- `:info` - General information
- `:warning` - Warning conditions
- `:error` - Error conditions
- `:fatal` - Critical errors

## License

MIT

