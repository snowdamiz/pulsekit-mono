defmodule Pulsekit.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :key_hash, :string, null: false
      add :key_prefix, :string, null: false
      add :name, :string, null: false
      add :permissions, :string, default: "write"
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:api_keys, [:project_id])
    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:key_prefix])
  end
end
