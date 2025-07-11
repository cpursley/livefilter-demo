defmodule TodoApp.TodosTest do
  use TodoApp.DataCase

  alias TodoApp.Todos

  describe "todos" do
    alias TodoApp.Todos.Todo

    import TodoApp.TodosFixtures

    @invalid_attrs %{priority: nil, status: nil, description: nil, title: nil, project: nil, due_date: nil, completed_at: nil, estimated_hours: nil, actual_hours: nil, is_urgent: nil, is_recurring: nil, tags: nil, assigned_to: nil, complexity: nil}

    test "list_todos/0 returns all todos" do
      todo = todo_fixture()
      assert Todos.list_todos() == [todo]
    end

    test "get_todo!/1 returns the todo with given id" do
      todo = todo_fixture()
      assert Todos.get_todo!(todo.id) == todo
    end

    test "create_todo/1 with valid data creates a todo" do
      valid_attrs = %{priority: :low, status: :pending, description: "some description", title: "some title", project: "some project", due_date: ~D[2025-07-08], completed_at: ~U[2025-07-08 23:03:00Z], estimated_hours: 120.5, actual_hours: 120.5, is_urgent: true, is_recurring: true, tags: ["option1", "option2"], assigned_to: "some assigned_to", complexity: 42}

      assert {:ok, %Todo{} = todo} = Todos.create_todo(valid_attrs)
      assert todo.priority == :low
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
      assert todo.complexity == 42
    end

    test "create_todo/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Todos.create_todo(@invalid_attrs)
    end

    test "update_todo/2 with valid data updates the todo" do
      todo = todo_fixture()
      update_attrs = %{priority: :medium, status: :in_progress, description: "some updated description", title: "some updated title", project: "some updated project", due_date: ~D[2025-07-09], completed_at: ~U[2025-07-09 23:03:00Z], estimated_hours: 456.7, actual_hours: 456.7, is_urgent: false, is_recurring: false, tags: ["option1"], assigned_to: "some updated assigned_to", complexity: 43}

      assert {:ok, %Todo{} = todo} = Todos.update_todo(todo, update_attrs)
      assert todo.priority == :medium
      assert todo.status == :in_progress
      assert todo.description == "some updated description"
      assert todo.title == "some updated title"
      assert todo.project == "some updated project"
      assert todo.due_date == ~D[2025-07-09]
      assert todo.completed_at == ~U[2025-07-09 23:03:00Z]
      assert todo.estimated_hours == 456.7
      assert todo.actual_hours == 456.7
      assert todo.is_urgent == false
      assert todo.is_recurring == false
      assert todo.tags == ["option1"]
      assert todo.assigned_to == "some updated assigned_to"
      assert todo.complexity == 43
    end

    test "update_todo/2 with invalid data returns error changeset" do
      todo = todo_fixture()
      assert {:error, %Ecto.Changeset{}} = Todos.update_todo(todo, @invalid_attrs)
      assert todo == Todos.get_todo!(todo.id)
    end

    test "delete_todo/1 deletes the todo" do
      todo = todo_fixture()
      assert {:ok, %Todo{}} = Todos.delete_todo(todo)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_todo!(todo.id) end
    end

    test "change_todo/1 returns a todo changeset" do
      todo = todo_fixture()
      assert %Ecto.Changeset{} = Todos.change_todo(todo)
    end
  end
end
