defmodule TodoAppWeb.PageControllerTest do
  use TodoAppWeb.ConnCase

  test "GET / redirects to /todos", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/todos"
  end
end
