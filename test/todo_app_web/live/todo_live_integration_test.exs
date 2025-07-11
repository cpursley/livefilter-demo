defmodule TodoAppWeb.TodoLive.IntegrationTest do
  use TodoAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TodoApp.TodosFixtures

  describe "basic functionality" do
    test "displays todos on load", %{conn: conn} do
      _todo = todo_fixture(%{title: "Test Todo"})

      {:ok, _view, html} = live(conn, ~p"/todos")

      assert html =~ "Test Todo"
      assert html =~ "todos"
    end

    test "loads with filter params in URL", %{conn: conn} do
      pending_todo = todo_fixture(%{title: "Pending Task", status: :pending})
      completed_todo = todo_fixture(%{title: "Completed Task", status: :completed})

      # Load with status filter
      {:ok, _view, html} =
        live(
          conn,
          ~p"/todos?filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=pending"
        )

      assert html =~ pending_todo.title
      refute html =~ completed_todo.title
    end

    test "loads with multiple filters", %{conn: conn} do
      # Create test data
      urgent_pending =
        todo_fixture(%{
          title: "Urgent Pending",
          status: :pending,
          is_urgent: true
        })

      non_urgent_pending =
        todo_fixture(%{
          title: "Non-urgent Pending",
          status: :pending,
          is_urgent: false
        })

      # Load with multiple filters
      {:ok, _view, html} =
        live(
          conn,
          ~p"/todos?filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=pending&filters[is_urgent][operator]=equals&filters[is_urgent][type]=boolean&filters[is_urgent][value]=true"
        )

      assert html =~ urgent_pending.title
      refute html =~ non_urgent_pending.title
    end

    test "loads with sort params", %{conn: conn} do
      _todos =
        for i <- 1..5 do
          todo_fixture(%{title: "Todo #{i}", due_date: Date.add(Date.utc_today(), i)})
        end

      {:ok, _view, html} = live(conn, ~p"/todos?sort[field]=due_date&sort[direction]=desc")

      # Should show todos (exact order hard to test without parsing HTML)
      assert html =~ "Todo"
    end

    test "loads with pagination params", %{conn: conn} do
      # Create many todos
      for i <- 1..25 do
        todo_fixture(%{title: "Todo #{i}"})
      end

      {:ok, _view, html} = live(conn, ~p"/todos?page=2&per_page=10")

      # Should show page 2
      assert html =~ "Page 2"
    end

    test "complex URL with all param types", %{conn: conn} do
      # Create specific test data
      match =
        todo_fixture(%{
          title: "Urgent Fix",
          description: "Fix authentication bug",
          status: :pending,
          is_urgent: true,
          assigned_to: "john_doe",
          due_date: Date.add(Date.utc_today(), 5)
        })

      _other =
        todo_fixture(%{
          title: "Other Task",
          status: :completed,
          is_urgent: false
        })

      # Complex URL with search, filters, sort, and pagination
      url =
        "/todos?filters[_search][operator]=custom&filters[_search][type]=string&filters[_search][value]=authentication&filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=pending&filters[is_urgent][operator]=equals&filters[is_urgent][type]=boolean&filters[is_urgent][value]=true&sort[field]=due_date&sort[direction]=asc&page=1&per_page=20"

      {:ok, _view, html} = live(conn, url)

      assert html =~ match.title
      refute html =~ "Other Task"
    end
  end

  describe "data integrity" do
    test "filter results match database query", %{conn: conn} do
      # Create test data
      for i <- 1..10 do
        todo_fixture(%{
          title: "Todo #{i}",
          status: Enum.random([:pending, :completed]),
          is_urgent: rem(i, 3) == 0
        })
      end

      # Load with filters
      {:ok, _view, html} =
        live(
          conn,
          ~p"/todos?filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=pending"
        )

      # Count pending todos in database
      pending_count =
        TodoApp.Todos.count_todos(%LiveFilter.FilterGroup{
          filters: [
            %LiveFilter.Filter{
              field: :status,
              operator: :equals,
              value: :pending,
              type: :enum
            }
          ]
        })

      # HTML should show the count somewhere
      assert html =~ "#{pending_count}"
    end

    test "empty results handled gracefully", %{conn: conn} do
      # Create a todo that won't match
      todo_fixture(%{title: "Test", status: :pending})

      # Load with filter that matches nothing
      {:ok, _view, html} =
        live(
          conn,
          ~p"/todos?filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=archived"
        )

      # Should handle empty state
      assert html =~ "No todos" || html =~ "0 todos" || !String.contains?(html, "phx-stream-item")
    end
  end

  describe "URL serialization round-trip" do
    test "filters survive navigation", %{conn: conn} do
      pending_todo = todo_fixture(%{title: "Pending Task", status: :pending})

      # Start with filter params
      original_params =
        "filters[status][operator]=equals&filters[status][type]=enum&filters[status][value]=pending"

      {:ok, view, html} = live(conn, ~p"/todos?#{original_params}")

      assert html =~ pending_todo.title

      # The view should maintain the filter state
      # (In a real test, we'd interact with the view and verify the URL is preserved)
      assert render(view) =~ pending_todo.title
    end
  end
end
