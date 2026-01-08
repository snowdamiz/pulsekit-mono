defmodule PulsekitWeb.DashboardLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Events
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_path, "/")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> load_stats()

    if connected?(socket) and socket.assigns.selected_project do
      Events.subscribe(socket.assigns.selected_project.id)
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
    |> assign(:selected_project, List.first(projects))
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)

    # Unsubscribe from old project
    if socket.assigns.selected_project do
      Phoenix.PubSub.unsubscribe(Pulsekit.PubSub, "events:#{socket.assigns.selected_project.id}")
    end

    # Subscribe to new project
    Events.subscribe(project.id)

    socket =
      socket
      |> assign(:selected_project, project)
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_event, _event}, socket) do
    {:noreply, load_stats(socket)}
  end

  @impl true
  def handle_info({:events_batch, _count}, socket) do
    {:noreply, load_stats(socket)}
  end

  defp load_stats(socket) do
    case socket.assigns.selected_project do
      nil ->
        socket
        |> assign(:stats, %{})
        |> assign(:recent_events, [])
        |> assign(:event_types, [])
        |> assign(:total_events, 0)

      project ->
        stats = Events.get_event_stats(project.id, :day)
        recent_events = Events.list_events(project.id, limit: 10)
        event_types = Events.get_recent_event_types(project.id, 5)
        total_events = Events.count_events(project.id)

        socket
        |> assign(:stats, stats)
        |> assign(:recent_events, recent_events)
        |> assign(:event_types, event_types)
        |> assign(:total_events, total_events)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Dashboard</h1>
            <p class="text-base-content/60 mt-1">Monitor your application health</p>
          </div>

          <%= if length(@projects) > 0 do %>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-outline gap-2">
                <.icon name="hero-folder" class="w-4 h-4" />
                {if @selected_project, do: @selected_project.name, else: "Select Project"}
                <.icon name="hero-chevron-down" class="w-4 h-4" />
              </div>
              <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-52 border border-base-300">
                <%= for project <- @projects do %>
                  <li>
                    <button
                      phx-click="select_project"
                      phx-value-id={project.id}
                      class={[if(@selected_project && @selected_project.id == project.id, do: "active")]}
                    >
                      {project.name}
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>

        <%= if length(@projects) == 0 do %>
          <%!-- Empty state --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body items-center text-center py-16">
              <.icon name="hero-folder-plus" class="w-16 h-16 text-base-content/30" />
              <h2 class="card-title mt-4">No projects yet</h2>
              <p class="text-base-content/60 max-w-md">
                Create your first project to start tracking events and errors from your applications.
              </p>
              <div class="card-actions mt-4">
                <a href="/projects/new" class="btn btn-primary">
                  <.icon name="hero-plus" class="w-4 h-4" />
                  Create Project
                </a>
              </div>
            </div>
          </div>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.stat_card
              title="Total Events"
              value={@total_events}
              icon="hero-chart-bar"
              color="primary"
            />
            <.stat_card
              title="Errors"
              value={Map.get(@stats, "error", 0) + Map.get(@stats, "fatal", 0)}
              icon="hero-exclamation-circle"
              color="error"
            />
            <.stat_card
              title="Warnings"
              value={Map.get(@stats, "warning", 0)}
              icon="hero-exclamation-triangle"
              color="warning"
            />
            <.stat_card
              title="Info"
              value={Map.get(@stats, "info", 0) + Map.get(@stats, "debug", 0)}
              icon="hero-information-circle"
              color="info"
            />
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Recent Events --%>
            <div class="lg:col-span-2">
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <div class="flex items-center justify-between mb-4">
                    <h2 class="card-title text-lg">Recent Events</h2>
                    <a href="/events" class="btn btn-ghost btn-sm">View All</a>
                  </div>

                  <%= if length(@recent_events) == 0 do %>
                    <div class="text-center py-8 text-base-content/60">
                      <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p>No events yet</p>
                    </div>
                  <% else %>
                    <div class="space-y-2">
                      <%= for event <- @recent_events do %>
                        <a
                          href={"/events/#{event.id}"}
                          class="flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 transition-colors"
                        >
                          <.level_badge level={event.level} />
                          <div class="flex-1 min-w-0">
                            <p class="font-medium truncate">{event.type}</p>
                            <p class="text-sm text-base-content/60 truncate">{event.message || "No message"}</p>
                          </div>
                          <span class="text-xs text-base-content/50 whitespace-nowrap">
                            {format_time_ago(event.timestamp)}
                          </span>
                        </a>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Event Types --%>
            <div>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4">Top Event Types</h2>

                  <%= if length(@event_types) == 0 do %>
                    <div class="text-center py-8 text-base-content/60">
                      <p>No data available</p>
                    </div>
                  <% else %>
                    <div class="space-y-3">
                      <%= for {type, count} <- @event_types do %>
                        <div class="flex items-center justify-between">
                          <span class="font-medium truncate">{type}</span>
                          <span class="badge badge-ghost">{count}</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
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
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-sm text-base-content/60">{@title}</p>
            <p class="text-3xl font-bold mt-1">{format_number(@value)}</p>
          </div>
          <div class={"p-3 rounded-full bg-#{@color}/10"}>
            <.icon name={@icon} class={"w-6 h-6 text-#{@color}"} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :level, :string, required: true

  defp level_badge(assigns) do
    color = case assigns.level do
      "fatal" -> "bg-error text-error-content"
      "error" -> "bg-error text-error-content"
      "warning" -> "bg-warning text-warning-content"
      "info" -> "bg-info text-info-content"
      "debug" -> "bg-base-300 text-base-content"
      _ -> "bg-base-300 text-base-content"
    end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"px-2 py-1 rounded text-xs font-medium uppercase #{@color}"}>
      {@level}
    </span>
    """
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

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
