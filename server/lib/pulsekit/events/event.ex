defmodule Pulsekit.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @levels ~w(debug info warning error fatal)

  schema "events" do
    field :type, :string
    field :level, :string, default: "info"
    field :message, :string
    field :metadata, :map, default: %{}
    field :stacktrace, :map
    field :environment, :string
    field :release, :string
    field :tags, :map, default: %{}
    field :fingerprint, :string
    field :timestamp, :utc_datetime

    belongs_to :project, Pulsekit.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:type, :level, :message, :metadata, :stacktrace, :environment, :release, :tags, :fingerprint, :timestamp])
    |> validate_required([:type, :timestamp])
    |> validate_inclusion(:level, @levels)
    |> maybe_generate_fingerprint()
    |> encode_json_fields()
  end

  def create_changeset(event, attrs, project_id) do
    timestamp = Map.get(attrs, "timestamp") || Map.get(attrs, :timestamp) || DateTime.utc_now()

    event
    |> cast(attrs, [:type, :level, :message, :metadata, :stacktrace, :environment, :release, :tags, :fingerprint])
    |> validate_required([:type])
    |> validate_inclusion(:level, @levels)
    |> put_change(:project_id, project_id)
    |> put_change(:timestamp, normalize_timestamp(timestamp))
    |> maybe_generate_fingerprint()
    |> encode_json_fields()
  end

  defp normalize_timestamp(%DateTime{} = dt), do: DateTime.truncate(dt, :second)
  defp normalize_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
  defp normalize_timestamp(_), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp maybe_generate_fingerprint(changeset) do
    case get_change(changeset, :fingerprint) do
      nil ->
        type = get_field(changeset, :type)
        message = get_field(changeset, :message) || ""

        fingerprint =
          :crypto.hash(:md5, "#{type}:#{message}")
          |> Base.encode16(case: :lower)
          |> String.slice(0, 16)

        put_change(changeset, :fingerprint, fingerprint)

      _ ->
        changeset
    end
  end

  defp encode_json_fields(changeset) do
    changeset
    |> encode_json_field(:metadata)
    |> encode_json_field(:stacktrace)
    |> encode_json_field(:tags)
  end

  defp encode_json_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_map(value) -> put_change(changeset, field, Jason.encode!(value))
      value when is_binary(value) -> changeset
      _ -> changeset
    end
  end

  def decode_json_fields(event) do
    %{event |
      metadata: decode_json(event.metadata),
      stacktrace: decode_json(event.stacktrace),
      tags: decode_json(event.tags)
    }
  end

  defp decode_json(nil), do: nil
  defp decode_json(value) when is_map(value), do: value
  defp decode_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> nil
    end
  end

  def levels, do: @levels
end
