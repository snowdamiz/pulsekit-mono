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
        <nav class="flex items-center gap-2 text-sm">
          <a href="/projects" class="text-base-content/50 hover:text-primary transition-colors duration-150">Projects</a>
          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/30" />
          <span class="font-medium text-base-content">{@project.name}</span>
        </nav>

        <%!-- Header --%>
        <div class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">{@project.name}</h1>
            <p class="text-base-content/50 mt-1 font-mono text-sm">{@project.slug}</p>
          </div>
          <a
            href={"/projects/#{@project.id}/edit"}
            class="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-base-300 bg-base-100 text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
          >
            <.icon name="hero-pencil" class="w-4 h-4" />
            Edit
          </a>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- API Keys --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="flex items-center justify-between px-5 py-4 border-b border-base-200 bg-base-200/30">
                <div class="flex items-center gap-2">
                  <div class="p-1.5 rounded-lg bg-primary/10">
                    <.icon name="hero-key" class="w-4 h-4 text-primary" />
                  </div>
                  <h2 class="font-semibold text-base-content">API Keys</h2>
                </div>
                <button
                  phx-click="show_key_modal"
                  class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150"
                >
                  <.icon name="hero-plus" class="w-4 h-4" />
                  New Key
                </button>
              </div>

              <%= if length(@api_keys) == 0 do %>
                <div class="flex flex-col items-center text-center py-12 px-6">
                  <div class="w-14 h-14 rounded-xl bg-base-200 flex items-center justify-center mb-4">
                    <.icon name="hero-key" class="w-7 h-7 text-base-content/30" />
                  </div>
                  <p class="text-base-content/60 text-sm">No API keys yet</p>
                  <p class="text-base-content/40 text-xs mt-1">Create an API key to start sending events</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="border-b border-base-200">
                        <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Name</th>
                        <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Key Prefix</th>
                        <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Permissions</th>
                        <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/60">Last Used</th>
                        <th class="w-10"></th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-base-200">
                      <%= for key <- @api_keys do %>
                        <tr class="hover:bg-base-200/50 transition-colors duration-100">
                          <td class="px-4 py-3.5 font-medium text-sm text-base-content">{key.name}</td>
                          <td class="px-4 py-3.5 font-mono text-sm text-base-content/70">{key.key_prefix}...</td>
                          <td class="px-4 py-3.5">
                            <span class="inline-flex px-2 py-0.5 rounded-md bg-base-200 text-xs font-medium text-base-content/70">
                              {key.permissions}
                            </span>
                          </td>
                          <td class="px-4 py-3.5 text-sm text-base-content/50">
                            {format_last_used(key.last_used_at)}
                          </td>
                          <td class="px-4 py-3.5">
                            <button
                              phx-click="delete_api_key"
                              phx-value-id={key.id}
                              data-confirm="Are you sure you want to delete this API key?"
                              class="p-1.5 rounded-lg hover:bg-error/10 transition-colors duration-150"
                            >
                              <.icon name="hero-trash" class="w-4 h-4 text-error" />
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>

            <%!-- Quick Start --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="flex items-center gap-2 px-5 py-4 border-b border-base-200 bg-base-200/30">
                <div class="p-1.5 rounded-lg bg-success/10">
                  <.icon name="hero-rocket-launch" class="w-4 h-4 text-success" />
                </div>
                <h2 class="font-semibold text-base-content">Quick Start</h2>
              </div>

              <div class="p-5 space-y-4">
                <p class="text-sm text-base-content/70">
                  Send your first event using curl:
                </p>

                <.curl_example endpoint={endpoint_url()} />
              </div>
            </div>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Stats --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="px-5 py-4 border-b border-base-200 bg-base-200/30">
                <h2 class="font-semibold text-base-content">Statistics</h2>
              </div>
              <div class="p-5">
                <dl class="space-y-5">
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Total Events</dt>
                    <dd class="text-3xl font-bold text-base-content mt-1">{format_number(@event_count)}</dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">API Keys</dt>
                    <dd class="text-3xl font-bold text-base-content mt-1">{length(@api_keys)}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <%!-- Project Info --%>
            <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden">
              <div class="px-5 py-4 border-b border-base-200 bg-base-200/30">
                <h2 class="font-semibold text-base-content">Project Info</h2>
              </div>
              <div class="p-5">
                <dl class="space-y-4">
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Project ID</dt>
                    <dd class="mt-1.5 font-mono text-sm text-base-content break-all bg-base-200/50 px-2 py-1.5 rounded-md">{@project.id}</dd>
                  </div>
                  <div>
                    <dt class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Created</dt>
                    <dd class="mt-1.5 text-sm text-base-content">{format_datetime(@project.inserted_at)}</dd>
                  </div>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create API Key Modal --%>
      <%= if @show_key_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_key_modal"
          />

          <%!-- Modal --%>
          <div class="relative w-full max-w-md mx-4 rounded-xl border border-base-300 bg-base-100 shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
              <h3 class="text-lg font-semibold text-base-content">
                {if @new_api_key, do: "API Key Created", else: "Create API Key"}
              </h3>
              <button
                phx-click="close_key_modal"
                class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150"
              >
                <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/50" />
              </button>
            </div>

            <%= if @new_api_key do %>
              <div class="p-6">
                <div class="flex items-start gap-3 p-4 rounded-lg bg-warning/10 border border-warning/30 mb-5">
                  <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning flex-shrink-0 mt-0.5" />
                  <p class="text-sm text-warning">Make sure to copy your API key now. You won't be able to see it again!</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-base-content mb-1.5">Your API Key</label>
                  <div class="flex items-center gap-2">
                    <input
                      type="text"
                      value={@new_api_key}
                      readonly
                      class="flex-1 px-3 py-2.5 rounded-lg border border-base-300 bg-base-200/50 font-mono text-sm text-base-content"
                      id="api-key-input"
                    />
                    <button
                      type="button"
                      class="flex-shrink-0 p-2.5 rounded-lg border border-base-300 bg-base-100 hover:bg-base-200 transition-colors duration-150"
                      onclick="navigator.clipboard.writeText(document.getElementById('api-key-input').value)"
                    >
                      <.icon name="hero-clipboard" class="w-4 h-4 text-base-content/70" />
                    </button>
                  </div>
                </div>

                <div class="flex justify-end mt-6 pt-4 border-t border-base-200">
                  <button
                    type="button"
                    phx-click="close_key_modal"
                    class="px-4 py-2 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150"
                  >
                    Done
                  </button>
                </div>
              </div>
            <% else %>
              <.form for={@key_form} phx-submit="create_api_key" class="p-6 space-y-5" id="api-key-form">
                <div>
                  <label class="block text-sm font-medium text-base-content mb-1.5">Key Name</label>
                  <input
                    type="text"
                    name="name"
                    placeholder="Production Server"
                    class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                    required
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-base-content mb-1.5">Permissions</label>
                  <select
                    name="permissions"
                    class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150 cursor-pointer"
                  >
                    <option value="write">Write (can send events)</option>
                    <option value="read">Read (can read events)</option>
                    <option value="admin">Admin (full access)</option>
                  </select>
                </div>

                <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                  <button
                    type="button"
                    phx-click="close_key_modal"
                    class="px-4 py-2 rounded-lg text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150 shadow-sm"
                  >
                    Create Key
                  </button>
                </div>
              </.form>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Edit Project Modal --%>
      <%= if @show_edit_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_edit_modal"
          />

          <%!-- Modal --%>
          <div class="relative w-full max-w-md mx-4 rounded-xl border border-base-300 bg-base-100 shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
              <h3 class="text-lg font-semibold text-base-content">Edit Project</h3>
              <button
                phx-click="close_edit_modal"
                class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150"
              >
                <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/50" />
              </button>
            </div>

            <.form for={@project_form} phx-submit="update_project" class="p-6 space-y-5" id="edit-project-form">
              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">Project Name</label>
                <.input
                  field={@project_form[:name]}
                  type="text"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">Slug</label>
                <.input
                  field={@project_form[:slug]}
                  type="text"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content font-mono focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  required
                />
                <p class="mt-1 text-xs text-base-content/50">
                  URL-friendly identifier (lowercase, alphanumeric, dashes)
                </p>
              </div>

              <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                <button
                  type="button"
                  phx-click="close_edit_modal"
                  class="px-4 py-2 rounded-lg text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150 shadow-sm"
                >
                  Save Changes
                </button>
              </div>
            </.form>
          </div>
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
    <div class="rounded-lg bg-base-200/50 border border-base-300 p-4 overflow-x-auto">
      <pre class="text-sm font-mono text-base-content/80 whitespace-pre-wrap">{@curl_cmd}</pre>
    </div>
    """
  end
end
