# PulseKit Go SDK

Official PulseKit SDK for Go applications.

## Installation

```bash
go get github.com/pulsekit/go
```

## Quick Start

```go
package main

import (
    "errors"
    "github.com/pulsekit/go"
)

func main() {
    // Initialize the client
    err := pulsekit.Init(pulsekit.Config{
        Endpoint:    "https://your-pulsekit-instance.com",
        APIKey:      "pk_your_api_key",
        Environment: "production",
        Release:     "1.0.0",
    })
    if err != nil {
        panic(err)
    }
    defer pulsekit.Close()

    // Capture an error
    err = errors.New("something went wrong")
    pulsekit.CaptureException(err)

    // Capture with options
    pulsekit.CaptureException(err,
        pulsekit.WithTags(map[string]string{"user_id": "123"}),
        pulsekit.WithMetadata(map[string]interface{}{"request_id": "abc"}),
    )

    // Send a custom event
    pulsekit.Capture(pulsekit.Event{
        Type:    "payment.success",
        Level:   pulsekit.LevelInfo,
        Message: "Payment completed",
        Metadata: map[string]interface{}{
            "amount":   99.99,
            "currency": "USD",
        },
        Tags: map[string]string{
            "customer_id": "cust_123",
        },
    })

    // Send a simple message
    pulsekit.CaptureMessage("User signed up", pulsekit.LevelInfo,
        pulsekit.WithTags(map[string]string{"user_id": "789"}),
    )

    // Flush before exit
    pulsekit.Flush()
}
```

## Configuration

```go
pulsekit.Init(pulsekit.Config{
    // Required
    Endpoint: "https://your-pulsekit-instance.com",
    APIKey:   "pk_your_api_key",

    // Optional
    Environment:   "production",    // Default: "production"
    Release:       "1.0.0",         // Your app version
    BatchSize:     10,              // Events to batch before sending
    FlushInterval: 5 * time.Second, // Flush interval
    Debug:         false,           // Enable debug logging
})
```

## Event Levels

- `pulsekit.LevelDebug` - Detailed debugging information
- `pulsekit.LevelInfo` - General information
- `pulsekit.LevelWarning` - Warning conditions
- `pulsekit.LevelError` - Error conditions
- `pulsekit.LevelFatal` - Critical errors

## HTTP Middleware

```go
func PulseKitMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                pulsekit.CaptureException(fmt.Errorf("%v", err),
                    pulsekit.WithMetadata(map[string]interface{}{
                        "path":   r.URL.Path,
                        "method": r.Method,
                    }),
                )
                http.Error(w, "Internal Server Error", http.StatusInternalServerError)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

## License

MIT

