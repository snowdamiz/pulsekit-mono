defmodule Pulsekit.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :level, :string, null: false, default: "info"
      add :message, :text
      add :metadata, :text
      add :stacktrace, :text
      add :environment, :string
      add :release, :string
      add :tags, :text
      add :fingerprint, :string
      add :timestamp, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:events, [:project_id])
    create index(:events, [:project_id, :type])
    create index(:events, [:project_id, :level])
    create index(:events, [:project_id, :timestamp])
    create index(:events, [:project_id, :fingerprint])
  end
end
