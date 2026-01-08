defmodule PulseKit.Client do
  @moduledoc """
  GenServer for batching and sending events to PulseKit.
  """

  use GenServer

  @default_batch_size 10
  @default_flush_interval 5_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_event(event) do
    GenServer.cast(__MODULE__, {:send_event, event})
  end

  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    config = get_config()

    state = %{
      endpoint: config[:endpoint],
      api_key: config[:api_key],
      environment: config[:environment] || "production",
      release: config[:release],
      batch_size: config[:batch_size] || @default_batch_size,
      flush_interval: config[:flush_interval] || @default_flush_interval,
      queue: []
    }

    schedule_flush(state.flush_interval)

    {:ok, state}
  end

  @impl true
  def handle_cast({:send_event, event}, state) do
    enriched_event = enrich_event(event, state)
    new_queue = [enriched_event | state.queue]

    state = %{state | queue: new_queue}

    if length(new_queue) >= state.batch_size do
      {:noreply, do_flush(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    {:reply, :ok, do_flush(state)}
  end

  @impl true
  def handle_info(:flush, state) do
    schedule_flush(state.flush_interval)
    {:noreply, do_flush(state)}
  end

  # Private Functions

  defp get_config do
    Application.get_all_env(:pulsekit)
  end

  defp enrich_event(event, state) do
    event
    |> Map.put(:environment, state.environment)
    |> Map.put(:release, state.release)
    |> Map.put(:timestamp, DateTime.utc_now() |> DateTime.to_iso8601())
    |> Map.put(:level, normalize_level(event[:level]))
  end

  defp normalize_level(level) when is_atom(level), do: Atom.to_string(level)
  defp normalize_level(level) when is_binary(level), do: level
  defp normalize_level(_), do: "info"

  defp do_flush(%{queue: []} = state), do: state

  defp do_flush(%{queue: queue} = state) do
    events = Enum.reverse(queue)

    Task.start(fn ->
      send_events(events, state)
    end)

    %{state | queue: []}
  end

  defp send_events([event], state) do
    url = "#{state.endpoint}/api/v1/events"

    Req.post(url,
      json: event,
      headers: [
        {"content-type", "application/json"},
        {"x-pulsekit-key", state.api_key}
      ]
    )
  end

  defp send_events(events, state) do
    url = "#{state.endpoint}/api/v1/events/batch"

    Req.post(url,
      json: %{events: events},
      headers: [
        {"content-type", "application/json"},
        {"x-pulsekit-key", state.api_key}
      ]
    )
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end
end
