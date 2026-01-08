defmodule Pulsekit.Projects.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field :key_hash, :string
    field :key_prefix, :string
    field :name, :string
    field :permissions, :string, default: "write"
    field :last_used_at, :utc_datetime

    # Virtual field for the raw key (only available on creation)
    field :raw_key, :string, virtual: true

    belongs_to :project, Pulsekit.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :permissions])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:permissions, ["read", "write", "admin"])
  end

  def create_changeset(api_key, attrs, project_id) do
    raw_key = generate_api_key()
    key_hash = hash_key(raw_key)
    key_prefix = String.slice(raw_key, 0, 8)

    api_key
    |> cast(attrs, [:name, :permissions])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:permissions, ["read", "write", "admin"])
    |> put_change(:project_id, project_id)
    |> put_change(:key_hash, key_hash)
    |> put_change(:key_prefix, key_prefix)
    |> put_change(:raw_key, raw_key)
  end

  def touch_last_used(api_key) do
    api_key
    |> change(%{last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  defp generate_api_key do
    "pk_" <> Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
  end

  defp hash_key(key) do
    :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)
  end

  def verify_key(raw_key, key_hash) do
    hash_key(raw_key) == key_hash
  end
end
