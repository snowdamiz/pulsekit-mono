defmodule Pulsekit.Organizations do
  @moduledoc """
  The Organizations context - manages workspaces that group projects together.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Organizations.Organization

  @doc """
  Returns the list of organizations.
  """
  def list_organizations do
    Organization
    |> order_by([o], asc: o.name)
    |> Repo.all()
  end

  @doc """
  Gets a single organization.
  """
  def get_organization!(id), do: Repo.get!(Organization, id)

  def get_organization(id), do: Repo.get(Organization, id)

  @doc """
  Gets an organization by slug.
  """
  def get_organization_by_slug(slug), do: Repo.get_by(Organization, slug: slug)

  @doc """
  Gets an organization with preloaded projects.
  """
  def get_organization_with_projects!(id) do
    Organization
    |> Repo.get!(id)
    |> Repo.preload(:projects)
  end

  @doc """
  Creates an organization.
  """
  def create_organization(attrs \\ %{}) do
    %Organization{}
    |> Organization.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an organization.
  """
  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an organization.
  """
  def delete_organization(%Organization{} = organization) do
    Repo.delete(organization)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organization changes.
  """
  def change_organization(%Organization{} = organization, attrs \\ %{}) do
    Organization.changeset(organization, attrs)
  end

  @doc """
  Gets the first organization or creates a default one.
  """
  def get_or_create_default_organization do
    case list_organizations() do
      [] ->
        {:ok, org} = create_organization(%{name: "Default Workspace"})
        org

      [org | _] ->
        org
    end
  end

  @doc """
  Counts projects in an organization.
  """
  def count_projects(organization_id) do
    Pulsekit.Projects.Project
    |> where([p], p.organization_id == ^organization_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets aggregate stats for an organization.
  """
  def get_organization_stats(organization_id) do
    projects = Pulsekit.Projects.list_projects_for_organization(organization_id)
    project_ids = Enum.map(projects, & &1.id)

    total_events =
      if project_ids == [] do
        0
      else
        Pulsekit.Events.Event
        |> where([e], e.project_id in ^project_ids)
        |> Repo.aggregate(:count)
      end

    %{
      project_count: length(projects),
      total_events: total_events
    }
  end
end
