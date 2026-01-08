defmodule Pulsekit.Alerts.AlertRule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @condition_types ~w(threshold new_error pattern_match)

  schema "alert_rules" do
    field :name, :string
    field :condition_type, :string
    field :condition_config, :map, default: %{}
    field :webhook_url, :string
    field :enabled, :boolean, default: true

    belongs_to :project, Pulsekit.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert_rule, attrs) do
    alert_rule
    |> cast(attrs, [:name, :condition_type, :condition_config, :webhook_url, :enabled])
    |> validate_required([:name, :condition_type, :webhook_url])
    |> validate_inclusion(:condition_type, @condition_types)
    |> validate_url(:webhook_url)
    |> encode_json_field(:condition_config)
  end

  def create_changeset(alert_rule, attrs, project_id) do
    alert_rule
    |> cast(attrs, [:name, :condition_type, :condition_config, :webhook_url, :enabled])
    |> validate_required([:name, :condition_type, :webhook_url])
    |> validate_inclusion(:condition_type, @condition_types)
    |> validate_url(:webhook_url)
    |> put_change(:project_id, project_id)
    |> encode_json_field(:condition_config)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case URI.parse(value) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
          []

        _ ->
          [{field, "must be a valid HTTP(S) URL"}]
      end
    end)
  end

  defp encode_json_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_map(value) -> put_change(changeset, field, Jason.encode!(value))
      value when is_binary(value) -> changeset
      _ -> changeset
    end
  end

  def decode_json_fields(alert_rule) do
    %{alert_rule |
      condition_config: decode_json(alert_rule.condition_config)
    }
  end

  defp decode_json(nil), do: %{}
  defp decode_json(value) when is_map(value), do: value
  defp decode_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end

  def condition_types, do: @condition_types
end
