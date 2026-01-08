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
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Events</h1>
            <p class="text-base-content/60 mt-1">View and filter all captured events</p>
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

        <%= if @selected_project do %>
          <%!-- Filters --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body py-4">
              <div class="flex flex-wrap items-center gap-4">
                <%!-- Search --%>
                <div class="flex-1 min-w-[200px]">
                  <form phx-change="search" phx-submit="search">
                    <div class="relative">
                      <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/50" />
                      <input
                        type="text"
                        name="search"
                        value={@search}
                        placeholder="Search events..."
                        class="input input-bordered w-full pl-10"
                        phx-debounce="300"
                      />
                    </div>
                  </form>
                </div>

                <%!-- Level Filter --%>
                <select
                  name="level"
                  class="select select-bordered"
                  phx-change="filter_level"
                >
                  <option value="">All Levels</option>
                  <%= for level <- Event.levels() do %>
                    <option value={level} selected={@level_filter == level}>
                      {String.capitalize(level)}
                    </option>
                  <% end %>
                </select>

                <%!-- Clear Filters --%>
                <%= if @level_filter || @type_filter || @search != "" do %>
                  <button phx-click="clear_filters" class="btn btn-ghost btn-sm">
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                    Clear
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Events List --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th class="w-24">Level</th>
                    <th>Type</th>
                    <th>Message</th>
                    <th class="w-32">Environment</th>
                    <th class="w-40">Time</th>
                  </tr>
                </thead>
                <tbody id="events" phx-update="stream">
                  <tr class="hidden only:table-row">
                    <td colspan="5" class="text-center py-12 text-base-content/60">
                      <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p>No events found</p>
                    </td>
                  </tr>
                  <tr
                    :for={{id, event} <- @streams.events}
                    id={id}
                    class="hover:bg-base-200 cursor-pointer"
                    onclick={"window.location.href='/events/#{event.id}'"}
                  >
                    <td>
                      <.level_badge level={event.level} />
                    </td>
                    <td class="font-medium">{event.type}</td>
                    <td class="max-w-md truncate text-base-content/70">
                      {event.message || "-"}
                    </td>
                    <td>
                      <%= if event.environment do %>
                        <span class="badge badge-ghost badge-sm">{event.environment}</span>
                      <% else %>
                        <span class="text-base-content/40">-</span>
                      <% end %>
                    </td>
                    <td class="text-sm text-base-content/60">
                      {format_datetime(event.timestamp)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        <% else %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body items-center text-center py-16">
              <.icon name="hero-folder-plus" class="w-16 h-16 text-base-content/30" />
              <h2 class="card-title mt-4">No projects yet</h2>
              <p class="text-base-content/60">Create a project to start viewing events.</p>
              <div class="card-actions mt-4">
                <a href="/projects/new" class="btn btn-primary">Create Project</a>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
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

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M:%S")
  end
end
