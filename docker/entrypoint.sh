#!/bin/bash
set -e

echo "Running database migrations..."
/app/bin/pulsekit eval "Pulsekit.Release.migrate()"

echo "Starting PulseKit server..."
exec /app/bin/pulsekit start

