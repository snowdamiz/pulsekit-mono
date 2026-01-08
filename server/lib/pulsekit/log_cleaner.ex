defmodule Pulsekit.LogCleaner do
  @moduledoc """
  GenServer that periodically cleans up old events based on the log retention setting.
  Runs daily to delete events older than the configured retention period.
  """

  use GenServer
  require Logger

  import Ecto.Query
  alias Pulsekit.Repo
  alias Pulsekit.Events.Event
  alias Pulsekit.Settings

  # Run cleanup every 24 hours (in milliseconds)
  @cleanup_interval :timer.hours(24)

  # For dev/test, you can use a shorter interval
  # @cleanup_interval :timer.minutes(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule first cleanup after a short delay to allow app to fully start
    schedule_cleanup(5_000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_events()
    schedule_cleanup(@cleanup_interval)
    {:noreply, state}
  end

  @doc """
  Manually triggers a cleanup. Useful for testing or manual intervention.
  """
  def cleanup_now do
    GenServer.cast(__MODULE__, :cleanup_now)
  end

  @impl true
  def handle_cast(:cleanup_now, state) do
    cleanup_old_events()
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp cleanup_old_events do
    retention_days = Settings.log_retention_days()

    if retention_days == 0 do
      Logger.debug("Log retention set to forever, skipping cleanup")
      :ok
    else
      cutoff_date = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

      {deleted_count, _} =
        Event
        |> where([e], e.timestamp < ^cutoff_date)
        |> Repo.delete_all()

      if deleted_count > 0 do
        Logger.info("LogCleaner: Deleted #{deleted_count} events older than #{retention_days} days")
      else
        Logger.debug("LogCleaner: No events to clean up")
      end

      {:ok, deleted_count}
    end
  end
end
