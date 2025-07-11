defmodule TodoAppWeb.TodoLiveTest do
  use TodoAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TodoApp.TodosFixtures

  @create_attrs %{priority: :low, status: :pending, description: "some description", title: "some title", project: "some project", due_date: "2025-07-08", completed_at: "2025-07-08T23:03:00Z", estimated_hours: 120.5, actual_hours: 120.5, is_urgent: true, is_recurring: true, tags: ["option1", "option2"], assigned_to: "some assigned_to", complexity: 42}
  @update_attrs %{priority: :medium, status: :in_progress, description: "some updated description", title: "some updated title", project: "some updated project", due_date: "2025-07-09", completed_at: "2025-07-09T23:03:00Z", estimated_hours: 456.7, actual_hours: 456.7, is_urgent: false, is_recurring: false, tags: ["option1"], assigned_to: "some updated assigned_to", complexity: 43}
  @invalid_attrs %{priority: nil, status: nil, description: nil, title: nil, project: nil, due_date: nil, completed_at: nil, estimated_hours: nil, actual_hours: nil, is_urgent: false, is_recurring: false, tags: [], assigned_to: nil, complexity: nil}

  defp create_todo(_) do
    todo = todo_fixture()
    %{todo: todo}
  end

  describe "Index" do
    setup [:create_todo]

    test "lists all todos", %{conn: conn, todo: todo} do
      {:ok, _index_live, html} = live(conn, ~p"/todos")

      assert html =~ "Listing Todos"
      assert html =~ todo.description
    end

    test "saves new todo", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/todos")

      assert index_live |> element("a", "New Todo") |> render_click() =~
               "New Todo"

      assert_patch(index_live, ~p"/todos/new")

      assert index_live
             |> form("#todo-form", todo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#todo-form", todo: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/todos")

      html = render(index_live)
      assert html =~ "Todo created successfully"
      assert html =~ "some description"
    end

    test "updates todo in listing", %{conn: conn, todo: todo} do
      {:ok, index_live, _html} = live(conn, ~p"/todos")

      assert index_live |> element("#todos-#{todo.id} a", "Edit") |> render_click() =~
               "Edit Todo"

      assert_patch(index_live, ~p"/todos/#{todo}/edit")

      assert index_live
             |> form("#todo-form", todo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#todo-form", todo: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/todos")

      html = render(index_live)
      assert html =~ "Todo updated successfully"
      assert html =~ "some updated description"
    end

    test "deletes todo in listing", %{conn: conn, todo: todo} do
      {:ok, index_live, _html} = live(conn, ~p"/todos")

      assert index_live |> element("#todos-#{todo.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#todos-#{todo.id}")
    end
  end

  describe "Show" do
    setup [:create_todo]

    test "displays todo", %{conn: conn, todo: todo} do
      {:ok, _show_live, html} = live(conn, ~p"/todos/#{todo}")

      assert html =~ "Show Todo"
      assert html =~ todo.description
    end

    test "updates todo within modal", %{conn: conn, todo: todo} do
      {:ok, show_live, _html} = live(conn, ~p"/todos/#{todo}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Todo"

      assert_patch(show_live, ~p"/todos/#{todo}/show/edit")

      assert show_live
             |> form("#todo-form", todo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#todo-form", todo: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/todos/#{todo}")

      html = render(show_live)
      assert html =~ "Todo updated successfully"
      assert html =~ "some updated description"
    end
  end
end
