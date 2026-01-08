defmodule Pulsekit.Events do
  @moduledoc """
  The Events context - manages event ingestion and retrieval.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Events.Event
  alias Pulsekit.Projects
  alias Pulsekit.Projects.Project

  @pubsub Pulsekit.PubSub

  def list_events(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)
    since = Keyword.get(opts, :since)
    environment = Keyword.get(opts, :environment)
    fingerprint = Keyword.get(opts, :fingerprint)

    Event
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_level(level)
    |> maybe_filter_type(type)
    |> maybe_search(search)
    |> maybe_filter_since(since)
    |> maybe_filter_environment(environment)
    |> maybe_filter_fingerprint(fingerprint)
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&Event.decode_json_fields/1)
  end

  @doc """
  Lists events across all projects in an organization (workspace).
  Returns events with preloaded project association.
  """
  def list_events_for_organization(organization_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)
    since = Keyword.get(opts, :since)
    environment = Keyword.get(opts, :environment)
    project_id = Keyword.get(opts, :project_id)

    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      []
    else
      Event
      |> where([e], e.project_id in ^project_ids)
      |> maybe_filter_project(project_id)
      |> maybe_filter_level(level)
      |> maybe_filter_type(type)
      |> maybe_search(search)
      |> maybe_filter_since(since)
      |> maybe_filter_environment(environment)
      |> order_by([e], desc: e.timestamp)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:project)
      |> Repo.all()
      |> Enum.map(&Event.decode_json_fields/1)
    end
  end

  @doc """
  Counts events across all projects in an organization.
  """
  def count_events_for_organization(organization_id, opts \\ []) do
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)
    since = Keyword.get(opts, :since)
    environment = Keyword.get(opts, :environment)
    project_id = Keyword.get(opts, :project_id)

    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      0
    else
      Event
      |> where([e], e.project_id in ^project_ids)
      |> maybe_filter_project(project_id)
      |> maybe_filter_level(level)
      |> maybe_filter_type(type)
      |> maybe_search(search)
      |> maybe_filter_since(since)
      |> maybe_filter_environment(environment)
      |> Repo.aggregate(:count)
    end
  end

  @doc """
  Gets event stats across all projects in an organization.
  """
  def get_event_stats_for_organization(organization_id, since \\ nil) do
    since = since || get_time_since(:day)
    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      %{}
    else
      Event
      |> where([e], e.project_id in ^project_ids and e.timestamp >= ^since)
      |> group_by([e], e.level)
      |> select([e], {e.level, count(e.id)})
      |> Repo.all()
      |> Map.new()
    end
  end

  @doc """
  Gets recent event types across all projects in an organization.
  """
  def get_recent_event_types_for_organization(organization_id, limit \\ 10, since \\ nil) do
    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      []
    else
      query =
        Event
        |> where([e], e.project_id in ^project_ids)
        |> group_by([e], e.type)
        |> select([e], {e.type, count(e.id)})
        |> order_by([e], desc: count(e.id))
        |> limit(^limit)

      query =
        if since do
          where(query, [e], e.timestamp >= ^since)
        else
          query
        end

      Repo.all(query)
    end
  end

  @doc """
  Gets event timeline data across all projects in an organization.
  """
  def get_event_timeline_for_organization(organization_id, time_range, opts \\ []) do
    level = Keyword.get(opts, :level)
    project_id = Keyword.get(opts, :project_id)
    {since, bucket_minutes} = timeline_params(time_range)
    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      []
    else
      query =
        Event
        |> where([e], e.project_id in ^project_ids and e.timestamp >= ^since)
        |> maybe_filter_level(level)
        |> maybe_filter_project(project_id)
        |> select([e], e.timestamp)
        |> order_by([e], asc: e.timestamp)

      events = Repo.all(query)

      now = DateTime.utc_now()
      buckets = generate_time_buckets(since, now, bucket_minutes)

      Enum.map(buckets, fn bucket_start ->
        bucket_end = DateTime.add(bucket_start, bucket_minutes, :minute)
        count = Enum.count(events, fn ts ->
          DateTime.compare(ts, bucket_start) != :lt and DateTime.compare(ts, bucket_end) == :lt
        end)
        {bucket_start, count}
      end)
    end
  end

  @doc """
  Gets unique environments across all projects in an organization.
  """
  def get_environments_for_organization(organization_id) do
    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      []
    else
      Event
      |> where([e], e.project_id in ^project_ids)
      |> where([e], not is_nil(e.environment))
      |> group_by([e], e.environment)
      |> select([e], e.environment)
      |> Repo.all()
      |> Enum.sort()
    end
  end

  defp get_project_ids_for_organization(organization_id) do
    Projects.list_projects_for_organization(organization_id)
    |> Enum.map(& &1.id)
  end

  defp maybe_filter_project(query, nil), do: query
  defp maybe_filter_project(query, ""), do: query
  defp maybe_filter_project(query, project_id), do: where(query, [e], e.project_id == ^project_id)

  def count_events(project_id, opts \\ []) do
    level = Keyword.get(opts, :level)
    type = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)
    since = Keyword.get(opts, :since)
    environment = Keyword.get(opts, :environment)

    Event
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_level(level)
    |> maybe_filter_type(type)
    |> maybe_search(search)
    |> maybe_filter_since(since)
    |> maybe_filter_environment(environment)
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

    # Broadcast batch event to project subscribers
    Phoenix.PubSub.broadcast(@pubsub, "events:#{project_id}", {:events_batch, count})

    # Also broadcast to org-level subscribers
    case Repo.get(Project, project_id) do
      nil -> :ok
      project ->
        Phoenix.PubSub.broadcast(@pubsub, "events:org:#{project.organization_id}", {:events_batch, count})
    end

    {:ok, count}
  end

  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  def get_event_stats(project_id, since \\ nil) do
    since = since || get_time_since(:day)

    Event
    |> where([e], e.project_id == ^project_id and e.timestamp >= ^since)
    |> group_by([e], e.level)
    |> select([e], {e.level, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  def get_recent_event_types(project_id, limit \\ 10, since \\ nil) do
    query =
      Event
      |> where([e], e.project_id == ^project_id)
      |> group_by([e], e.type)
      |> select([e], {e.type, count(e.id)})
      |> order_by([e], desc: count(e.id))
      |> limit(^limit)

    query =
      if since do
        where(query, [e], e.timestamp >= ^since)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets unique environments for a project.
  """
  def get_environments(project_id) do
    Event
    |> where([e], e.project_id == ^project_id)
    |> where([e], not is_nil(e.environment))
    |> group_by([e], e.environment)
    |> select([e], e.environment)
    |> Repo.all()
    |> Enum.sort()
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

  defp maybe_filter_since(query, nil), do: query
  defp maybe_filter_since(query, since), do: where(query, [e], e.timestamp >= ^since)

  defp maybe_filter_environment(query, nil), do: query
  defp maybe_filter_environment(query, ""), do: query
  defp maybe_filter_environment(query, env), do: where(query, [e], e.environment == ^env)

  defp maybe_filter_fingerprint(query, nil), do: query
  defp maybe_filter_fingerprint(query, ""), do: query
  defp maybe_filter_fingerprint(query, fingerprint), do: where(query, [e], e.fingerprint == ^fingerprint)

  defp get_time_since(:day), do: DateTime.add(DateTime.utc_now(), -1, :day)

  defp broadcast_event(project_id, event) do
    Phoenix.PubSub.broadcast(@pubsub, "events:#{project_id}", {:new_event, event})
    # Also broadcast to org-level subscribers by fetching the project's org
    case Repo.get(Project, project_id) do
      nil -> :ok
      project ->
        event_with_project = %{event | project: project}
        Phoenix.PubSub.broadcast(@pubsub, "events:org:#{project.organization_id}", {:new_event, event_with_project})
    end
  end

  def subscribe(project_id) do
    Phoenix.PubSub.subscribe(@pubsub, "events:#{project_id}")
  end

  @doc """
  Subscribes to events across all projects in an organization.
  """
  def subscribe_organization(organization_id) do
    Phoenix.PubSub.subscribe(@pubsub, "events:org:#{organization_id}")
  end

  @doc """
  Unsubscribes from organization-level events.
  """
  def unsubscribe_organization(organization_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, "events:org:#{organization_id}")
  end

  @doc """
  Gets event timeline data for charting.
  Returns a list of {datetime, count} tuples bucketed by the appropriate interval.
  """
  def get_event_timeline(project_id, time_range, opts \\ []) do
    level = Keyword.get(opts, :level)
    {since, bucket_minutes} = timeline_params(time_range)

    # Get all events in the time range
    events =
      Event
      |> where([e], e.project_id == ^project_id and e.timestamp >= ^since)
      |> maybe_filter_level(level)
      |> select([e], e.timestamp)
      |> order_by([e], asc: e.timestamp)
      |> Repo.all()

    # Generate time buckets
    now = DateTime.utc_now()
    buckets = generate_time_buckets(since, now, bucket_minutes)

    # Count events per bucket
    Enum.map(buckets, fn bucket_start ->
      bucket_end = DateTime.add(bucket_start, bucket_minutes, :minute)
      count = Enum.count(events, fn ts ->
        DateTime.compare(ts, bucket_start) != :lt and DateTime.compare(ts, bucket_end) == :lt
      end)
      {bucket_start, count}
    end)
  end

  defp timeline_params("1h"), do: {DateTime.add(DateTime.utc_now(), -1, :hour), 5}
  defp timeline_params("6h"), do: {DateTime.add(DateTime.utc_now(), -6, :hour), 15}
  defp timeline_params("24h"), do: {DateTime.add(DateTime.utc_now(), -24, :hour), 60}
  defp timeline_params("7d"), do: {DateTime.add(DateTime.utc_now(), -7, :day), 360}
  defp timeline_params("30d"), do: {DateTime.add(DateTime.utc_now(), -30, :day), 1440}
  defp timeline_params(_), do: {DateTime.add(DateTime.utc_now(), -24, :hour), 60}

  defp generate_time_buckets(start_time, end_time, bucket_minutes) do
    start_time = DateTime.truncate(start_time, :second)
    end_time = DateTime.truncate(end_time, :second)

    Stream.unfold(start_time, fn current ->
      if DateTime.compare(current, end_time) == :lt do
        next = DateTime.add(current, bucket_minutes, :minute)
        {current, next}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end
end
