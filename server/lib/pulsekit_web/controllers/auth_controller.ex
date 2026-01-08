defmodule PulsekitWeb.AuthController do
  use PulsekitWeb, :controller

  alias Pulsekit.Accounts

  @doc """
  Handles the login callback from LiveView.
  Sets the session and redirects to the home page.
  """
  def callback(conn, %{"user_id" => user_id}) do
    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "Authentication failed.")
        |> redirect(to: ~p"/login")

      _user ->
        conn
        |> put_session(:user_id, user_id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/")
    end
  end

  @doc """
  Logs out the current user.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> configure_session(renew: true)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/login")
  end
end
