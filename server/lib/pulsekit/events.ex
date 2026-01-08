defmodule Pulsekit.Events do
  @moduledoc """
  The Events context - manages event ingestion and retrieval.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Events.Event

  @pubsub Pulsekit.PubSub

  def list_events(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)

    Event
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_level(level)
    |> maybe_filter_type(type)
    |> maybe_search(search)
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&Event.decode_json_fields/1)
  end

  def count_events(project_id, opts \\ []) do
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)

    Event
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_level(level)
    |> maybe_filter_type(type)
    |> maybe_search(search)
    |> Repo.aggregate(:count)
  end

  def get_event!(id) do
    Event
    |> Repo.get!(id)
    |> Event.decode_json_fields()
  end

  def get_event(id) do
    case Repo.get(Event, id) do
      nil -> nil
      event -> Event.decode_json_fields(event)
    end
  end

  def create_event(project_id, attrs \\ %{}) do
    result =
      %Event{}
      |> Event.create_changeset(attrs, project_id)
      |> Repo.insert()

    case result do
      {:ok, event} ->
        event = Event.decode_json_fields(event)
        broadcast_event(project_id, event)
        {:ok, event}

      error ->
        error
    end
  end

  def create_events(project_id, events_attrs) when is_list(events_attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events =
      Enum.map(events_attrs, fn attrs ->
        changeset = Event.create_changeset(%Event{}, attrs, project_id)

        if changeset.valid? do
          changes = changeset.changes
          %{
            id: Ecto.UUID.generate(),
            project_id: project_id,
            type: changes[:type],
            level: changes[:level] || "info",
            message: changes[:message],
            metadata: changes[:metadata],
            stacktrace: changes[:stacktrace],
            environment: changes[:environment],
            release: changes[:release],
            tags: changes[:tags],
            fingerprint: changes[:fingerprint],
            timestamp: changes[:timestamp] || now,
            inserted_at: now,
            updated_at: now
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {count, _} = Repo.insert_all(Event, events)

    # Broadcast batch event
    Phoenix.PubSub.broadcast(@pubsub, "events:#{project_id}", {:events_batch, count})

    {:ok, count}
  end

  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  def get_event_stats(project_id, time_range \\ :day) do
    since = get_time_since(time_range)

    Event
    |> where([e], e.project_id == ^project_id and e.timestamp >= ^since)
    |> group_by([e], e.level)
    |> select([e], {e.level, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  def get_recent_event_types(project_id, limit \\ 10) do
    Event
    |> where([e], e.project_id == ^project_id)
    |> group_by([e], e.type)
    |> select([e], {e.type, count(e.id)})
    |> order_by([e], desc: count(e.id))
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_level(query, nil), do: query
  defp maybe_filter_level(query, level), do: where(query, [e], e.level == ^level)

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [e], e.type == ^type)

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query
  defp maybe_search(query, search) do
    search_term = "%#{search}%"
    where(query, [e], like(e.message, ^search_term) or like(e.type, ^search_term))
  end

  defp get_time_since(:hour), do: DateTime.add(DateTime.utc_now(), -1, :hour)
  defp get_time_since(:day), do: DateTime.add(DateTime.utc_now(), -1, :day)
  defp get_time_since(:week), do: DateTime.add(DateTime.utc_now(), -7, :day)
  defp get_time_since(:month), do: DateTime.add(DateTime.utc_now(), -30, :day)

  defp broadcast_event(project_id, event) do
    Phoenix.PubSub.broadcast(@pubsub, "events:#{project_id}", {:new_event, event})
  end

  def subscribe(project_id) do
    Phoenix.PubSub.subscribe(@pubsub, "events:#{project_id}")
  end
end
