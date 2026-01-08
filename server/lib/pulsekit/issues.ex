defmodule Pulsekit.Issues do
  @moduledoc """
  The Issues context - manages issue grouping and status tracking.
  Issues are groups of events with the same fingerprint.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Events.Event
  alias Pulsekit.Issues.IssueStatus
  alias Pulsekit.Projects
  alias Pulsekit.Projects.Project

  @doc """
  Lists issues (grouped events by fingerprint) for a project.
  Returns aggregated data including occurrence count, first/last seen, etc.
  """
  def list_issues(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    status_filter = Keyword.get(opts, :status)
    level_filter = Keyword.get(opts, :level)
    environment_filter = Keyword.get(opts, :environment)
    since = Keyword.get(opts, :since)

    # Base query for aggregating events by fingerprint
    # Note: SQLite doesn't support array_agg, so we fetch the latest message separately
    base_query =
      Event
      |> where([e], e.project_id == ^project_id)
      |> maybe_filter_since(since)
      |> maybe_filter_level(level_filter)
      |> maybe_filter_environment(environment_filter)
      |> group_by([e], [e.fingerprint, e.type, e.level])
      |> select([e], %{
        fingerprint: e.fingerprint,
        type: e.type,
        level: e.level,
        count: count(e.id),
        first_seen: min(e.timestamp),
        last_seen: max(e.timestamp)
      })
      |> order_by([e], desc: max(e.timestamp))
      |> limit(^limit)
      |> offset(^offset)

    issues = Repo.all(base_query)

    # Fetch the latest message for each issue
    issues = Enum.map(issues, fn issue ->
      last_message = get_latest_message(project_id, issue.fingerprint)
      Map.put(issue, :last_message, last_message)
    end)

    # Get fingerprints to fetch statuses
    fingerprints = Enum.map(issues, & &1.fingerprint)

    # Fetch statuses for these fingerprints
    statuses = get_statuses_map(project_id, fingerprints)

    # Merge status info into issues
    issues =
      Enum.map(issues, fn issue ->
        status = Map.get(statuses, issue.fingerprint, %{status: "unresolved", id: nil})
        Map.merge(issue, %{status: status.status, status_id: status.id})
      end)

    # Filter by status if requested
    case status_filter do
      nil -> issues
      status -> Enum.filter(issues, &(&1.status == status))
    end
  end

  @doc """
  Counts unique issues (unique fingerprints) for a project.
  """
  def count_issues(project_id, opts \\ []) do
    since = Keyword.get(opts, :since)
    level_filter = Keyword.get(opts, :level)
    environment_filter = Keyword.get(opts, :environment)

    Event
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_since(since)
    |> maybe_filter_level(level_filter)
    |> maybe_filter_environment(environment_filter)
    |> select([e], count(e.fingerprint, :distinct))
    |> Repo.one()
  end

  @doc """
  Gets a single issue by fingerprint with full details.
  """
  def get_issue(project_id, fingerprint) do
    issue =
      Event
      |> where([e], e.project_id == ^project_id and e.fingerprint == ^fingerprint)
      |> group_by([e], [e.fingerprint, e.type, e.level])
      |> select([e], %{
        fingerprint: e.fingerprint,
        type: e.type,
        level: e.level,
        count: count(e.id),
        first_seen: min(e.timestamp),
        last_seen: max(e.timestamp)
      })
      |> Repo.one()

    case issue do
      nil ->
        nil

      issue ->
        status = get_status(project_id, fingerprint)
        environments = get_issue_environments(project_id, fingerprint)

        Map.merge(issue, %{
          status: status.status,
          status_id: status.id,
          environments: environments
        })
    end
  end

  @doc """
  Gets events for a specific issue (by fingerprint).
  """
  def get_issue_events(project_id, fingerprint, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    Event
    |> where([e], e.project_id == ^project_id and e.fingerprint == ^fingerprint)
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&Event.decode_json_fields/1)
  end

  @doc """
  Gets unique environments for an issue.
  """
  def get_issue_environments(project_id, fingerprint) do
    Event
    |> where([e], e.project_id == ^project_id and e.fingerprint == ^fingerprint)
    |> where([e], not is_nil(e.environment))
    |> group_by([e], e.environment)
    |> select([e], e.environment)
    |> Repo.all()
  end

  @doc """
  Updates the status of an issue.
  """
  def update_issue_status(project_id, fingerprint, status) when status in ["unresolved", "resolved", "ignored"] do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      status: status,
      resolved_at: if(status == "resolved", do: now, else: nil),
      ignored_at: if(status == "ignored", do: now, else: nil)
    }

    case Repo.get_by(IssueStatus, project_id: project_id, fingerprint: fingerprint) do
      nil ->
        %IssueStatus{}
        |> IssueStatus.create_changeset(Map.put(attrs, :fingerprint, fingerprint), project_id)
        |> Repo.insert()

      issue_status ->
        issue_status
        |> IssueStatus.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Resolves an issue.
  """
  def resolve_issue(project_id, fingerprint) do
    update_issue_status(project_id, fingerprint, "resolved")
  end

  @doc """
  Ignores an issue.
  """
  def ignore_issue(project_id, fingerprint) do
    update_issue_status(project_id, fingerprint, "ignored")
  end

  @doc """
  Reopens an issue (sets to unresolved).
  """
  def reopen_issue(project_id, fingerprint) do
    update_issue_status(project_id, fingerprint, "unresolved")
  end

  @doc """
  Gets issue stats (counts by status) for a project.
  """
  def get_issue_stats(project_id, opts \\ []) do
    since = Keyword.get(opts, :since)

    # Get total unique fingerprints
    total =
      Event
      |> where([e], e.project_id == ^project_id)
      |> maybe_filter_since(since)
      |> select([e], count(e.fingerprint, :distinct))
      |> Repo.one()

    # Get counts by status
    resolved_count =
      IssueStatus
      |> where([s], s.project_id == ^project_id and s.status == "resolved")
      |> select([s], count(s.id))
      |> Repo.one()

    ignored_count =
      IssueStatus
      |> where([s], s.project_id == ^project_id and s.status == "ignored")
      |> select([s], count(s.id))
      |> Repo.one()

    unresolved = max(total - resolved_count - ignored_count, 0)

    %{
      total: total,
      unresolved: unresolved,
      resolved: resolved_count,
      ignored: ignored_count
    }
  end

  # Organization-level (workspace) functions

  @doc """
  Lists issues across all projects in an organization (workspace).
  Returns aggregated data with project information.
  """
  def list_issues_for_organization(organization_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    status_filter = Keyword.get(opts, :status)
    level_filter = Keyword.get(opts, :level)
    environment_filter = Keyword.get(opts, :environment)
    project_filter = Keyword.get(opts, :project_id)
    since = Keyword.get(opts, :since)

    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      []
    else
      # Base query for aggregating events by fingerprint and project
      base_query =
        Event
        |> where([e], e.project_id in ^project_ids)
        |> maybe_filter_project(project_filter)
        |> maybe_filter_since(since)
        |> maybe_filter_level(level_filter)
        |> maybe_filter_environment(environment_filter)
        |> group_by([e], [e.fingerprint, e.type, e.level, e.project_id])
        |> select([e], %{
          fingerprint: e.fingerprint,
          type: e.type,
          level: e.level,
          project_id: e.project_id,
          count: count(e.id),
          first_seen: min(e.timestamp),
          last_seen: max(e.timestamp)
        })
        |> order_by([e], desc: max(e.timestamp))
        |> limit(^limit)
        |> offset(^offset)

      issues = Repo.all(base_query)

      # Build a map of project_id -> project for quick lookup
      projects_map = build_projects_map(project_ids)

      # Fetch the latest message for each issue and add project info
      issues = Enum.map(issues, fn issue ->
        last_message = get_latest_message(issue.project_id, issue.fingerprint)
        project = Map.get(projects_map, issue.project_id)
        issue
        |> Map.put(:last_message, last_message)
        |> Map.put(:project, project)
      end)

      # Get fingerprints with project_ids to fetch statuses
      fingerprint_project_pairs = Enum.map(issues, &{&1.fingerprint, &1.project_id})

      # Fetch statuses for these fingerprints (need to query per project)
      statuses = get_statuses_map_for_org(fingerprint_project_pairs)

      # Merge status info into issues
      issues =
        Enum.map(issues, fn issue ->
          key = {issue.fingerprint, issue.project_id}
          status = Map.get(statuses, key, %{status: "unresolved", id: nil})
          Map.merge(issue, %{status: status.status, status_id: status.id})
        end)

      # Filter by status if requested
      case status_filter do
        nil -> issues
        status -> Enum.filter(issues, &(&1.status == status))
      end
    end
  end

  @doc """
  Gets issue stats across all projects in an organization.
  """
  def get_issue_stats_for_organization(organization_id, opts \\ []) do
    since = Keyword.get(opts, :since)
    project_ids = get_project_ids_for_organization(organization_id)

    if project_ids == [] do
      %{total: 0, unresolved: 0, resolved: 0, ignored: 0}
    else
      # Get total unique fingerprints across all projects
      total =
        Event
        |> where([e], e.project_id in ^project_ids)
        |> maybe_filter_since(since)
        |> select([e], count(fragment("DISTINCT ? || '-' || ?", e.fingerprint, e.project_id)))
        |> Repo.one()

      # Get counts by status across all projects
      resolved_count =
        IssueStatus
        |> where([s], s.project_id in ^project_ids and s.status == "resolved")
        |> select([s], count(s.id))
        |> Repo.one()

      ignored_count =
        IssueStatus
        |> where([s], s.project_id in ^project_ids and s.status == "ignored")
        |> select([s], count(s.id))
        |> Repo.one()

      unresolved = max(total - resolved_count - ignored_count, 0)

      %{
        total: total,
        unresolved: unresolved,
        resolved: resolved_count,
        ignored: ignored_count
      }
    end
  end

  defp get_project_ids_for_organization(organization_id) do
    Projects.list_projects_for_organization(organization_id)
    |> Enum.map(& &1.id)
  end

  defp build_projects_map(project_ids) do
    Project
    |> where([p], p.id in ^project_ids)
    |> Repo.all()
    |> Map.new(fn p -> {p.id, p} end)
  end

  defp maybe_filter_project(query, nil), do: query
  defp maybe_filter_project(query, ""), do: query
  defp maybe_filter_project(query, project_id), do: where(query, [e], e.project_id == ^project_id)

  defp get_statuses_map_for_org(fingerprint_project_pairs) when is_list(fingerprint_project_pairs) do
    # Get unique project_ids
    project_ids = fingerprint_project_pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    IssueStatus
    |> where([s], s.project_id in ^project_ids)
    |> select([s], {{s.fingerprint, s.project_id}, %{status: s.status, id: s.id}})
    |> Repo.all()
    |> Map.new()
  end

  # Private helpers

  defp get_status(project_id, fingerprint) do
    case Repo.get_by(IssueStatus, project_id: project_id, fingerprint: fingerprint) do
      nil -> %{status: "unresolved", id: nil}
      status -> %{status: status.status, id: status.id}
    end
  end

  defp get_statuses_map(project_id, fingerprints) when is_list(fingerprints) do
    IssueStatus
    |> where([s], s.project_id == ^project_id and s.fingerprint in ^fingerprints)
    |> select([s], {s.fingerprint, %{status: s.status, id: s.id}})
    |> Repo.all()
    |> Map.new()
  end

  defp maybe_filter_since(query, nil), do: query
  defp maybe_filter_since(query, since), do: where(query, [e], e.timestamp >= ^since)

  defp maybe_filter_level(query, nil), do: query
  defp maybe_filter_level(query, level), do: where(query, [e], e.level == ^level)

  defp maybe_filter_environment(query, nil), do: query
  defp maybe_filter_environment(query, env), do: where(query, [e], e.environment == ^env)

  defp get_latest_message(project_id, fingerprint) do
    Event
    |> where([e], e.project_id == ^project_id and e.fingerprint == ^fingerprint)
    |> order_by([e], desc: e.timestamp)
    |> limit(1)
    |> select([e], e.message)
    |> Repo.one()
  end
end
