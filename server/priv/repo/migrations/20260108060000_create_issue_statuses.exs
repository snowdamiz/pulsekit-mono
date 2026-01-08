defmodule Pulsekit.Repo.Migrations.CreateIssueStatuses do
  use Ecto.Migration

  def change do
    create table(:issue_statuses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :fingerprint, :string, null: false
      add :status, :string, null: false, default: "unresolved"
      add :resolved_at, :utc_datetime
      add :ignored_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issue_statuses, [:project_id, :fingerprint])
    create index(:issue_statuses, [:project_id, :status])
  end
end
