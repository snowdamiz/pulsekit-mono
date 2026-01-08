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
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content tracking-tight">Workspaces</h1>
            <p class="text-base-content/60 mt-1">Organize your projects into workspaces</p>
          </div>
          <a
            href="/organizations/new"
            class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-primary text-primary-content font-medium text-sm hover:brightness-110 transition-all duration-150 shadow-sm hover:shadow-md"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            New Workspace
          </a>
        </div>

        <%!-- Workspaces Grid --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
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
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_modal"
          />

          <%!-- Modal --%>
          <div class="relative w-full max-w-md mx-4 rounded-xl border border-base-300 bg-base-100 shadow-xl">
            <div class="flex items-center justify-between px-6 py-4 border-b border-base-200">
              <h3 class="text-lg font-semibold text-base-content">Create New Workspace</h3>
              <button
                phx-click="close_modal"
                class="p-1.5 rounded-lg hover:bg-base-200 transition-colors duration-150"
              >
                <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/50" />
              </button>
            </div>

            <.form for={@form} phx-submit="create_organization" class="p-6 space-y-5" id="organization-form">
              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">
                  Workspace Name
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="My Microservices"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-base-content mb-1.5">
                  Description (optional)
                </label>
                <.input
                  field={@form[:description]}
                  type="text"
                  placeholder="A brief description of this workspace"
                  class="w-full px-3 py-2.5 rounded-lg border border-base-300 bg-base-100 text-base-content placeholder:text-base-content/40 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none transition-all duration-150"
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
                  Create Workspace
                </button>
              </div>
            </.form>
          </div>
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
      "group rounded-xl border bg-base-100 shadow-sm hover:shadow-md transition-all duration-150 overflow-hidden",
      if(@is_current, do: "border-primary", else: "border-base-300 hover:border-primary/30")
    ]}>
      <%!-- Orange top accent bar for current workspace --%>
      <div class={["h-1", if(@is_current, do: "bg-gradient-to-r from-primary to-primary/60", else: "bg-base-200")]} />

      <div class="p-5">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h2 class="font-semibold text-base-content truncate">{@organization.name}</h2>
              <%= if @is_current do %>
                <span class="flex-shrink-0 px-2 py-0.5 rounded-md bg-primary/10 text-primary text-xs font-semibold">
                  Current
                </span>
              <% end %>
            </div>
            <p class="text-xs text-base-content/50 font-mono mt-1 truncate">{@organization.slug}</p>
            <%= if @organization.description do %>
              <p class="text-sm text-base-content/60 mt-2 line-clamp-2">{@organization.description}</p>
            <% end %>
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
                  href={"/organizations/#{@organization.id}"}
                  class="flex items-center gap-2 px-3 py-2 rounded-md text-sm text-base-content hover:bg-base-200 transition-colors duration-100"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                  View
                </a>
              </li>
              <li>
                <a
                  href={"/organizations/#{@organization.id}/edit"}
                  class="flex items-center gap-2 px-3 py-2 rounded-md text-sm text-base-content hover:bg-base-200 transition-colors duration-100"
                >
                  <.icon name="hero-pencil" class="w-4 h-4" />
                  Edit
                </a>
              </li>
              <%= if @can_delete do %>
                <li class="border-t border-base-200 mt-1 pt-1">
                  <button
                    phx-click="delete_organization"
                    phx-value-id={@organization.id}
                    data-confirm="Are you sure? This will delete all projects and events in this workspace."
                    class="flex items-center gap-2 w-full px-3 py-2 rounded-md text-sm text-error hover:bg-error/10 transition-colors duration-100"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                    Delete
                  </button>
                </li>
              <% end %>
            </ul>
          </div>
        </div>

        <div class="mt-5 pt-4 border-t border-base-200">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <span class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Projects</span>
              <p class="font-bold text-xl text-base-content mt-1">{@stats.project_count}</p>
            </div>
            <div>
              <span class="text-xs font-medium text-base-content/50 uppercase tracking-wider">Events</span>
              <p class="font-bold text-xl text-base-content mt-1">{format_number(@stats.total_events)}</p>
            </div>
          </div>
        </div>

        <a
          href={"/?org=#{@organization.id}"}
          class="mt-4 flex items-center justify-center gap-2 w-full px-4 py-2 rounded-lg border border-base-300 text-sm font-medium text-base-content hover:bg-base-200 hover:border-base-400 transition-all duration-150"
        >
          Switch to Workspace
          <.icon name="hero-arrow-right" class="w-4 h-4" />
        </a>
      </div>
    </div>
    """
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"
end
