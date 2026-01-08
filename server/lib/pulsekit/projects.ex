defmodule Pulsekit.Projects do
  @moduledoc """
  The Projects context - manages projects and API keys.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Projects.{Project, ApiKey}

  # Projects

  @doc """
  Lists all projects.
  """
  def list_projects do
    Project
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  @doc """
  Lists projects for a specific organization.
  """
  def list_projects_for_organization(organization_id) do
    Project
    |> where([p], p.organization_id == ^organization_id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get_project!(id), do: Repo.get!(Project, id)

  def get_project(id), do: Repo.get(Project, id)

  def get_project_by_slug(slug), do: Repo.get_by(Project, slug: slug)

  def get_project_with_organization!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload(:organization)
  end

  @doc """
  Creates a project within an organization.
  """
  def create_project(organization_id, attrs \\ %{}) do
    %Project{}
    |> Project.create_changeset(attrs, organization_id)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  # API Keys

  def list_api_keys(project_id) do
    ApiKey
    |> where([k], k.project_id == ^project_id)
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end

  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  def get_api_key(id), do: Repo.get(ApiKey, id)

  def get_api_key_by_hash(key_hash) do
    Repo.get_by(ApiKey, key_hash: key_hash)
  end

  def authenticate_api_key(raw_key) do
    key_hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)

    case get_api_key_by_hash(key_hash) do
      nil ->
        {:error, :invalid_key}

      api_key ->
        api_key = Repo.preload(api_key, project: :organization)
        touch_api_key_last_used(api_key)
        {:ok, api_key}
    end
  end

  def create_api_key(project_id, attrs \\ %{}) do
    %ApiKey{}
    |> ApiKey.create_changeset(attrs, project_id)
    |> Repo.insert()
  end

  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
  end

  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  defp touch_api_key_last_used(api_key) do
    api_key
    |> ApiKey.touch_last_used()
    |> Repo.update()
  end
end
