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
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Projects</h1>
            <p class="text-base-content/60 mt-1">Manage your projects and API keys</p>
          </div>
          <a
            href="/projects/new"
            class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            New Project
          </a>
        </div>

        <%!-- Projects Grid --%>
        <%= if length(@projects) == 0 do %>
          <div class="rounded-xl border border-base-300 bg-base-100 shadow-sm">
            <div class="flex flex-col items-center text-center py-20 px-6">
              <div class="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
                <.icon name="hero-folder-plus" class="w-10 h-10 text-primary" />
              </div>
              <h2 class="text-xl font-semibold text-base-content">No projects yet</h2>
              <p class="text-base-content/60 max-w-md mt-2">
                Create your first project to start tracking events and errors.
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
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            <%= for project <- @projects do %>
              <div class="group rounded-xl border border-base-300 bg-base-100 shadow-sm hover:shadow-md hover:border-primary/30 transition-all duration-150 overflow-hidden">
                <%!-- Orange top accent bar --%>
                <div class="h-1 bg-gradient-to-r from-primary to-primary/60" />

                <div class="p-5">
                  <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                      <h2 class="font-semibold text-base-content truncate">{project.name}</h2>
                      <p class="text-xs text-base-content/50 font-mono mt-1 truncate">{project.slug}</p>
                    </div>
                    <div class="dropdown dropdown-end flex-shrink-0">
                      <div
                        tabindex="0"
                        role="button"
                        class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150 cursor-pointer"
                      >
                        <.icon name="hero-ellipsis-vertical" class="w-5 h-5 text-base-content/50" />
                      </div>
                      <ul tabindex="0" class="dropdown-content z-[1] mt-1 p-1.5 w-40 bg-base-100 rounded-lg border border-base-300 shadow-lg">
                        <li>
                          <a
                            href={"/projects/#{project.id}"}
                            class="flex items-center gap-2 px-3 py-2 rounded-md text-sm text-base-content hover:bg-base-200 transition-colors duration-100"
                          >
                            <.icon name="hero-eye" class="w-4 h-4" />
                            View
                          </a>
                        </li>
                        <li>
                          <a
                            href={"/projects/#{project.id}/edit"}
                            class="flex items-center gap-2 px-3 py-2 rounded-md text-sm text-base-content hover:bg-base-200 transition-colors duration-100"
                          >
                            <.icon name="hero-pencil" class="w-4 h-4" />
                            Edit
                          </a>
                        </li>
                        <li class="border-t border-base-200 mt-1 pt-1">
                          <button
                            phx-click="delete_project"
                            phx-value-id={project.id}
                            data-confirm="Are you sure you want to delete this project? This will also delete all associated events and API keys."
                            class="flex items-center gap-2 w-full px-3 py-2 rounded-md text-sm text-error hover:bg-error/10 transition-colors duration-100"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" />
                            Delete
                          </button>
                        </li>
                      </ul>
                    </div>
                  </div>

                  <div class="mt-5 pt-4 border-t border-base-200">
                    <div class="flex items-center justify-between text-sm">
                      <span class="text-base-content/50">Created</span>
                      <span class="font-medium text-base-content/70">{format_date(project.inserted_at)}</span>
                    </div>
                  </div>

                  <a
                    href={"/projects/#{project.id}"}
                    class="mt-4 flex items-center justify-center gap-2 w-full px-4 py-2 rounded-lg border border-base-300 text-sm font-medium text-base-content hover:bg-base-200 hover:border-base-400 transition-all duration-150"
                  >
                    View Details
                    <.icon name="hero-arrow-right" class="w-4 h-4" />
                  </a>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Create Project Modal --%>
      <%= if @show_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_modal"
          />

          <%!-- Modal --%>
          <div class="relative w-full max-w-md mx-4 rounded-xl border border-base-300 bg-base-100 shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
              <h3 class="text-lg font-semibold text-base-content">Create New Project</h3>
              <button
                phx-click="close_modal"
                class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150"
              >
                <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/50" />
              </button>
            </div>

            <.form for={@form} phx-submit="create_project" class="p-6" id="project-form">
              <div class="mb-6">
                <label class="block text-sm font-medium text-base-content mb-1.5">
                  Project Name
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="My Awesome App"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  required
                />
              </div>

              <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 rounded-lg text-sm font-medium text-base-content hover:bg-base-200 transition-colors duration-150"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 rounded-lg bg-primary text-primary-content text-sm font-medium hover:brightness-110 transition-all duration-150 shadow-sm"
                >
                  Create Project
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
