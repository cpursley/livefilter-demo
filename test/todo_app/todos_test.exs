defmodule TodoApp.TodosTest do
  use TodoApp.DataCase

  alias TodoApp.Todos

  describe "todos" do
    alias TodoApp.Todos.Todo

    import TodoApp.TodosFixtures

    test "list_todos/0 returns all todos" do
      todo = todo_fixture()
      assert Todos.list_todos() == [todo]
    end

    test "get_todo!/1 returns the todo with given id" do
      todo = todo_fixture()
      assert Todos.get_todo!(todo.id) == todo
    end

    test "create_todo/1 with valid data creates a todo" do
      valid_attrs = %{
        status: :pending,
        description: "some description",
        title: "some title",
        project: "some project",
        due_date: ~D[2025-07-08],
        completed_at: ~U[2025-07-08 23:03:00Z],
        estimated_hours: 120.5,
        actual_hours: 120.5,
        is_urgent: true,
        is_recurring: true,
        tags: ["option1", "option2"],
        assigned_to: "some assigned_to",
        complexity: 5
      }

      assert {:ok, %Todo{} = todo} = Todos.create_todo(valid_attrs)
      assert todo.status == :pending
      assert todo.description == "some description"
      assert todo.title == "some title"
      assert todo.project == "some project"
      assert todo.due_date == ~D[2025-07-08]
      assert todo.completed_at == ~U[2025-07-08 23:03:00Z]
      assert todo.estimated_hours == 120.5
      assert todo.actual_hours == 120.5
      assert todo.is_urgent == true
      assert todo.is_recurring == true
      assert todo.tags == ["option1", "option2"]
      assert todo.assigned_to == "some assigned_to"
      assert todo.complexity == 5
    end

    test "create_todo/1 with invalid data returns error changeset" do
      invalid_attrs = %{
        status: nil,
        description: nil,
        title: nil,
        project: nil,
        due_date: nil,
        completed_at: nil,
        estimated_hours: nil,
        actual_hours: nil,
        is_urgent: nil,
        is_recurring: nil,
        tags: nil,
        assigned_to: nil,
        complexity: nil
      }

      assert {:error, %Ecto.Changeset{}} = Todos.create_todo(invalid_attrs)
    end

    test "list_todos_paginated/3 returns paginated todos" do
      # Create multiple todos
      for i <- 1..15 do
        todo_fixture(%{title: "Todo #{i}"})
      end

      result = Todos.list_todos_paginated(nil, nil, page: 1, per_page: 10)

      assert length(result.todos) == 10
      assert result.total_count == 15
      assert result.page == 1
      assert result.per_page == 10
      assert result.total_pages == 2
    end

    test "count_todos/1 returns total count" do
      todo_fixture(%{status: :pending})
      todo_fixture(%{status: :completed})
      todo_fixture(%{status: :pending})

      assert Todos.count_todos() == 3

      # With filter
      filter_group = %LiveFilter.FilterGroup{
        filters: [
          %LiveFilter.Filter{
            field: :status,
            operator: :equals,
            value: :pending,
            type: :enum
          }
        ]
      }

      assert Todos.count_todos(filter_group) == 2
    end

    test "count_by_status/1 returns status counts" do
      todo_fixture(%{status: :pending})
      todo_fixture(%{status: :completed})
      todo_fixture(%{status: :pending})
      todo_fixture(%{status: :in_progress})

      counts = Todos.count_by_status()

      assert counts[:pending] == 2
      assert counts[:completed] == 1
      assert counts[:in_progress] == 1
    end
  end
end
