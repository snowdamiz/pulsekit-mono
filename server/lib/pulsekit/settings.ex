defmodule Pulsekit.Settings do
  @moduledoc """
  The Settings context - manages global application settings.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Settings.Setting

  @doc """
  Gets a setting value by key.
  Returns nil if the setting doesn't exist.
  """
  def get(key) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> nil
      setting -> setting.value
    end
  end

  @doc """
  Gets a setting value by key with a default value.
  """
  def get(key, default) when is_binary(key) do
    get(key) || default
  end

  @doc """
  Sets a setting value.
  Creates the setting if it doesn't exist, updates it otherwise.
  """
  def set(key, value) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{}
        |> Setting.changeset(%{key: key, value: to_string(value)})
        |> Repo.insert()

      setting ->
        setting
        |> Setting.changeset(%{value: to_string(value)})
        |> Repo.update()
    end
  end

  @doc """
  Deletes a setting by key.
  """
  def delete(key) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      nil -> {:ok, nil}
      setting -> Repo.delete(setting)
    end
  end

  @doc """
  Returns all settings as a map.
  """
  def all do
    Setting
    |> Repo.all()
    |> Map.new(fn s -> {s.key, s.value} end)
  end

  # Convenience functions for specific settings

  @doc """
  Gets the log retention period in days.
  Returns 30 (days) by default.
  Returns 0 for "forever" (no auto-delete).
  """
  def log_retention_days do
    case get("log_retention_days") do
      nil -> 30
      "0" -> 0
      days -> String.to_integer(days)
    end
  end

  @doc """
  Sets the log retention period in days.
  Pass 0 for "forever" (no auto-delete).
  """
  def set_log_retention_days(days) when is_integer(days) and days >= 0 do
    set("log_retention_days", days)
  end
end
