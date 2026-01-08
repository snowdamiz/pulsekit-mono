defmodule Pulsekit.Repo.Migrations.CreateAlertRules do
  use Ecto.Migration

  def change do
    create table(:alert_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :condition_type, :string, null: false
      add :condition_config, :text
      add :webhook_url, :string, null: false
      add :enabled, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:alert_rules, [:project_id])
    create index(:alert_rules, [:project_id, :enabled])
  end
end
