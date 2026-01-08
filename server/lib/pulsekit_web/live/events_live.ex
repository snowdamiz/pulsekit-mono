defmodule PulsekitWeb.EventsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Events
  alias Pulsekit.Events.Event
  alias PulsekitWeb.LiveHelpers
  alias PulsekitWeb.CoreComponents

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Events")
      |> assign(:current_path, "/events")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> assign(:level_filter, nil)
      |> assign(:type_filter, nil)
      |> assign(:environment_filter, nil)
      |> assign(:project_filter, nil)
      |> assign(:time_range, "24h")
      |> assign(:search, "")
      |> assign(:events_empty?, true)
      |> assign(:environments, [])
      |> assign(:live_tail, false)
      |> assign(:paused, false)
      |> assign(:new_events_count, 0)
      |> stream(:events, [])
      |> load_environments()
      |> load_events()

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

  defp load_environments(socket) do
    case socket.assigns.current_organization do
      nil -> assign(socket, :environments, [])
      org -> assign(socket, :environments, Events.get_environments_for_organization(org.id))
    end
  end

  @impl true
  def handle_event("filter_project", %{"project" => project_id}, socket) do
    project_id = if project_id == "", do: nil, else: project_id

    socket =
      socket
      |> assign(:project_filter, project_id)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_level", %{"level" => level}, socket) do
    level = if level == "", do: nil, else: level

    socket =
      socket
      |> assign(:level_filter, level)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    type = if type == "", do: nil, else: type

    socket =
      socket
      |> assign(:type_filter, type)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_environment", %{"environment" => env}, socket) do
    env = if env == "", do: nil, else: env

    socket =
      socket
      |> assign(:environment_filter, env)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("time_range_changed", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:time_range, range)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign(:search, search)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:level_filter, nil)
      |> assign(:type_filter, nil)
      |> assign(:environment_filter, nil)
      |> assign(:project_filter, nil)
      |> assign(:time_range, "24h")
      |> assign(:search, "")
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_live_tail", _params, socket) do
    live_tail = !socket.assigns.live_tail

    socket =
      socket
      |> assign(:live_tail, live_tail)
      |> assign(:paused, false)
      |> assign(:new_events_count, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("pause_live_tail", _params, socket) do
    {:noreply, assign(socket, :paused, true)}
  end

  @impl true
  def handle_event("resume_live_tail", _params, socket) do
    {:noreply,
     socket
     |> assign(:paused, false)
     |> assign(:new_events_count, 0)
     |> load_events()}
  end

  @impl true
  def handle_info({:new_event, event}, socket) do
    if matches_filters?(event, socket.assigns) do
      cond do
        socket.assigns.live_tail and not socket.assigns.paused ->
          {:noreply,
           socket
           |> assign(:events_empty?, false)
           |> stream_insert(:events, event, at: 0)}

        socket.assigns.live_tail and socket.assigns.paused ->
          {:noreply, assign(socket, :new_events_count, socket.assigns.new_events_count + 1)}

        true ->
          {:noreply,
           socket
           |> assign(:events_empty?, false)
           |> stream_insert(:events, event, at: 0)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:events_batch, _count}, socket) do
    {:noreply, load_events(socket)}
  end

  defp load_events(socket) do
    case socket.assigns.current_organization do
      nil ->
        socket
        |> assign(:events_empty?, true)
        |> stream(:events, [], reset: true)

      org ->
        since = CoreComponents.time_range_to_since(socket.assigns.time_range)

        opts = [
          limit: 100,
          level: socket.assigns.level_filter,
          type: socket.assigns.type_filter,
          search: socket.assigns.search,
          since: since,
          environment: socket.assigns.environment_filter,
          project_id: socket.assigns.project_filter
        ]

        events = Events.list_events_for_organization(org.id, opts)

        socket
        |> assign(:events_empty?, events == [])
        |> stream(:events, events, reset: true)
    end
  end

  defp matches_filters?(event, assigns) do
    level_match = is_nil(assigns.level_filter) or event.level == assigns.level_filter
    type_match = is_nil(assigns.type_filter) or event.type == assigns.type_filter
    env_match = is_nil(assigns.environment_filter) or event.environment == assigns.environment_filter
    project_match = is_nil(assigns.project_filter) or event.project_id == assigns.project_filter
    search_match = assigns.search == "" or
      String.contains?(String.downcase(event.message || ""), String.downcase(assigns.search)) or
      String.contains?(String.downcase(event.type), String.downcase(assigns.search))

    level_match and type_match and env_match and project_match and search_match
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-start justify-between flex-wrap gap-4">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Events</h1>
            <p class="text-base-content/60 mt-1">
              <%= if @current_organization do %>
                View and filter all events across <span class="font-medium text-base-content">{@current_organization.name}</span>
              <% else %>
                View and filter all captured events
              <% end %>
            </p>
          </div>

          <div class="flex items-center gap-3 flex-wrap">
            <%!-- Live Tail Toggle --%>
            <%= if @current_organization do %>
              <button
                phx-click="toggle_live_tail"
                class={[
                  "flex items-center gap-2 px-4 py-2 rounded-lg border text-sm font-medium transition-all duration-150",
                  if(@live_tail,
                    do: "border-success bg-success/10 text-success",
                    else: "border-base-300 bg-base-100 text-base-content/70 hover:bg-base-200"
                  )
                ]}
              >
                <%= if @live_tail do %>
                  <span class="relative flex h-2 w-2">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                  </span>
                  Live
                <% else %>
                  <.icon name="hero-signal" class="w-4 h-4" />
                  Live Tail
                <% end %>
              </button>
            <% end %>

            <%!-- Time Range Selector --%>
            <%= if @current_organization && !@live_tail do %>
              <.time_range_selector selected={@time_range} on_change="time_range_changed" />
            <% end %>
          </div>
        </div>

        <%= if @current_organization do %>
          <%!-- Live Tail Paused Banner --%>
          <%= if @live_tail and @paused do %>
            <div class="rounded-xl border border-warning/30 bg-warning/10 p-4 shadow-sm">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <.icon name="hero-pause-circle" class="w-5 h-5 text-warning" />
                  <div>
                    <p class="font-medium text-warning">Live tail paused</p>
                    <p class="text-sm text-warning/70">
                      <%= if @new_events_count > 0 do %>
                        {@new_events_count} new event{if @new_events_count > 1, do: "s", else: ""} arrived
                      <% else %>
                        Scroll up to see new events
                      <% end %>
                    </p>
                  </div>
                </div>
                <button
                  phx-click="resume_live_tail"
                  class="px-4 py-2 rounded-lg bg-warning text-warning-content text-sm font-medium hover:brightness-110 transition-all duration-150"
                >
                  Resume
                </button>
              </div>
            </div>
          <% end %>

          <%!-- Filters --%>
          <div class="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
            <div class="flex flex-wrap items-center gap-3">
              <%!-- Search --%>
              <div class="flex-1 min-w-[240px]">
                <form phx-change="search" phx-submit="search">
                  <div class="relative">
                    <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40" />
                    <input
                      type="text"
                      name="search"
                      value={@search}
                      placeholder="Search events by type or message..."
                      class="w-full pl-10 pr-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                      phx-debounce="300"
                    />
                  </div>
                </form>
              </div>

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

              <%!-- Level Filter --%>
              <select
                name="level"
                class="px-4 py-2.5 rounded-lg border border-base-300 bg-base-100 text-sm font-medium focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                phx-change="filter_level"
              >
                <option value="">All Levels</option>
                <%= for level <- Event.levels() do %>
                  <option value={level} selected={@level_filter == level}>
                    {String.capitalize(level)}
                  </option>
                <% end %>
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

              <%!-- Active Filters Indicator / Clear --%>
              <%= if @level_filter || @type_filter || @environment_filter || @project_filter || @search != "" do %>
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

          <%!-- Events Table --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="border-b border-base-200 bg-base-200/30">
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-24">Level</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Type</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-32">Project</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Message</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-28">Environment</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-40">Time</th>
                    <th class="w-10"></th>
                  </tr>
                </thead>
                <tbody id="events" phx-update="stream" class="divide-y divide-base-200">
                  <tr id="events-empty" class="hidden only:table-row">
                    <td colspan="7" class="text-center py-16">
                      <div class="flex flex-col items-center">
                        <div class="w-14 h-14 rounded-xl bg-base-200 flex items-center justify-center mb-4">
                          <.icon name="hero-inbox" class="w-7 h-7 text-base-content/30" />
                        </div>
                        <p class="text-base-content/60 text-sm">No events found</p>
                        <p class="text-base-content/40 text-xs mt-1">Try adjusting your filters</p>
                      </div>
                    </td>
                  </tr>
                  <tr
                    :for={{id, event} <- @streams.events}
                    id={id}
                    class="hover:bg-base-200/50 cursor-pointer transition-colors duration-100"
                    onclick={"window.location.href='/events/#{event.id}'"}
                  >
                    <td class="px-4 py-3.5">
                      <.level_badge level={event.level} />
                    </td>
                    <td class="px-4 py-3.5">
                      <span class="font-medium text-sm text-base-content">{event.type}</span>
                    </td>
                    <td class="px-4 py-3.5">
                      <%= if event.project do %>
                        <span class="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-primary/10 text-xs font-semibold text-primary">
                          <.icon name="hero-folder" class="w-3 h-3" />
                          {event.project.name}
                        </span>
                      <% else %>
                        <span class="text-base-content/30 text-sm">-</span>
                      <% end %>
                    </td>
                    <td class="px-4 py-3.5 max-w-md">
                      <span class="text-sm text-base-content/70 truncate block">{event.message || "-"}</span>
                    </td>
                    <td class="px-4 py-3.5">
                      <%= if event.environment do %>
                        <span class="inline-flex px-2 py-0.5 rounded-md bg-base-200 text-xs font-medium text-base-content/70">
                          {event.environment}
                        </span>
                      <% else %>
                        <span class="text-base-content/30 text-sm">-</span>
                      <% end %>
                    </td>
                    <td class="px-4 py-3.5">
                      <span class="text-sm text-base-content/50">{format_datetime(event.timestamp)}</span>
                    </td>
                    <td class="px-4 py-3.5">
                      <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/30" />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
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
                Select or create a workspace to start viewing events.
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
    <span class={["inline-flex px-2 py-1 rounded-md text-xs font-semibold uppercase tracking-wide", @bg_class, @text_class]}>
      {@level}
    </span>
    """
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M:%S")
  end
end
