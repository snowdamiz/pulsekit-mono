defmodule PulsekitWeb.ProjectDetailLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Events
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    project = Projects.get_project_with_organization!(id)
    api_keys = Projects.list_api_keys(project.id)
    event_count = Events.count_events(project.id)

    socket =
      socket
      |> assign(:page_title, project.name)
      |> assign(:current_path, "/projects")
      |> LiveHelpers.assign_organization_context(params, session)
      |> assign(:project, project)
      |> assign(:api_keys, api_keys)
      |> assign(:event_count, event_count)
      |> assign(:show_key_modal, false)
      |> assign(:show_edit_modal, false)
      |> assign(:new_api_key, nil)
      |> assign(:key_form, to_form(%{"name" => "", "permissions" => "write"}))
      |> assign(:project_form, to_form(Projects.change_project(project)))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    assign(socket, :show_edit_modal, true)
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:show_edit_modal, false)
    |> assign(:show_key_modal, false)
  end

  @impl true
  def handle_event("show_key_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_key_modal, true)
     |> assign(:new_api_key, nil)
     |> assign(:key_form, to_form(%{"name" => "", "permissions" => "write"}))}
  end

  @impl true
  def handle_event("close_key_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_key_modal, false)
     |> assign(:new_api_key, nil)}
  end

  @impl true
  def handle_event("create_api_key", %{"name" => name, "permissions" => permissions}, socket) do
    case Projects.create_api_key(socket.assigns.project.id, %{name: name, permissions: permissions}) do
      {:ok, api_key} ->
        api_keys = Projects.list_api_keys(socket.assigns.project.id)

        {:noreply,
         socket
         |> assign(:api_keys, api_keys)
         |> assign(:new_api_key, api_key.raw_key)
         |> put_flash(:info, "API key created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create API key")}
    end
  end

  @impl true
  def handle_event("delete_api_key", %{"id" => id}, socket) do
    api_key = Projects.get_api_key!(id)

    case Projects.delete_api_key(api_key) do
      {:ok, _} ->
        api_keys = Projects.list_api_keys(socket.assigns.project.id)

        {:noreply,
         socket
         |> assign(:api_keys, api_keys)
         |> put_flash(:info, "API key deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete API key")}
    end
  end

  @impl true
  def handle_event("update_project", %{"project" => project_params}, socket) do
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:show_edit_modal, false)
         |> put_flash(:info, "Project updated successfully")
         |> push_patch(to: "/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, push_patch(socket, to: "/projects/#{socket.assigns.project.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={@current_path} current_organization={@current_organization} organizations={@organizations}>
      <div class="space-y-6">
        <%!-- Breadcrumb --%>
        <div class="flex items-center gap-2 text-sm">
          <a href="/projects" class="text-base-content/60 hover:text-base-content">Projects</a>
          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
          <span class="font-medium">{@project.name}</span>
        </div>

        <%!-- Header --%>
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold">{@project.name}</h1>
            <p class="text-base-content/60 mt-1 font-mono">{@project.slug}</p>
          </div>
          <div class="flex gap-2">
            <a href={"/projects/#{@project.id}/edit"} class="btn btn-outline">
              <.icon name="hero-pencil" class="w-4 h-4" />
              Edit
            </a>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- API Keys --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="card-title text-lg">
                    <.icon name="hero-key" class="w-5 h-5" />
                    API Keys
                  </h2>
                  <button phx-click="show_key_modal" class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="w-4 h-4" />
                    New Key
                  </button>
                </div>

                <%= if length(@api_keys) == 0 do %>
                  <div class="text-center py-8 text-base-content/60">
                    <.icon name="hero-key" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>No API keys yet</p>
                    <p class="text-sm mt-1">Create an API key to start sending events</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="table">
                      <thead>
                        <tr>
                          <th>Name</th>
                          <th>Key Prefix</th>
                          <th>Permissions</th>
                          <th>Last Used</th>
                          <th></th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for key <- @api_keys do %>
                          <tr>
                            <td class="font-medium">{key.name}</td>
                            <td class="font-mono text-sm">{key.key_prefix}...</td>
                            <td>
                              <span class="badge badge-ghost">{key.permissions}</span>
                            </td>
                            <td class="text-sm text-base-content/60">
                              {format_last_used(key.last_used_at)}
                            </td>
                            <td>
                              <button
                                phx-click="delete_api_key"
                                phx-value-id={key.id}
                                data-confirm="Are you sure you want to delete this API key?"
                                class="btn btn-ghost btn-sm text-error"
                              >
                                <.icon name="hero-trash" class="w-4 h-4" />
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Quick Start --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">
                  <.icon name="hero-rocket-launch" class="w-5 h-5" />
                  Quick Start
                </h2>

                <div class="space-y-4">
                  <p class="text-base-content/70">
                    Send your first event using curl:
                  </p>

                  <.curl_example endpoint={endpoint_url()} />
                </div>
              </div>
            </div>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Stats --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">Statistics</h2>
                <dl class="space-y-4">
                  <div>
                    <dt class="text-sm text-base-content/60">Total Events</dt>
                    <dd class="text-2xl font-bold mt-1">{format_number(@event_count)}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">API Keys</dt>
                    <dd class="text-2xl font-bold mt-1">{length(@api_keys)}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <%!-- Project Info --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">Project Info</h2>
                <dl class="space-y-4">
                  <div>
                    <dt class="text-sm text-base-content/60">Project ID</dt>
                    <dd class="font-mono text-sm mt-1 break-all">{@project.id}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Created</dt>
                    <dd class="mt-1">{format_datetime(@project.inserted_at)}</dd>
                  </div>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create API Key Modal --%>
      <%= if @show_key_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_key_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <%= if @new_api_key do %>
              <h3 class="font-bold text-lg mb-4">API Key Created</h3>
              <div class="alert alert-warning mb-4">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                <span>Make sure to copy your API key now. You won't be able to see it again!</span>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Your API Key</span>
                </label>
                <div class="join w-full">
                  <input
                    type="text"
                    value={@new_api_key}
                    readonly
                    class="input input-bordered join-item flex-1 font-mono text-sm"
                    id="api-key-input"
                  />
                  <button
                    type="button"
                    class="btn join-item"
                    onclick="navigator.clipboard.writeText(document.getElementById('api-key-input').value)"
                  >
                    <.icon name="hero-clipboard" class="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_key_modal" class="btn btn-primary">
                  Done
                </button>
              </div>
            <% else %>
              <h3 class="font-bold text-lg mb-4">Create API Key</h3>

              <.form for={@key_form} phx-submit="create_api_key" class="space-y-4" id="api-key-form">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Key Name</span>
                  </label>
                  <input
                    type="text"
                    name="name"
                    placeholder="Production Server"
                    class="input input-bordered w-full"
                    required
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Permissions</span>
                  </label>
                  <select name="permissions" class="select select-bordered w-full">
                    <option value="write">Write (can send events)</option>
                    <option value="read">Read (can read events)</option>
                    <option value="admin">Admin (full access)</option>
                  </select>
                </div>

                <div class="modal-action">
                  <button type="button" phx-click="close_key_modal" class="btn btn-ghost">
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary">
                    Create Key
                  </button>
                </div>
              </.form>
            <% end %>
          </div>
          <div class="modal-backdrop bg-base-300/50" phx-click="close_key_modal"></div>
        </div>
      <% end %>

      <%!-- Edit Project Modal --%>
      <%= if @show_edit_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_edit_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <h3 class="font-bold text-lg mb-4">Edit Project</h3>

            <.form for={@project_form} phx-submit="update_project" class="space-y-4" id="edit-project-form">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Project Name</span>
                </label>
                <.input
                  field={@project_form[:name]}
                  type="text"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Slug</span>
                </label>
                <.input
                  field={@project_form[:slug]}
                  type="text"
                  class="input input-bordered w-full font-mono"
                  required
                />
                <label class="label">
                  <span class="label-text-alt text-base-content/60">
                    URL-friendly identifier (lowercase, alphanumeric, dashes)
                  </span>
                </label>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_edit_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  Save Changes
                </button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop bg-base-300/50" phx-click="close_edit_modal"></div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_last_used(nil), do: "Never"
  defp format_last_used(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %H:%M UTC")
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  defp endpoint_url do
    PulsekitWeb.Endpoint.url()
  end

  attr :endpoint, :string, required: true

  defp curl_example(assigns) do
    curl_cmd = """
    curl -X POST #{assigns.endpoint}/api/v1/events \\
      -H "Content-Type: application/json" \\
      -H "X-PulseKit-Key: YOUR_API_KEY" \\
      -d '{"type": "test.event", "level": "info", "message": "Hello!"}'
    """

    assigns = assign(assigns, :curl_cmd, curl_cmd)

    ~H"""
    <div class="bg-base-200 rounded-lg p-4 overflow-x-auto">
      <pre class="text-sm font-mono whitespace-pre-wrap">{@curl_cmd}</pre>
    </div>
    """
  end
end
