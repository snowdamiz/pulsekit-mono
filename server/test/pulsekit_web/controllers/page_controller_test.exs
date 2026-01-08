defmodule PulsekitWeb.PageControllerTest do
  use PulsekitWeb.ConnCase

  test "GET / redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == "/login"
  end

  test "GET /login renders the login page", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Sign in"
  end
end
