defmodule PulsekitWeb.OrganizationDetailLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Organizations
  alias Pulsekit.Projects
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    organization = Organizations.get_organization_with_projects!(id)
    projects = Projects.list_projects_for_organization(id)
    stats = Organizations.get_organization_stats(id)

    socket =
      socket
      |> assign(:page_title, organization.name)
      |> assign(:current_path, "/organizations")
      |> LiveHelpers.assign_organization_context(params, session)
      |> assign(:organization, organization)
      |> assign(:projects, projects)
      |> assign(:stats, stats)
      |> assign(:show_edit_modal, false)
      |> assign(:form, to_form(Organizations.change_organization(organization)))

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
    assign(socket, :show_edit_modal, false)
  end

  @impl true
  def handle_event("update_organization", %{"organization" => org_params}, socket) do
    case Organizations.update_organization(socket.assigns.organization, org_params) do
      {:ok, organization} ->
        organizations = Organizations.list_organizations()

        {:noreply,
         socket
         |> assign(:organization, organization)
         |> assign(:organizations, organizations)
         |> assign(:show_edit_modal, false)
         |> put_flash(:info, "Workspace updated successfully")
         |> push_patch(to: "/organizations/#{organization.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, push_patch(socket, to: "/organizations/#{socket.assigns.organization.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_path={@current_path}
      current_organization={@current_organization}
      organizations={@organizations}
    >
      <div class="space-y-6">
        <%!-- Breadcrumb --%>
        <div class="flex items-center gap-2 text-sm">
          <a href="/organizations" class="text-base-content/60 hover:text-base-content">Workspaces</a>
          <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
          <span class="font-medium">{@organization.name}</span>
        </div>

        <%!-- Header --%>
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold">{@organization.name}</h1>
            <p class="text-base-content/60 mt-1 font-mono">{@organization.slug}</p>
            <%= if @organization.description do %>
              <p class="text-base-content/70 mt-2">{@organization.description}</p>
            <% end %>
          </div>
          <div class="flex gap-2">
            <a href={"/?org=#{@organization.id}"} class="btn btn-primary">
              <.icon name="hero-arrow-right-start-on-rectangle" class="w-4 h-4" />
              Switch to Workspace
            </a>
            <a href={"/organizations/#{@organization.id}/edit"} class="btn btn-outline">
              <.icon name="hero-pencil" class="w-4 h-4" />
              Edit
            </a>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Projects --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="card-title text-lg">
                    <.icon name="hero-folder" class="w-5 h-5" />
                    Projects
                  </h2>
                  <a href={"/projects/new?org=#{@organization.id}"} class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="w-4 h-4" />
                    New Project
                  </a>
                </div>

                <%= if length(@projects) == 0 do %>
                  <div class="text-center py-8 text-base-content/60">
                    <.icon name="hero-folder" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>No projects yet</p>
                    <p class="text-sm mt-1">Create your first project in this workspace</p>
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <%= for project <- @projects do %>
                      <a
                        href={"/projects/#{project.id}"}
                        class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors"
                      >
                        <div class="flex items-center gap-3">
                          <.icon name="hero-folder" class="w-5 h-5 text-primary" />
                          <div>
                            <p class="font-medium">{project.name}</p>
                            <p class="text-sm text-base-content/60 font-mono">{project.slug}</p>
                          </div>
                        </div>
                        <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
                      </a>
                    <% end %>
                  </div>
                <% end %>
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
                    <dt class="text-sm text-base-content/60">Projects</dt>
                    <dd class="text-2xl font-bold mt-1">{@stats.project_count}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Total Events</dt>
                    <dd class="text-2xl font-bold mt-1">{format_number(@stats.total_events)}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <%!-- Workspace Info --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-lg mb-4">Workspace Info</h2>
                <dl class="space-y-4">
                  <div>
                    <dt class="text-sm text-base-content/60">Workspace ID</dt>
                    <dd class="font-mono text-sm mt-1 break-all">{@organization.id}</dd>
                  </div>
                  <div>
                    <dt class="text-sm text-base-content/60">Created</dt>
                    <dd class="mt-1">{format_datetime(@organization.inserted_at)}</dd>
                  </div>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Edit Organization Modal --%>
      <%= if @show_edit_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_edit_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <h3 class="font-bold text-lg mb-4">Edit Workspace</h3>

            <.form for={@form} phx-submit="update_organization" class="space-y-4" id="edit-organization-form">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Workspace Name</span>
                </label>
                <.input
                  field={@form[:name]}
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
                  field={@form[:slug]}
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

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Description (optional)</span>
                </label>
                <.input
                  field={@form[:description]}
                  type="text"
                  class="input input-bordered w-full"
                />
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

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %H:%M UTC")
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"
end
