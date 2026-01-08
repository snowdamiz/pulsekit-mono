defmodule PulsekitWeb.EventDetailLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Events
  alias Pulsekit.Projects
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    event = Events.get_event!(id)
    project = Projects.get_project_with_organization!(event.project_id)

    socket =
      socket
      |> assign(:page_title, "Event Details")
      |> assign(:current_path, "/events")
      |> LiveHelpers.assign_organization_context(params, session)
      |> assign(:event, event)
      |> assign(:project, project)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Breadcrumb --%>
        <div class="flex items-center gap-2 text-sm">
          <a href="/events" class="text-base-content/60 hover:text-base-content">Events</a>
          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
          <span class="font-medium">{@event.type}</span>
        </div>

        <%!-- Header --%>
        <div class="flex items-start justify-between">
          <div>
            <div class="flex items-center gap-3">
              <.level_badge level={@event.level} />
              <h1 class="text-2xl font-bold">{@event.type}</h1>
            </div>
            <p class="text-base-content/60 mt-2">{@event.message || "No message"}</p>
          </div>
          <a href="/events" class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back
          </a>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Stacktrace --%>
            <%= if @event.stacktrace do %>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4">
                    <.icon name="hero-code-bracket" class="w-5 h-5" />
                    Stacktrace
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
                    <pre class="text-sm font-mono whitespace-pre-wrap">{format_stacktrace(@event.stacktrace)}</pre>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Metadata --%>
            <%= if @event.metadata && map_size(@event.metadata) > 0 do %>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4">
                    <.icon name="hero-document-text" class="w-5 h-5" />
                    Metadata
                  </h2>
                  <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
                    <pre class="text-sm font-mono" phx-no-curly-interpolation><%= Jason.encode!(@event.metadata, pretty: true) %></pre>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Tags --%>
            <%= if @event.tags && map_size(@event.tags) > 0 do %>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4">
                    <.icon name="hero-tag" class="w-5 h-5" />
                    Tags
                  </h2>
                  <div class="flex flex-wrap gap-2">
                    <%= for {key, value} <- @event.tags do %>
                      <span class="badge badge-lg gap-2">
                        <span class="font-medium">{key}:</span>
                        <span>{value}</span>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Event Info --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">Event Info</h2>
                <dl class="space-y-4">
                  <div>
                    <dt class="text-sm text-base-content/60">Event ID</dt>
                    <dd class="font-mono text-sm mt-1 break-all">{@event.id}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Project</dt>
                    <dd class="mt-1">
                      <a href={"/projects/#{@project.id}"} class="link link-primary">
                        {@project.name}
                      </a>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Timestamp</dt>
                    <dd class="mt-1">{format_datetime(@event.timestamp)}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Fingerprint</dt>
                    <dd class="font-mono text-sm mt-1">{@event.fingerprint || "-"}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <%!-- Context --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">Context</h2>
                <dl class="space-y-4">
                  <div>
                    <dt class="text-sm text-base-content/60">Environment</dt>
                    <dd class="mt-1">
                      <%= if @event.environment do %>
                        <span class="badge">{@event.environment}</span>
                      <% else %>
                        <span class="text-base-content/40">Not set</span>
                      <% end %>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Release</dt>
                    <dd class="mt-1">
                      <%= if @event.release do %>
                        <span class="font-mono text-sm">{@event.release}</span>
                      <% else %>
                        <span class="text-base-content/40">Not set</span>
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
    <span class={"px-3 py-1.5 rounded-lg text-sm font-medium uppercase #{@color}"}>
      {@level}
    </span>
    """
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
