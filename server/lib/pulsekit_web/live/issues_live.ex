defmodule PulsekitWeb.IssuesLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Issues
  alias Pulsekit.Events
  alias PulsekitWeb.LiveHelpers
  alias PulsekitWeb.CoreComponents

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Issues")
      |> assign(:current_path, "/issues")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> assign(:status_filter, nil)
      |> assign(:level_filter, nil)
      |> assign(:environment_filter, nil)
      |> assign(:project_filter, nil)
      |> assign(:time_range, "24h")
      |> assign(:issues, [])
      |> assign(:issue_stats, %{total: 0, unresolved: 0, resolved: 0, ignored: 0})
      |> assign(:environments, [])
      |> load_environments()
      |> load_issues()

    if connected?(socket) and socket.assigns.current_organization do
      Events.subscribe_organization(socket.assigns.current_organization.id)
    end

    {:ok, socket}
  end

  defp load_projects(socket) do
    projects =
      case socket.assigns.current_organization do
        nil -> []
        org -> Projects.list_projects_for_organization(org.id)
      end

    socket
    |> assign(:projects, projects)
  end

  defp load_environments(socket) do
    case socket.assigns.current_organization do
      nil -> assign(socket, :environments, [])
      org -> assign(socket, :environments, Events.get_environments_for_organization(org.id))
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_project", %{"project" => project_id}, socket) do
    project_id = if project_id == "", do: nil, else: project_id

    socket =
      socket
      |> assign(:project_filter, project_id)
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status

    socket =
      socket
      |> assign(:status_filter, status)
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_level", %{"level" => level}, socket) do
    level = if level == "", do: nil, else: level

    socket =
      socket
      |> assign(:level_filter, level)
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_environment", %{"environment" => env}, socket) do
    env = if env == "", do: nil, else: env

    socket =
      socket
      |> assign(:environment_filter, env)
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_event("time_range_changed", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:time_range, range)
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve_issue", %{"fingerprint" => fingerprint, "project_id" => project_id}, socket) do
    case Issues.resolve_issue(project_id, fingerprint) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_issues()
         |> put_flash(:info, "Issue resolved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve issue")}
    end
  end

  @impl true
  def handle_event("ignore_issue", %{"fingerprint" => fingerprint, "project_id" => project_id}, socket) do
    case Issues.ignore_issue(project_id, fingerprint) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_issues()
         |> put_flash(:info, "Issue ignored")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to ignore issue")}
    end
  end

  @impl true
  def handle_event("reopen_issue", %{"fingerprint" => fingerprint, "project_id" => project_id}, socket) do
    case Issues.reopen_issue(project_id, fingerprint) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_issues()
         |> put_flash(:info, "Issue reopened")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reopen issue")}
    end
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:status_filter, nil)
      |> assign(:level_filter, nil)
      |> assign(:environment_filter, nil)
      |> assign(:project_filter, nil)
      |> assign(:time_range, "24h")
      |> load_issues()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_event, _event}, socket) do
    {:noreply, load_issues(socket)}
  end

  @impl true
  def handle_info({:events_batch, _count}, socket) do
    {:noreply, load_issues(socket)}
  end

  defp load_issues(socket) do
    case socket.assigns.current_organization do
      nil ->
        socket
        |> assign(:issues, [])
        |> assign(:issue_stats, %{total: 0, unresolved: 0, resolved: 0, ignored: 0})

      org ->
        since = CoreComponents.time_range_to_since(socket.assigns.time_range)

        opts = [
          limit: 100,
          status: socket.assigns.status_filter,
          level: socket.assigns.level_filter,
          environment: socket.assigns.environment_filter,
          project_id: socket.assigns.project_filter,
          since: since
        ]

        issues = Issues.list_issues_for_organization(org.id, opts)
        stats = Issues.get_issue_stats_for_organization(org.id, since: since)

        socket
        |> assign(:issues, issues)
        |> assign(:issue_stats, stats)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-start justify-between flex-wrap gap-4">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Issues</h1>
            <p class="text-base-content/60 mt-1">
              <%= if @current_organization do %>
                Grouped errors and events across <span class="font-medium text-base-content">{@current_organization.name}</span>
              <% else %>
                Grouped errors and events by fingerprint
              <% end %>
            </p>
          </div>

          <div class="flex items-center gap-3 flex-wrap">
            <%!-- Time Range Selector --%>
            <%= if @current_organization do %>
              <.time_range_selector selected={@time_range} on_change="time_range_changed" />
            <% end %>
          </div>
        </div>

        <%= if @current_organization do %>
          <%!-- Stats Cards --%>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <.stat_card
              title="Total Issues"
              value={@issue_stats.total}
              icon="hero-bug-ant"
              color="primary"
            />
            <.stat_card
              title="Unresolved"
              value={@issue_stats.unresolved}
              icon="hero-exclamation-circle"
              color="error"
            />
            <.stat_card
              title="Resolved"
              value={@issue_stats.resolved}
              icon="hero-check-circle"
              color="success"
            />
            <.stat_card
              title="Ignored"
              value={@issue_stats.ignored}
              icon="hero-eye-slash"
              color="warning"
            />
          </div>

          <%!-- Filters --%>
          <div class="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
            <div class="flex flex-wrap items-center gap-3">
              <%!-- Project Filter --%>
              <%= if length(@projects) > 0 do %>
                <select
                  name="project"
                  class="px-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm font-medium focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                  phx-change="filter_project"
                >
                  <option value="">All Projects</option>
                  <%= for project <- @projects do %>
                    <option value={project.id} selected={@project_filter == project.id}>
                      {project.name}
                    </option>
                  <% end %>
                </select>
              <% end %>

              <%!-- Status Filter --%>
              <select
                name="status"
                class="px-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm font-medium focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                phx-change="filter_status"
              >
                <option value="">All Statuses</option>
                <option value="unresolved" selected={@status_filter == "unresolved"}>Unresolved</option>
                <option value="resolved" selected={@status_filter == "resolved"}>Resolved</option>
                <option value="ignored" selected={@status_filter == "ignored"}>Ignored</option>
              </select>

              <%!-- Level Filter --%>
              <select
                name="level"
                class="px-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm font-medium focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                phx-change="filter_level"
              >
                <option value="">All Levels</option>
                <option value="fatal" selected={@level_filter == "fatal"}>Fatal</option>
                <option value="error" selected={@level_filter == "error"}>Error</option>
                <option value="warning" selected={@level_filter == "warning"}>Warning</option>
                <option value="info" selected={@level_filter == "info"}>Info</option>
                <option value="debug" selected={@level_filter == "debug"}>Debug</option>
              </select>

              <%!-- Environment Filter --%>
              <%= if length(@environments) > 0 do %>
                <select
                  name="environment"
                  class="px-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm font-medium focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                  phx-change="filter_environment"
                >
                  <option value="">All Environments</option>
                  <%= for env <- @environments do %>
                    <option value={env} selected={@environment_filter == env}>
                      {env}
                    </option>
                  <% end %>
                </select>
              <% end %>

              <%!-- Clear Filters --%>
              <%= if @status_filter || @level_filter || @environment_filter || @project_filter do %>
                <button
                  phx-click="clear_filters"
                  class="flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium text-base-content/70 hover:text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                  Clear filters
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Issues List --%>
          <div class="space-y-3">
            <%= if length(@issues) == 0 do %>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
                <div class="flex flex-col items-center text-center py-16 px-6">
                  <div class="w-16 h-16 rounded-xl bg-primary/10 flex items-center justify-center mb-4">
                    <.icon name="hero-check-badge" class="w-8 h-8 text-primary" />
                  </div>
                  <h2 class="text-lg font-semibold text-base-content">No issues found</h2>
                  <p class="text-base-content/60 text-sm mt-1">
                    <%= if @status_filter || @level_filter || @project_filter do %>
                      Try adjusting your filters
                    <% else %>
                      No events have been captured yet
                    <% end %>
                  </p>
                </div>
              </div>
            <% else %>
              <%= for issue <- @issues do %>
                <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm hover:shadow-md transition-shadow duration-150 overflow-hidden">
                  <div class="p-5">
                    <div class="flex items-start gap-4">
                      <%!-- Level indicator --%>
                      <div class={[
                        "w-1.5 h-12 rounded-full flex-shrink-0 mt-0.5",
                        level_color(issue.level)
                      ]} />

                      <%!-- Issue content --%>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between gap-4">
                          <div class="min-w-0">
                            <div class="flex items-center gap-2 flex-wrap">
                              <.level_badge level={issue.level} />
                              <.status_badge status={issue.status} />
                              <%= if issue.project do %>
                                <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded bg-primary/10 text-xs font-semibold text-primary">
                                  <.icon name="hero-folder" class="w-3 h-3" />
                                  {issue.project.name}
                                </span>
                              <% end %>
                            </div>
                            <h3 class="font-semibold text-base-content mt-2 truncate">{issue.type}</h3>
                            <p class="text-sm text-base-content/60 truncate mt-1">{issue.last_message || "No message"}</p>
                          </div>

                          <%!-- Actions --%>
                          <div class="flex items-center gap-1 flex-shrink-0">
                            <%= cond do %>
                              <% issue.status == "unresolved" -> %>
                                <button
                                  phx-click="resolve_issue"
                                  phx-value-fingerprint={issue.fingerprint}
                                  phx-value-project_id={issue.project_id}
                                  class="p-2 rounded-lg hover:bg-success/10 transition-colors duration-150"
                                  title="Resolve"
                                >
                                  <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
                                </button>
                                <button
                                  phx-click="ignore_issue"
                                  phx-value-fingerprint={issue.fingerprint}
                                  phx-value-project_id={issue.project_id}
                                  class="p-2 rounded-lg hover:bg-warning/10 transition-colors duration-150"
                                  title="Ignore"
                                >
                                  <.icon name="hero-eye-slash" class="w-5 h-5 text-warning" />
                                </button>
                              <% issue.status in ["resolved", "ignored"] -> %>
                                <button
                                  phx-click="reopen_issue"
                                  phx-value-fingerprint={issue.fingerprint}
                                  phx-value-project_id={issue.project_id}
                                  class="p-2 rounded-lg hover:bg-base-200 transition-colors duration-150"
                                  title="Reopen"
                                >
                                  <.icon name="hero-arrow-path" class="w-5 h-5 text-base-content/70" />
                                </button>
                              <% true -> %>
                            <% end %>
                            <a
                              href={"/events?fingerprint=#{issue.fingerprint}"}
                              class="p-2 rounded-lg hover:bg-base-200 transition-colors duration-150"
                              title="View Events"
                            >
                              <.icon name="hero-arrow-right" class="w-5 h-5 text-base-content/50" />
                            </a>
                          </div>
                        </div>

                        <%!-- Stats row --%>
                        <div class="flex items-center gap-4 mt-4 pt-4 border-t border-base-200 flex-wrap">
                          <div class="flex items-center gap-1.5 text-sm">
                            <.icon name="hero-hashtag" class="w-4 h-4 text-base-content/40" />
                            <span class="font-semibold text-base-content">{format_count(issue.count)}</span>
                            <span class="text-base-content/50">events</span>
                          </div>
                          <div class="flex items-center gap-1.5 text-sm text-base-content/50">
                            <.icon name="hero-clock" class="w-4 h-4" />
                            <span>First seen {format_time_ago(issue.first_seen)}</span>
                          </div>
                          <div class="flex items-center gap-1.5 text-sm text-base-content/50">
                            <.icon name="hero-arrow-path" class="w-4 h-4" />
                            <span>Last seen {format_time_ago(issue.last_seen)}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% else %>
          <%!-- No Workspace State --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
            <div class="flex flex-col items-center text-center py-20 px-6">
              <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                <.icon name="hero-building-office-2" class="w-10 h-10 text-primary" />
              </div>
              <h2 class="text-xl font-semibold text-base-content">No workspace selected</h2>
              <p class="text-base-content/60 max-w-md mt-2">
                Select or create a workspace to start viewing issues.
              </p>
              <a
                href="/organizations"
                class="inline-flex items-center gap-2 mt-6 px-5 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Manage Workspaces
              </a>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "primary"

  defp stat_card(assigns) do
    icon_bg_class = case assigns.color do
      "primary" -> "bg-primary/10"
      "error" -> "bg-error/10"
      "success" -> "bg-success/10"
      "warning" -> "bg-warning/10"
      _ -> "bg-base-200"
    end

    icon_text_class = case assigns.color do
      "primary" -> "text-primary"
      "error" -> "text-error"
      "success" -> "text-success"
      "warning" -> "text-warning"
      _ -> "text-base-content"
    end

    assigns = assign(assigns, :icon_bg_class, icon_bg_class)
    assigns = assign(assigns, :icon_text_class, icon_text_class)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
      <div class="flex items-center gap-3">
        <div class={["p-2.5 rounded-lg", @icon_bg_class]}>
          <.icon name={@icon} class={["w-5 h-5", @icon_text_class]} />
        </div>
        <div>
          <p class="text-xs font-medium text-base-content/50 uppercase tracking-wider">{@title}</p>
          <p class="text-xl font-bold text-base-content">{format_number(@value)}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :level, :string, required: true

  defp level_badge(assigns) do
    {bg_class, text_class} = case assigns.level do
      "fatal" -> {"bg-error/15", "text-error"}
      "error" -> {"bg-error/15", "text-error"}
      "warning" -> {"bg-warning/15", "text-warning"}
      "info" -> {"bg-info/15", "text-info"}
      "debug" -> {"bg-base-200", "text-base-content/70"}
      _ -> {"bg-base-200", "text-base-content/70"}
    end

    assigns = assign(assigns, :bg_class, bg_class)
    assigns = assign(assigns, :text_class, text_class)

    ~H"""
    <span class={["inline-flex px-2 py-0.5 rounded text-xs font-semibold uppercase tracking-wide", @bg_class, @text_class]}>
      {@level}
    </span>
    """
  end

  attr :status, :string, required: true

  defp status_badge(assigns) do
    {bg_class, text_class, icon} = case assigns.status do
      "resolved" -> {"bg-success/15", "text-success", "hero-check-circle"}
      "ignored" -> {"bg-warning/15", "text-warning", "hero-eye-slash"}
      _ -> {"bg-base-200", "text-base-content/70", "hero-exclamation-circle"}
    end

    assigns = assign(assigns, :bg_class, bg_class)
    assigns = assign(assigns, :text_class, text_class)
    assigns = assign(assigns, :status_icon, icon)

    ~H"""
    <span class={["inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium", @bg_class, @text_class]}>
      <.icon name={@status_icon} class="w-3 h-3" />
      {String.capitalize(@status)}
    </span>
    """
  end

  defp level_color(level) do
    case level do
      "fatal" -> "bg-error"
      "error" -> "bg-error"
      "warning" -> "bg-warning"
      "info" -> "bg-info"
      "debug" -> "bg-base-300"
      _ -> "bg-base-300"
    end
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  defp format_count(count) when count >= 1000, do: "#{Float.round(count / 1000, 1)}k"
  defp format_count(count), do: "#{count}"

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
