defmodule PulsekitWeb.OrganizationsLive do
  use PulsekitWeb, :live_view

  alias Pulsekit.Organizations
  alias Pulsekit.Organizations.Organization
  alias PulsekitWeb.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Workspaces")
      |> assign(:current_path, "/organizations")
      |> LiveHelpers.assign_organization_context(params, session)
      |> assign(:show_modal, false)
      |> assign(:form, to_form(Organizations.change_organization(%Organization{})))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_modal, true)
    |> assign(:form, to_form(Organizations.change_organization(%Organization{})))
  end

  defp apply_action(socket, _action, _params) do
    assign(socket, :show_modal, false)
  end

  @impl true
  def handle_event("create_organization", %{"organization" => org_params}, socket) do
    case Organizations.create_organization(org_params) do
      {:ok, org} ->
        organizations = Organizations.list_organizations()

        {:noreply,
         socket
         |> assign(:organizations, organizations)
         |> assign(:current_organization, org)
         |> assign(:show_modal, false)
         |> put_flash(:info, "Workspace '#{org.name}' created successfully!")
         |> push_navigate(to: "/organizations/#{org.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: "/organizations")}
  end

  @impl true
  def handle_event("delete_organization", %{"id" => id}, socket) do
    org = Organizations.get_organization!(id)

    # Don't allow deleting the last organization
    if length(socket.assigns.organizations) <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot delete the last workspace")}
    else
      case Organizations.delete_organization(org) do
        {:ok, _} ->
          organizations = Organizations.list_organizations()
          current_org = List.first(organizations)

          {:noreply,
           socket
           |> assign(:organizations, organizations)
           |> assign(:current_organization, current_org)
           |> put_flash(:info, "Workspace deleted successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete workspace")}
      end
    end
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
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">Workspaces</h1>
            <p class="text-base-content/60 mt-1">Organize your projects into workspaces</p>
          </div>
          <a href="/organizations/new" class="btn btn-primary">
            <.icon name="hero-plus" class="w-4 h-4" />
            New Workspace
          </a>
        </div>

        <%!-- Workspaces Grid --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for org <- @organizations do %>
            <.organization_card
              organization={org}
              is_current={@current_organization && @current_organization.id == org.id}
              can_delete={length(@organizations) > 1}
            />
          <% end %>
        </div>
      </div>

      <%!-- Create Organization Modal --%>
      <%= if @show_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <h3 class="font-bold text-lg mb-4">Create New Workspace</h3>

            <.form for={@form} phx-submit="create_organization" class="space-y-4" id="organization-form">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Workspace Name</span>
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="My Microservices"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Description (optional)</span>
                </label>
                <.input
                  field={@form[:description]}
                  type="text"
                  placeholder="A brief description of this workspace"
                  class="input input-bordered w-full"
                />
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  Create Workspace
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

  attr :organization, :map, required: true
  attr :is_current, :boolean, default: false
  attr :can_delete, :boolean, default: true

  defp organization_card(assigns) do
    stats = Organizations.get_organization_stats(assigns.organization.id)
    assigns = assign(assigns, :stats, stats)

    ~H"""
    <div class={[
      "card bg-base-100 border transition-colors",
      if(@is_current, do: "border-primary", else: "border-base-300 hover:border-primary/50")
    ]}>
      <div class="card-body">
        <div class="flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2">
              <h2 class="card-title">{@organization.name}</h2>
              <%= if @is_current do %>
                <span class="badge badge-primary badge-sm">Current</span>
              <% end %>
            </div>
            <p class="text-sm text-base-content/60 font-mono">{@organization.slug}</p>
            <%= if @organization.description do %>
              <p class="text-sm text-base-content/70 mt-2">{@organization.description}</p>
            <% end %>
          </div>
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
            </div>
            <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-40 border border-base-300">
              <li>
                <a href={"/organizations/#{@organization.id}"}>
                  <.icon name="hero-eye" class="w-4 h-4" />
                  View
                </a>
              </li>
              <li>
                <a href={"/organizations/#{@organization.id}/edit"}>
                  <.icon name="hero-pencil" class="w-4 h-4" />
                  Edit
                </a>
              </li>
              <%= if @can_delete do %>
                <li>
                  <button
                    phx-click="delete_organization"
                    phx-value-id={@organization.id}
                    data-confirm="Are you sure? This will delete all projects and events in this workspace."
                    class="text-error"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                    Delete
                  </button>
                </li>
              <% end %>
            </ul>
          </div>
        </div>

        <div class="mt-4 pt-4 border-t border-base-300">
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="text-base-content/60">Projects</span>
              <p class="font-bold text-lg">{@stats.project_count}</p>
            </div>
            <div>
              <span class="text-base-content/60">Total Events</span>
              <p class="font-bold text-lg">{format_number(@stats.total_events)}</p>
            </div>
          </div>
        </div>

        <div class="card-actions mt-4">
          <a href={"/?org=#{@organization.id}"} class="btn btn-outline btn-sm flex-1">
            Switch to Workspace
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"
end
