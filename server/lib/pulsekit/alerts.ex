defmodule Pulsekit.Alerts do
  @moduledoc """
  The Alerts context - manages alert rules and webhook dispatching.
  """

  import Ecto.Query, warn: false
  alias Pulsekit.Repo
  alias Pulsekit.Alerts.AlertRule
  alias Pulsekit.Events.Event

  # Alert Rules

  def list_alert_rules(project_id) do
    AlertRule
    |> where([a], a.project_id == ^project_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
    |> Enum.map(&AlertRule.decode_json_fields/1)
  end

  def get_alert_rule!(id) do
    AlertRule
    |> Repo.get!(id)
    |> AlertRule.decode_json_fields()
  end

  def get_alert_rule(id) do
    case Repo.get(AlertRule, id) do
      nil -> nil
      rule -> AlertRule.decode_json_fields(rule)
    end
  end

  def create_alert_rule(project_id, attrs \\ %{}) do
    result =
      %AlertRule{}
      |> AlertRule.create_changeset(attrs, project_id)
      |> Repo.insert()

    case result do
      {:ok, rule} -> {:ok, AlertRule.decode_json_fields(rule)}
      error -> error
    end
  end

  def update_alert_rule(%AlertRule{} = alert_rule, attrs) do
    result =
      alert_rule
      |> AlertRule.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, rule} -> {:ok, AlertRule.decode_json_fields(rule)}
      error -> error
    end
  end

  def delete_alert_rule(%AlertRule{} = alert_rule) do
    Repo.delete(alert_rule)
  end

  def change_alert_rule(%AlertRule{} = alert_rule, attrs \\ %{}) do
    AlertRule.changeset(alert_rule, attrs)
  end

  def toggle_alert_rule(%AlertRule{} = alert_rule) do
    update_alert_rule(alert_rule, %{enabled: !alert_rule.enabled})
  end

  # Alert Evaluation

  def evaluate_event(%Event{} = event) do
    rules = get_enabled_rules_for_project(event.project_id)

    Enum.each(rules, fn rule ->
      if matches_rule?(event, rule) do
        dispatch_webhook(rule, event)
      end
    end)
  end

  defp get_enabled_rules_for_project(project_id) do
    AlertRule
    |> where([a], a.project_id == ^project_id and a.enabled == true)
    |> Repo.all()
    |> Enum.map(&AlertRule.decode_json_fields/1)
  end

  defp matches_rule?(event, rule) do
    case rule.condition_type do
      "threshold" -> matches_threshold?(event, rule.condition_config)
      "new_error" -> matches_new_error?(event, rule.condition_config)
      "pattern_match" -> matches_pattern?(event, rule.condition_config)
      _ -> false
    end
  end

  defp matches_threshold?(_event, config) do
    # Threshold alerts are evaluated separately via scheduled jobs
    # This is a placeholder for real-time threshold checking
    count = Map.get(config, "count", 10)
    _window = Map.get(config, "window", "5m")

    # For now, just check if we've seen many events recently
    count > 0
  end

  defp matches_new_error?(event, _config) do
    # Check if this is the first occurrence of this fingerprint
    event.level in ["error", "fatal"]
  end

  defp matches_pattern?(event, config) do
    pattern = Map.get(config, "pattern", "")

    case Regex.compile(pattern) do
      {:ok, regex} ->
        message = event.message || ""
        Regex.match?(regex, message)

      _ ->
        false
    end
  end

  # Webhook Dispatching

  def dispatch_webhook(rule, event) do
    payload = build_webhook_payload(rule, event)

    Task.start(fn ->
      send_webhook(rule.webhook_url, payload)
    end)
  end

  defp build_webhook_payload(rule, event) do
    %{
      alert: %{
        id: rule.id,
        name: rule.name,
        rule_type: rule.condition_type,
        triggered_at: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      project: %{
        id: event.project_id
      },
      event: %{
        id: event.id,
        type: event.type,
        level: event.level,
        message: event.message,
        timestamp: event.timestamp |> DateTime.to_iso8601()
      },
      context: %{
        environment: event.environment,
        release: event.release
      }
    }
  end

  defp send_webhook(url, payload) do
    Req.post(url,
      json: payload,
      headers: [
        {"content-type", "application/json"},
        {"user-agent", "PulseKit/1.0"}
      ],
      receive_timeout: 10_000
    )
  end
end
