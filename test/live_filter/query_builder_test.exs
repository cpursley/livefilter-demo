defmodule LiveFilter.QueryBuilderTest do
  use TodoApp.DataCase, async: true

  alias LiveFilter.{Filter, FilterGroup, QueryBuilder, Sort}
  alias TodoApp.Todos.Todo
  alias TodoApp.Repo
  import TodoApp.TodosFixtures

  setup do
    # Create test data
    todo1 =
      todo_fixture(%{
        title: "Fix bug in authentication",
        description: "Critical security issue",
        status: :pending,
        is_urgent: true,
        assigned_to: "john_doe",
        due_date: ~D[2025-01-15],
        tags: ["bug", "security"],
        complexity: 8,
        estimated_hours: 16.0
      })

    todo2 =
      todo_fixture(%{
        title: "Implement new feature",
        description: "Dashboard analytics",
        status: :in_progress,
        is_urgent: false,
        assigned_to: "jane_smith",
        due_date: ~D[2025-02-01],
        tags: ["feature", "dashboard"],
        complexity: 5,
        estimated_hours: 24.0
      })

    todo3 =
      todo_fixture(%{
        title: "Update documentation",
        description: "API docs need updating",
        status: :completed,
        is_urgent: false,
        assigned_to: "john_doe",
        due_date: ~D[2025-01-10],
        tags: ["documentation"],
        complexity: 2,
        estimated_hours: 8.0,
        completed_at: DateTime.utc_now()
      })

    %{todos: [todo1, todo2, todo3]}
  end

  describe "string operators" do
    test "equals operator", %{todos: [todo1, _, _]} do
      filter = %Filter{
        field: :title,
        operator: :equals,
        value: "Fix bug in authentication",
        type: :string
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo1.id
    end

    test "contains operator", %{todos: [todo1, _todo2, _]} do
      filter = %Filter{field: :title, operator: :contains, value: "bug", type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo1.id
    end

    test "starts_with operator", %{todos: [_, todo2, _]} do
      filter = %Filter{field: :title, operator: :starts_with, value: "Implement", type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo2.id
    end

    test "ends_with operator", %{todos: [_, _, todo3]} do
      filter = %Filter{field: :title, operator: :ends_with, value: "documentation", type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo3.id
    end

    test "is_empty operator" do
      # Create a todo with empty description
      empty_todo = todo_fixture(%{description: ""})

      filter = %Filter{field: :description, operator: :is_empty, value: nil, type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == empty_todo.id end)
    end
  end

  describe "enum operators" do
    test "equals operator for single value", %{todos: [todo1, _, _]} do
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == todo1.id end)
      assert Enum.all?(result, fn todo -> todo.status == :pending end)
    end

    test "in operator for multiple values", %{todos: [todo1, todo2, _]} do
      filter = %Filter{
        field: :status,
        operator: :in,
        value: [:pending, :in_progress],
        type: :enum
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert todo1.id in ids
      assert todo2.id in ids
    end
  end

  describe "boolean operators" do
    test "is_true operator", %{todos: [todo1, _, _]} do
      filter = %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.all?(result, fn todo -> todo.is_urgent == true end)
      assert Enum.any?(result, fn todo -> todo.id == todo1.id end)
    end

    test "is_false operator", %{todos: [_, todo2, todo3]} do
      filter = %Filter{field: :is_urgent, operator: :is_false, value: false, type: :boolean}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.all?(result, fn todo -> todo.is_urgent == false end)
      ids = Enum.map(result, & &1.id)
      assert todo2.id in ids
      assert todo3.id in ids
    end

    test "equals operator for boolean", %{todos: [todo1, _, _]} do
      filter = %Filter{field: :is_urgent, operator: :equals, value: true, type: :boolean}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == todo1.id end)
    end
  end

  describe "date operators" do
    test "equals operator", %{todos: [todo1, _, _]} do
      filter = %Filter{field: :due_date, operator: :equals, value: ~D[2025-01-15], type: :date}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo1.id
    end

    test "before operator", %{todos: [_, _, todo3]} do
      filter = %Filter{field: :due_date, operator: :before, value: ~D[2025-01-12], type: :date}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == todo3.id end)
    end

    test "after operator", %{todos: [_, todo2, _]} do
      filter = %Filter{field: :due_date, operator: :after, value: ~D[2025-01-20], type: :date}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == todo2.id end)
    end

    test "between operator", %{todos: [todo1, _, todo3]} do
      filter = %Filter{
        field: :due_date,
        operator: :between,
        value: {~D[2025-01-01], ~D[2025-01-20]},
        type: :date
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert todo1.id in ids
      assert todo3.id in ids
    end
  end

  describe "numeric operators" do
    test "greater_than operator", %{todos: [todo1, _, _]} do
      filter = %Filter{field: :complexity, operator: :greater_than, value: 7, type: :integer}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.all?(result, fn todo -> todo.complexity > 7 end)
      assert Enum.any?(result, fn todo -> todo.id == todo1.id end)
    end

    test "less_than operator", %{todos: [_, _, todo3]} do
      filter = %Filter{field: :complexity, operator: :less_than, value: 3, type: :integer}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.all?(result, fn todo -> todo.complexity < 3 end)
      assert Enum.any?(result, fn todo -> todo.id == todo3.id end)
    end

    test "between operator for float", %{todos: [todo1, _, todo3]} do
      filter = %Filter{
        field: :estimated_hours,
        operator: :between,
        value: {5.0, 20.0},
        type: :float
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert todo1.id in ids
      assert todo3.id in ids
    end
  end

  describe "array operators" do
    test "contains_any operator", %{todos: [todo1, _, todo3]} do
      filter = %Filter{
        field: :tags,
        operator: :contains_any,
        value: ["bug", "documentation"],
        type: :array
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert todo1.id in ids
      assert todo3.id in ids
    end

    test "contains_all operator", %{todos: [todo1, _, _]} do
      filter = %Filter{
        field: :tags,
        operator: :contains_all,
        value: ["bug", "security"],
        type: :array
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo1.id
    end
  end

  describe "complex filter combinations" do
    test "multiple filters with AND", %{todos: [todo1, _, _]} do
      filters = [
        %Filter{field: :status, operator: :equals, value: :pending, type: :enum},
        %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
      ]

      filter_group = %FilterGroup{filters: filters, conjunction: :and}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == todo1.id
    end

    test "nested groups with mixed conjunctions", %{todos: [todo1, _, todo3]} do
      # (status = pending AND is_urgent = true) OR (assigned_to = john_doe AND status = completed)
      filter_group = %FilterGroup{
        conjunction: :or,
        groups: [
          %FilterGroup{
            conjunction: :and,
            filters: [
              %Filter{field: :status, operator: :equals, value: :pending, type: :enum},
              %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
            ]
          },
          %FilterGroup{
            conjunction: :and,
            filters: [
              %Filter{field: :assigned_to, operator: :equals, value: "john_doe", type: :string},
              %Filter{field: :status, operator: :equals, value: :completed, type: :enum}
            ]
          }
        ]
      }

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      # Should return todo1 (pending & urgent) and todo3 (john_doe & completed)
      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert todo1.id in ids
      assert todo3.id in ids
    end
  end

  describe "sorting" do
    test "single sort ascending", %{todos: _todos} do
      sort = %Sort{field: :due_date, direction: :asc}

      result =
        Todo
        |> QueryBuilder.apply_sort(sort)
        |> Repo.all()

      dates = Enum.map(result, & &1.due_date)
      assert dates == Enum.sort(dates, Date)
    end

    test "single sort descending", %{todos: _todos} do
      sort = %Sort{field: :complexity, direction: :desc}

      result =
        Todo
        |> QueryBuilder.apply_sort(sort)
        |> Repo.all()

      complexities = Enum.map(result, & &1.complexity)
      assert complexities == Enum.sort(complexities, :desc)
    end

    test "multiple sorts" do
      sorts = [
        %Sort{field: :status, direction: :asc},
        %Sort{field: :due_date, direction: :desc}
      ]

      result =
        Todo
        |> QueryBuilder.apply_sort(sorts)
        |> Repo.all()

      # Verify primary sort by status
      _statuses = Enum.map(result, & &1.status)
      grouped = Enum.group_by(result, & &1.status)

      # Within each status group, dates should be descending
      for {_status, group} <- grouped do
        dates = Enum.map(group, & &1.due_date)
        assert dates == Enum.sort(dates, {:desc, Date})
      end
    end
  end

  describe "edge cases" do
    test "empty filter group returns all records" do
      filter_group = %FilterGroup{}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      all_todos = Repo.all(Todo)
      assert length(result) == length(all_todos)
    end

    test "nil value handling" do
      # Create a todo with nil assigned_to
      nil_todo = todo_fixture(%{assigned_to: nil})

      filter = %Filter{field: :assigned_to, operator: :is_empty, value: nil, type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.any?(result, fn todo -> todo.id == nil_todo.id end)
    end

    test "invalid field name doesn't crash" do
      filter = %Filter{field: :nonexistent_field, operator: :equals, value: "test", type: :string}
      filter_group = %FilterGroup{filters: [filter]}

      assert_raise Ecto.QueryError, fn ->
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()
      end
    end
  end

  describe "datetime operators" do
    test "datetime filtering on completed_at", %{todos: [_, _, todo3]} do
      # Test that completed_at filtering works
      filter = %Filter{
        field: :completed_at,
        operator: :is_not_empty,
        value: nil,
        type: :datetime
      }

      filter_group = %FilterGroup{filters: [filter]}

      result =
        Todo
        |> QueryBuilder.build_query(filter_group)
        |> Repo.all()

      assert Enum.all?(result, fn todo -> not is_nil(todo.completed_at) end)
      assert Enum.any?(result, fn todo -> todo.id == todo3.id end)
    end
  end
end
