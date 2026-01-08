defmodule PulsekitWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for authenticating API requests using API keys.
  """

  import Plug.Conn
  alias Pulsekit.Projects

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, api_key} <- get_api_key_from_header(conn),
         {:ok, authenticated_key} <- Projects.authenticate_api_key(api_key) do
      conn
      |> assign(:api_key, authenticated_key)
      |> assign(:project, authenticated_key.project)
    else
      {:error, :missing_key} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Missing API key", message: "Please provide an API key via the X-PulseKit-Key header"})
        |> halt()

      {:error, :invalid_key} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid API key", message: "The provided API key is invalid or has been revoked"})
        |> halt()
    end
  end

  defp get_api_key_from_header(conn) do
    case get_req_header(conn, "x-pulsekit-key") do
      [key | _] -> {:ok, key}
      [] -> {:error, :missing_key}
    end
  end
end
