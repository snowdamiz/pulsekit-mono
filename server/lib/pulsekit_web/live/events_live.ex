defmodule PulsekitWeb.EventsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Events
  alias Pulsekit.Events.Event
  alias PulsekitWeb.LiveHelpers

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
      |> assign(:search, "")
      |> assign(:events_empty?, true)
      |> stream(:events, [])
      |> load_events()

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

    if socket.assigns.selected_project do
      Phoenix.PubSub.unsubscribe(Pulsekit.PubSub, "events:#{socket.assigns.selected_project.id}")
    end

    Events.subscribe(project.id)

    socket =
      socket
      |> assign(:selected_project, project)
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
      |> assign(:search, "")
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_event, event}, socket) do
    if matches_filters?(event, socket.assigns) do
      {:noreply,
       socket
       |> assign(:events_empty?, false)
       |> stream_insert(:events, event, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:events_batch, _count}, socket) do
    {:noreply, load_events(socket)}
  end

  defp load_events(socket) do
    case socket.assigns.selected_project do
      nil ->
        socket
        |> assign(:events_empty?, true)
        |> stream(:events, [], reset: true)

      project ->
        opts = [
          limit: 100,
          level: socket.assigns.level_filter,
          type: socket.assigns.type_filter,
          search: socket.assigns.search
        ]

        events = Events.list_events(project.id, opts)

        socket
        |> assign(:events_empty?, events == [])
        |> stream(:events, events, reset: true)
    end
  end

  defp matches_filters?(event, assigns) do
    level_match = is_nil(assigns.level_filter) or event.level == assigns.level_filter
    type_match = is_nil(assigns.type_filter) or event.type == assigns.type_filter
    search_match = assigns.search == "" or
      String.contains?(String.downcase(event.message || ""), String.downcase(assigns.search)) or
      String.contains?(String.downcase(event.type), String.downcase(assigns.search))

    level_match and type_match and search_match
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Events</h1>
            <p class="text-base-content/60 mt-1">View and filter all captured events</p>
          </div>

          <%= if length(@projects) > 0 do %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                class="flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 hover:bg-base-200 transition-colors duration-150 cursor-pointer"
              >
                <.icon name="hero-folder" class="w-4 h-4 text-primary" />
                <span class="font-medium text-sm">{if @selected_project, do: @selected_project.name, else: "Select Project"}</span>
                <.icon name="hero-chevron-down" class="w-4 h-4 text-base-content/50" />
              </div>
              <ul tabindex="0" class="dropdown-content z-[1] mt-2 p-1.5 w-56 bg-base-100 rounded-lg border border-base-300 shadow-lg">
                <%= for project <- @projects do %>
                  <li>
                    <button
                      phx-click="select_project"
                      phx-value-id={project.id}
                      class={[
                        "flex items-center gap-2 w-full px-3 py-2 rounded-md text-sm text-left transition-colors duration-100",
                        if(@selected_project && @selected_project.id == project.id,
                          do: "bg-primary/10 text-primary font-medium",
                          else: "text-base-content hover:bg-base-200"
                        )
                      ]}
                    >
                      <.icon name="hero-folder" class="w-4 h-4" />
                      <span class="truncate">{project.name}</span>
                      <.icon :if={@selected_project && @selected_project.id == project.id} name="hero-check" class="w-4 h-4 ml-auto" />
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>

        <%= if @selected_project do %>
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

              <%!-- Active Filters Indicator / Clear --%>
              <%= if @level_filter || @type_filter || @search != "" do %>
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
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Message</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-28">Environment</th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60 w-40">Time</th>
                    <th class="w-10"></th>
                  </tr>
                </thead>
                <tbody id="events" phx-update="stream" class="divide-y divide-base-200">
                  <tr class="hidden only:table-row">
                    <td colspan="6" class="text-center py-16">
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
          <%!-- No Projects State --%>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
            <div class="flex flex-col items-center text-center py-20 px-6">
              <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                <.icon name="hero-folder-plus" class="w-10 h-10 text-primary" />
              </div>
              <h2 class="text-xl font-semibold text-base-content">No projects yet</h2>
              <p class="text-base-content/60 max-w-md mt-2">
                Create a project to start viewing events.
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
