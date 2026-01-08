# PulseKit SDK Examples

This directory contains example projects demonstrating how to use each PulseKit SDK.

## Prerequisites

1. **PulseKit running locally**: Start PulseKit using Docker:
   ```bash
   cd docker
   docker compose up -d
   ```

2. **Create a project**: Open http://localhost:4000/projects/new and create a test project

3. **Get an API key**: Click on your project and create a new API key

4. **Set the API key**: Either:
   - Set the `PULSEKIT_API_KEY` environment variable
   - Or update the API key in each example file

## TypeScript Example

```bash
cd typescript
npm install
npm test
```

Or with the API key:
```bash
cd typescript
npm install
PULSEKIT_API_KEY=pk_your_key npm test
```

## Go Example

```bash
cd go
go run main.go
```

Or with the API key:
```bash
cd go
PULSEKIT_API_KEY=pk_your_key go run main.go
```

## Elixir Example

```bash
cd elixir
mix deps.get
mix run test_pulsekit.exs
```

Or with the API key:
```bash
cd elixir
mix deps.get
PULSEKIT_API_KEY=pk_your_key mix run test_pulsekit.exs
```

## What the Tests Do

Each example:
1. Sends a custom info event
2. Captures an exception
3. Sends a business event (payment success)
4. Sends a warning event
5. Flushes remaining events

After running, check http://localhost:4000 to see your events in the dashboard!

## Troubleshooting

### "Invalid API key" error
Make sure you've:
1. Created a project in PulseKit
2. Generated an API key for the project
3. Set the `PULSEKIT_API_KEY` environment variable or updated the key in the example file

### Connection refused
Make sure PulseKit is running:
```bash
docker ps --filter "name=pulsekit"
```

If not running:
```bash
cd docker
docker compose up -d
```

### Events not appearing
1. Wait a few seconds and refresh the dashboard
2. Make sure you're looking at the correct project
3. Check the browser console for any errors

