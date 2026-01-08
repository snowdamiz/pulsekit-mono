defmodule PulsekitWeb.DashboardLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Events
  alias PulsekitWeb.LiveHelpers
  alias PulsekitWeb.CoreComponents

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_path, "/")
      |> assign(:time_range, "24h")
      |> assign(:fullscreen, false)
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> load_stats()

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

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("time_range_changed", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:time_range, range)
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  @impl true
  def handle_event("exit_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, false)}
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
    case socket.assigns.current_organization do
      nil ->
        socket
        |> assign(:stats, %{})
        |> assign(:recent_events, [])
        |> assign(:event_types, [])
        |> assign(:total_events, 0)
        |> assign(:timeline_data, [])

      org ->
        since = CoreComponents.time_range_to_since(socket.assigns.time_range)
        stats = Events.get_event_stats_for_organization(org.id, since)
        recent_events = Events.list_events_for_organization(org.id, limit: 10, since: since)
        event_types = Events.get_recent_event_types_for_organization(org.id, 5, since)
        total_events = Events.count_events_for_organization(org.id, since: since)
        timeline_data = Events.get_event_timeline_for_organization(org.id, socket.assigns.time_range)

        socket
        |> assign(:stats, stats)
        |> assign(:recent_events, recent_events)
        |> assign(:event_types, event_types)
        |> assign(:total_events, total_events)
        |> assign(:timeline_data, timeline_data)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations} fullscreen={@fullscreen}>
      <div class="space-y-8">
        <%!-- Header --%>
        <div class="flex items-start justify-between flex-wrap gap-4">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Dashboard</h1>
            <p class={["text-base-content/60 mt-1", @fullscreen && "hidden"]}>
              <%= if @current_organization do %>
                Workspace overview for <span class="font-medium text-base-content">{@current_organization.name}</span>
              <% else %>
                Monitor your application health and track events in real-time
              <% end %>
            </p>
          </div>

          <div class="flex items-center gap-3 flex-wrap">
            <%!-- Time Range Selector --%>
            <%= if @current_organization do %>
              <.time_range_selector selected={@time_range} on_change="time_range_changed" />
            <% end %>

            <%!-- Fullscreen Toggle --%>
            <button
              id="fullscreen-toggle"
              phx-click="toggle_fullscreen"
              phx-hook="Fullscreen"
              data-fullscreen={@fullscreen}
              class={[
                "group relative flex items-center justify-center p-2.5 rounded-lg text-sm font-medium transition-all duration-200",
                "border border-base-300 hover:border-primary/30",
                if(@fullscreen,
                  do: "bg-primary text-primary-content shadow-md hover:bg-primary/90",
                  else: "bg-base-100 text-base-content/70 hover:bg-base-200 hover:text-base-content"
                )
              ]}
              title={if(@fullscreen, do: "Exit fullscreen (Esc)", else: "Enter fullscreen (F)")}
            >
              <.icon
                :if={!@fullscreen}
                name="hero-arrows-pointing-out"
                class="w-5 h-5 transition-transform duration-200 group-hover:scale-110"
              />
              <.icon
                :if={@fullscreen}
                name="hero-arrows-pointing-in"
                class="w-5 h-5 transition-transform duration-200 group-hover:scale-110"
              />
            </button>
          </div>
        </div>

        <%= if length(@projects) == 0 do %>
          <%!-- Empty state --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
            <div class="flex flex-col items-center text-center py-20 px-6">
              <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                <.icon name="hero-folder-plus" class="w-10 h-10 text-primary" />
              </div>
              <h2 class="text-xl font-semibold text-base-content">No projects yet</h2>
              <p class="text-base-content/60 max-w-md mt-2">
                Create your first project to start tracking events and errors from your applications.
              </p>
              <a
                href="/projects/new"
                class="inline-flex items-center gap-2 mt-6 px-5 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Create Project
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
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

          <%!-- Event Timeline Chart --%>
          <%= if length(@timeline_data) > 0 do %>
            <.event_timeline data={@timeline_data} time_range={@time_range} />
          <% end %>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Recent Events --%>
            <div class="lg:col-span-2">
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
                <div class="flex items-center justify-between px-5 py-4 border-b border-base-200">
                  <h2 class="text-base font-semibold text-base-content">Recent Events</h2>
                  <a
                    href="/events"
                    class="text-sm font-medium text-primary hover:text-primary/80 transition-colors duration-150"
                  >
                    View All
                  </a>
                </div>

                <%= if length(@recent_events) == 0 do %>
                  <div class="flex flex-col items-center text-center py-16 px-6">
                    <div class="w-14 h-14 rounded-xl bg-base-200 flex items-center justify-center mb-4">
                      <.icon name="hero-inbox" class="w-7 h-7 text-base-content/30" />
                    </div>
                    <p class="text-base-content/60 text-sm">No events captured yet</p>
                  </div>
                <% else %>
                  <div class="divide-y divide-base-200">
                    <%= for event <- @recent_events do %>
                      <a
                        href={"/events/#{event.id}"}
                        class="flex items-center gap-4 px-5 py-3.5 hover:bg-base-200/50 transition-colors duration-100"
                      >
                        <.level_indicator level={event.level} />
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2">
                            <p class="font-medium text-sm text-base-content truncate">{event.type}</p>
                            <%= if event.project do %>
                              <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-primary/10 text-primary text-[10px] font-semibold uppercase tracking-wide">
                                <.icon name="hero-folder" class="w-2.5 h-2.5" />
                                {event.project.name}
                              </span>
                            <% end %>
                          </div>
                          <p class="text-xs text-base-content/50 truncate mt-0.5">{event.message || "No message"}</p>
                        </div>
                        <span class="text-xs text-base-content/40 whitespace-nowrap font-medium">
                          {format_time_ago(event.timestamp)}
                        </span>
                        <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/30" />
                      </a>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Event Types --%>
            <div>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
                <div class="px-5 py-4 border-b border-base-200">
                  <h2 class="text-base font-semibold text-base-content">Top Event Types</h2>
                </div>

                <%= if length(@event_types) == 0 do %>
                  <div class="flex flex-col items-center text-center py-16 px-6">
                    <p class="text-base-content/60 text-sm">No data available</p>
                  </div>
                <% else %>
                  <div class="p-4 space-y-3">
                    <%= for {type, count} <- @event_types do %>
                      <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-base-200/50">
                        <span class="font-medium text-sm truncate text-base-content">{type}</span>
                        <span class="flex-shrink-0 px-2 py-0.5 rounded-md bg-base-300 text-xs font-semibold text-base-content/70">
                          {format_count(count)}
                        </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
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
    icon_bg_class = case assigns.color do
      "primary" -> "bg-primary/10"
      "error" -> "bg-error/10"
      "warning" -> "bg-warning/10"
      "info" -> "bg-info/10"
      _ -> "bg-base-200"
    end

    icon_text_class = case assigns.color do
      "primary" -> "text-primary"
      "error" -> "text-error"
      "warning" -> "text-warning"
      "info" -> "text-info"
      _ -> "text-base-content"
    end

    assigns = assign(assigns, :icon_bg_class, icon_bg_class)
    assigns = assign(assigns, :icon_text_class, icon_text_class)

    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100 p-5 shadow-sm hover:shadow-md transition-shadow duration-150">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm font-medium text-base-content/60">{@title}</p>
          <p class="text-3xl font-bold text-base-content mt-2 tracking-tight">{format_number(@value)}</p>
        </div>
        <div class={["p-3 rounded-xl", @icon_bg_class]}>
          <.icon name={@icon} class={["w-6 h-6", @icon_text_class]} />
        </div>
      </div>
    </div>
    """
  end

  attr :level, :string, required: true

  defp level_indicator(assigns) do
    color_class = case assigns.level do
      "fatal" -> "bg-error"
      "error" -> "bg-error"
      "warning" -> "bg-warning"
      "info" -> "bg-info"
      "debug" -> "bg-base-300"
      _ -> "bg-base-300"
    end

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <div class={["w-1.5 h-8 rounded-full flex-shrink-0", @color_class]} />
    """
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
