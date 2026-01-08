defmodule PulsekitWeb.LiveHelpers do
  @moduledoc """
  Shared helpers for LiveView pages.
  """

  import Phoenix.Component
  alias Pulsekit.Organizations

  @doc """
  Assigns organization context to the socket.
  Loads all organizations and sets the current organization from session or query params.
  """
  def assign_organization_context(socket, params, session) do
    organizations = Organizations.list_organizations()

    current_org_id =
      params["org"] ||
      get_in(session, ["current_organization_id"]) ||
      (List.first(organizations) && List.first(organizations).id)

    current_organization =
      if current_org_id do
        Enum.find(organizations, fn org -> org.id == current_org_id end) ||
        List.first(organizations)
      else
        case organizations do
          [] ->
            # Create default organization if none exist
            {:ok, org} = Organizations.create_organization(%{name: "Default Workspace"})
            org

          [org | _] ->
            org
        end
      end

    # Reload organizations list in case we created a default one
    organizations =
      if organizations == [] do
        Organizations.list_organizations()
      else
        organizations
      end

    socket
    |> assign(:organizations, organizations)
    |> assign(:current_organization, current_organization)
  end

  @doc """
  Handles organization switching event.
  """
  def handle_org_switch(socket, org_id) do
    organizations = socket.assigns.organizations
    current_organization = Enum.find(organizations, fn org -> org.id == org_id end)

    socket
    |> assign(:current_organization, current_organization)
  end
end
