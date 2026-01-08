defmodule Pulsekit.Repo.Migrations.AddOrganizations do
  use Ecto.Migration

  def change do
    # Create organizations table
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug])

    # Add organization_id to projects
    alter table(:projects) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
    end

    create index(:projects, [:organization_id])

    # Create a default organization and assign existing projects to it
    execute """
    INSERT INTO organizations (id, name, slug, inserted_at, updated_at)
    SELECT
      lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)),2) || '-' || substr('89ab',abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6))),
      'Default Workspace',
      'default',
      datetime('now'),
      datetime('now')
    WHERE EXISTS (SELECT 1 FROM projects LIMIT 1)
    """, ""

    execute """
    UPDATE projects
    SET organization_id = (SELECT id FROM organizations WHERE slug = 'default' LIMIT 1)
    WHERE organization_id IS NULL
    """, ""
  end
end
