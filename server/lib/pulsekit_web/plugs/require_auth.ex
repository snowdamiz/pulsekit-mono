defmodule PulsekitWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug for requiring user authentication on browser routes.
  Redirects to login page if not authenticated.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Pulsekit.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      case Accounts.get_user(user_id) do
        nil ->
          conn
          |> clear_session()
          |> redirect_to_login()

        user ->
          assign(conn, :current_user, user)
      end
    else
      redirect_to_login(conn)
    end
  end

  defp redirect_to_login(conn) do
    conn
    |> put_flash(:error, "You must be logged in to access this page.")
    |> redirect(to: "/login")
    |> halt()
  end
end
