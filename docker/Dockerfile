# Build stage
FROM hexpm/elixir:1.16.0-erlang-26.2.1-debian-bookworm-20231009-slim AS build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set environment variables
ENV MIX_ENV=prod

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy mix files
COPY server/mix.exs server/mix.lock ./

# Install dependencies
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy config files
COPY server/config/config.exs server/config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY server/priv priv
COPY server/lib lib
COPY server/assets assets

# Copy runtime config
COPY server/config/runtime.exs config/

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Build the release
RUN mix release

# Runtime stage
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Set working directory
WORKDIR /app

# Create data directory for SQLite
RUN mkdir -p /app/data && chmod 755 /app/data

# Copy the release from build stage
COPY --from=build /app/_build/prod/rel/pulsekit ./

# Copy and set up entrypoint script
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV PHX_SERVER=true
ENV DATABASE_PATH=/app/data/pulsekit.db

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/api/v1/health || exit 1

# Run migrations and start the server
CMD ["/app/entrypoint.sh"]

