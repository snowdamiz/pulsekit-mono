defmodule Pulsekit.Issues.IssueStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(unresolved resolved ignored)

  schema "issue_statuses" do
    field :fingerprint, :string
    field :status, :string, default: "unresolved"
    field :resolved_at, :utc_datetime
    field :ignored_at, :utc_datetime

    belongs_to :project, Pulsekit.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(issue_status, attrs) do
    issue_status
    |> cast(attrs, [:fingerprint, :status, :resolved_at, :ignored_at])
    |> validate_required([:fingerprint, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:project_id, :fingerprint])
  end

  def create_changeset(issue_status, attrs, project_id) do
    issue_status
    |> cast(attrs, [:fingerprint, :status, :resolved_at, :ignored_at])
    |> validate_required([:fingerprint])
    |> validate_inclusion(:status, @statuses)
    |> put_change(:project_id, project_id)
    |> unique_constraint([:project_id, :fingerprint])
  end

  def statuses, do: @statuses
end
