defmodule PulsekitWeb.EventDetailLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Events
  alias Pulsekit.Projects
  alias Pulsekit.Issues
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    event = Events.get_event!(id)
    project = Projects.get_project_with_organization!(event.project_id)

    # Get similar events (same fingerprint)
    similar_events = Issues.get_issue_events(project.id, event.fingerprint, limit: 10)
    # Exclude current event
    similar_events = Enum.reject(similar_events, &(&1.id == event.id))

    # Get issue info
    issue_info = Issues.get_issue(project.id, event.fingerprint)

    socket =
      socket
      |> assign(:page_title, "Event Details")
      |> assign(:current_path, "/events")
      |> LiveHelpers.assign_organization_context(params, session)
      |> assign(:event, event)
      |> assign(:project, project)
      |> assign(:similar_events, similar_events)
      |> assign(:issue_info, issue_info)
      |> assign(:show_similar, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_similar", _params, socket) do
    {:noreply, assign(socket, :show_similar, !socket.assigns.show_similar)}
  end

  @impl true
  def handle_event("resolve_issue", _params, socket) do
    case Issues.resolve_issue(socket.assigns.project.id, socket.assigns.event.fingerprint) do
      {:ok, _} ->
        issue_info = Issues.get_issue(socket.assigns.project.id, socket.assigns.event.fingerprint)
        {:noreply,
         socket
         |> assign(:issue_info, issue_info)
         |> put_flash(:info, "Issue resolved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve issue")}
    end
  end

  @impl true
  def handle_event("ignore_issue", _params, socket) do
    case Issues.ignore_issue(socket.assigns.project.id, socket.assigns.event.fingerprint) do
      {:ok, _} ->
        issue_info = Issues.get_issue(socket.assigns.project.id, socket.assigns.event.fingerprint)
        {:noreply,
         socket
         |> assign(:issue_info, issue_info)
         |> put_flash(:info, "Issue ignored")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to ignore issue")}
    end
  end

  @impl true
  def handle_event("reopen_issue", _params, socket) do
    case Issues.reopen_issue(socket.assigns.project.id, socket.assigns.event.fingerprint) do
      {:ok, _} ->
        issue_info = Issues.get_issue(socket.assigns.project.id, socket.assigns.event.fingerprint)
        {:noreply,
         socket
         |> assign(:issue_info, issue_info)
         |> put_flash(:info, "Issue reopened")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reopen issue")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Breadcrumb --%>
        <nav class="flex items-center gap-2 text-sm">
          <a href="/events" class="text-base-content/50 hover:text-primary transition-colors duration-150">Events</a>
          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/30" />
          <span class="font-medium text-base-content truncate max-w-xs">{@event.type}</span>
        </nav>

        <%!-- Header --%>
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <div class="flex items-center gap-3 flex-wrap">
              <.level_badge level={@event.level} />
              <%= if @issue_info do %>
                <.status_badge status={@issue_info.status} />
              <% end %>
              <h1 class="text-2xl font-bold text-base-content tracking-tight truncate">{@event.type}</h1>
            </div>
            <p class="text-base-content/60 mt-2 line-clamp-2">{@event.message || "No message"}</p>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <%!-- Issue Actions --%>
            <%= if @issue_info do %>
              <%= cond do %>
                <% @issue_info.status == "unresolved" -> %>
                  <button
                    phx-click="resolve_issue"
                    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-success/30 bg-success/10 text-success text-sm font-medium hover:bg-success/20 transition-colors duration-150"
                  >
                    <.icon name="hero-check-circle" class="w-4 h-4" />
                    Resolve
                  </button>
                  <button
                    phx-click="ignore_issue"
                    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-warning/30 bg-warning/10 text-warning text-sm font-medium hover:bg-warning/20 transition-colors duration-150"
                  >
                    <.icon name="hero-eye-slash" class="w-4 h-4" />
                    Ignore
                  </button>
                <% @issue_info.status in ["resolved", "ignored"] -> %>
                  <button
                    phx-click="reopen_issue"
                    class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-base-300 bg-base-100 text-base-content text-sm font-medium hover:bg-base-200 transition-colors duration-150"
                  >
                    <.icon name="hero-arrow-path" class="w-4 h-4" />
                    Reopen
                  </button>
                <% true -> %>
              <% end %>
            <% end %>
            <a
              href="/events"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" />
              Back
            </a>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Stacktrace --%>
            <%= if @event.stacktrace do %>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
                <div class="flex items-center gap-2 px-5 py-4 border-b border-base-200 bg-base-200/30">
                  <div class="p-1.5 rounded-lg bg-error/10">
                    <.icon name="hero-code-bracket" class="w-4 h-4 text-error" />
                  </div>
                  <h2 class="font-semibold text-base-content">Stacktrace</h2>
                </div>
                <div class="p-4">
                  <div class="rounded-lg bg-base-200/50 border border-base-300 p-4 overflow-x-auto">
                    <pre class="text-sm font-mono text-base-content/80 whitespace-pre-wrap leading-relaxed">{format_stacktrace(@event.stacktrace)}</pre>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Metadata --%>
            <%= if @event.metadata && map_size(@event.metadata) > 0 do %>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
                <div class="flex items-center gap-2 px-5 py-4 border-b border-base-200 bg-base-200/30">
                  <div class="p-1.5 rounded-lg bg-info/10">
                    <.icon name="hero-document-text" class="w-4 h-4 text-info" />
                  </div>
                  <h2 class="font-semibold text-base-content">Metadata</h2>
                </div>
                <div class="p-4">
                  <div class="rounded-lg bg-base-200/50 border border-base-300 p-4 overflow-x-auto">
                    <pre class="text-sm font-mono text-base-content/80 leading-relaxed" phx-no-curly-interpolation><%= Jason.encode!(@event.metadata, pretty: true) %></pre>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Tags --%>
            <%= if @event.tags && map_size(@event.tags) > 0 do %>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
                <div class="flex items-center gap-2 px-5 py-4 border-b border-base-200 bg-base-200/30">
                  <div class="p-1.5 rounded-lg bg-primary/10">
                    <.icon name="hero-tag" class="w-4 h-4 text-primary" />
                  </div>
                  <h2 class="font-semibold text-base-content">Tags</h2>
                </div>
                <div class="p-4">
                  <div class="flex flex-wrap gap-2">
                    <%= for {key, value} <- @event.tags do %>
                      <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-base-200 border border-base-300 text-sm">
                        <span class="font-medium text-base-content/70">{key}:</span>
                        <span class="text-base-content">{value}</span>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Similar Events Panel --%>
            <%= if @issue_info && @issue_info.count > 1 do %>
              <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
                <button
                  phx-click="toggle_similar"
                  class="flex items-center justify-between w-full px-5 py-4 border-b border-base-200 bg-base-200/30 hover:bg-base-200/50 transition-colors duration-150"
                >
                  <div class="flex items-center gap-2">
                    <div class="p-1.5 rounded-lg bg-warning/10">
                      <.icon name="hero-document-duplicate" class="w-4 h-4 text-warning" />
                    </div>
                    <h2 class="font-semibold text-base-content">Similar Events</h2>
                    <span class="px-2 py-0.5 rounded-md bg-warning/15 text-warning text-xs font-semibold">
                      {@issue_info.count - 1} more
                    </span>
                  </div>
                  <.icon name={if @show_similar, do: "hero-chevron-up", else: "hero-chevron-down"} class="w-5 h-5 text-base-content/50" />
                </button>

                <%= if @show_similar do %>
                  <div class="divide-y divide-base-200">
                    <%= if length(@similar_events) == 0 do %>
                      <div class="p-4 text-center text-sm text-base-content/50">
                        No other events to display
                      </div>
                    <% else %>
                      <%= for event <- @similar_events do %>
                        <a
                          href={"/events/#{event.id}"}
                          class="flex items-center gap-4 px-5 py-3.5 hover:bg-base-200/50 transition-colors duration-100"
                        >
                          <div class={["w-1.5 h-8 rounded-full flex-shrink-0", level_color(event.level)]} />
                          <div class="flex-1 min-w-0">
                            <p class="text-sm text-base-content/70 truncate">{event.message || "No message"}</p>
                            <p class="text-xs text-base-content/40 mt-0.5">
                              {if event.environment, do: "#{event.environment} · ", else: ""}{format_datetime(event.timestamp)}
                            </p>
                          </div>
                          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/30" />
                        </a>
                      <% end %>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Event Info --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="px-5 py-4 border-b border-base-200 bg-base-200/30">
                <h2 class="font-semibold text-base-content">Event Info</h2>
              </div>
              <div class="p-5">
                <dl class="space-y-4">
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Event ID</dt>
                    <dd class="mt-1.5 font-mono text-sm text-base-content break-all bg-base-200/50 px-2 py-1.5 rounded-md">{@event.id}</dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Project</dt>
                    <dd class="mt-1.5">
                      <a
                        href={"/projects/#{@project.id}"}
                        class="inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:text-primary/80 transition-colors duration-150"
                      >
                        <.icon name="hero-folder" class="w-4 h-4" />
                        {@project.name}
                      </a>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Timestamp</dt>
                    <dd class="mt-1.5 text-sm text-base-content">{format_datetime(@event.timestamp)}</dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Fingerprint</dt>
                    <dd class="mt-1.5 font-mono text-sm text-base-content/70">{@event.fingerprint || "-"}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <%!-- Context --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="px-5 py-4 border-b border-base-200 bg-base-200/30">
                <h2 class="font-semibold text-base-content">Context</h2>
              </div>
              <div class="p-5">
                <dl class="space-y-4">
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Environment</dt>
                    <dd class="mt-1.5">
                      <%= if @event.environment do %>
                        <span class="inline-flex px-2.5 py-1 rounded-md bg-primary/10 text-primary text-sm font-medium">
                          {@event.environment}
                        </span>
                      <% else %>
                        <span class="text-sm text-base-content/40">Not set</span>
                      <% end %>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Release</dt>
                    <dd class="mt-1.5">
                      <%= if @event.release do %>
                        <span class="font-mono text-sm text-base-content">{@event.release}</span>
                      <% else %>
                        <span class="text-sm text-base-content/40">Not set</span>
                      <% end %>
                    </dd>
                  </div>
                </dl>
              </div>
            </div>
          </div>
        </div>
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
    <span class={["inline-flex px-3 py-1.5 rounded-lg text-sm font-semibold uppercase tracking-wide", @bg_class, @text_class]}>
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
    <span class={["inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium", @bg_class, @text_class]}>
      <.icon name={@status_icon} class="w-4 h-4" />
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

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %H:%M:%S UTC")
  end

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Enum.map(&format_stack_frame/1)
    |> Enum.join("\n")
  end

  defp format_stacktrace(stacktrace) when is_binary(stacktrace), do: stacktrace
  defp format_stacktrace(stacktrace) when is_map(stacktrace), do: Jason.encode!(stacktrace, pretty: true)
  defp format_stacktrace(_), do: "No stacktrace available"

  defp format_stack_frame(%{"file" => file, "line" => line, "function" => function}) do
    "  at #{function} (#{file}:#{line})"
  end

  defp format_stack_frame(%{"file" => file, "line" => line}) do
    "  at #{file}:#{line}"
  end

  defp format_stack_frame(frame) when is_binary(frame), do: "  #{frame}"
  defp format_stack_frame(frame), do: "  #{inspect(frame)}"
end
