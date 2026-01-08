defmodule PulsekitWeb.Api.V1.EventController do
  use PulsekitWeb, :controller

  alias Pulsekit.Events
  alias Pulsekit.Alerts

  action_fallback PulsekitWeb.FallbackController

  def create(conn, params) do
    project = conn.assigns.project

    case Events.create_event(project.id, params) do
      {:ok, event} ->
        # Evaluate alert rules asynchronously
        Task.start(fn -> Alerts.evaluate_event(event) end)

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          event: %{
            id: event.id,
            type: event.type,
            level: event.level,
            timestamp: event.timestamp
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def batch(conn, %{"events" => events}) when is_list(events) do
    project = conn.assigns.project

    {:ok, count} = Events.create_events(project.id, events)

    conn
    |> put_status(:created)
    |> json(%{
      success: true,
      count: count
    })
  end

  def batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Invalid request",
      message: "Expected 'events' array in request body"
    })
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
