defmodule Pulsekit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PulsekitWeb.Telemetry,
      Pulsekit.Repo,
      {DNSCluster, query: Application.get_env(:pulsekit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pulsekit.PubSub},
      # Log cleanup worker - runs daily to delete old events
      Pulsekit.LogCleaner,
      # Start to serve requests, typically the last entry
      PulsekitWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pulsekit.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Ensure master user exists after supervisor starts
    ensure_master_user()

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PulsekitWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp ensure_master_user do
    # Run in a separate task to not block application startup
    Task.start(fn ->
      # Small delay to ensure repo is fully ready
      Process.sleep(100)
      Pulsekit.Accounts.ensure_master_user()
    end)
  end
end
