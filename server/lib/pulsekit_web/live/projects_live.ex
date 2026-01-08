defmodule PulsekitWeb.ProjectsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Projects
  alias Pulsekit.Projects.Project
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Projects")
      |> assign(:current_path, "/projects")
      |> LiveHelpers.assign_organization_context(params, session)
      |> load_projects()
      |> assign(:show_modal, false)
      |> assign(:form, to_form(Projects.change_project(%Project{})))

    {:ok, socket}
  end

  defp load_projects(socket) do
    projects =
      case socket.assigns.current_organization do
        nil -> []
        org -> Projects.list_projects_for_organization(org.id)
      end

    assign(socket, :projects, projects)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_modal, true)
    |> assign(:form, to_form(Projects.change_project(%Project{})))
  end

  defp apply_action(socket, _action, _params) do
    assign(socket, :show_modal, false)
  end

  @impl true
  def handle_event("create_project", %{"project" => project_params}, socket) do
    organization_id = socket.assigns.current_organization.id

    case Projects.create_project(organization_id, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> load_projects()
         |> assign(:show_modal, false)
         |> put_flash(:info, "Project '#{project.name}' created successfully!")
         |> push_navigate(to: "/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: "/projects")}
  end

  @impl true
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Projects.get_project!(id)

    case Projects.delete_project(project) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_projects()
         |> put_flash(:info, "Project deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
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
            <h1 class="text-2xl font-bold">Projects</h1>
            <p class="text-base-content/60 mt-1">Manage your projects and API keys</p>
          </div>
          <a href="/projects/new" class="btn btn-primary">
            <.icon name="hero-plus" class="w-4 h-4" />
            New Project
          </a>
        </div>

        <%!-- Projects Grid --%>
        <%= if length(@projects) == 0 do %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body items-center text-center py-16">
              <.icon name="hero-folder-plus" class="w-16 h-16 text-base-content/30" />
              <h2 class="card-title mt-4">No projects yet</h2>
              <p class="text-base-content/60 max-w-md">
                Create your first project to start tracking events and errors.
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
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for project <- @projects do %>
              <div class="card bg-base-100 border border-base-300 hover:border-primary/50 transition-colors">
                <div class="card-body">
                  <div class="flex items-start justify-between">
                    <div>
                      <h2 class="card-title">{project.name}</h2>
                      <p class="text-sm text-base-content/60 font-mono">{project.slug}</p>
                    </div>
                    <div class="dropdown dropdown-end">
                      <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
                        <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                      </div>
                      <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-40 border border-base-300">
                        <li>
                          <a href={"/projects/#{project.id}"}>
                            <.icon name="hero-eye" class="w-4 h-4" />
                            View
                          </a>
                        </li>
                        <li>
                          <a href={"/projects/#{project.id}/edit"}>
                            <.icon name="hero-pencil" class="w-4 h-4" />
                            Edit
                          </a>
                        </li>
                        <li>
                          <button
                            phx-click="delete_project"
                            phx-value-id={project.id}
                            data-confirm="Are you sure you want to delete this project? This will also delete all associated events and API keys."
                            class="text-error"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" />
                            Delete
                          </button>
                        </li>
                      </ul>
                    </div>
                  </div>

                  <div class="mt-4 pt-4 border-t border-base-300">
                    <div class="flex items-center justify-between text-sm">
                      <span class="text-base-content/60">Created</span>
                      <span>{format_date(project.inserted_at)}</span>
                    </div>
                  </div>

                  <div class="card-actions mt-4">
                    <a href={"/projects/#{project.id}"} class="btn btn-outline btn-sm flex-1">
                      View Details
                    </a>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Create Project Modal --%>
      <%= if @show_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <h3 class="font-bold text-lg mb-4">Create New Project</h3>

            <.form for={@form} phx-submit="create_project" class="space-y-4" id="project-form">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Project Name</span>
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="My Awesome App"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  Create Project
                </button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop bg-base-300/50" phx-click="close_modal"></div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
