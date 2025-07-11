defmodule TodoApp.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TodoApp.Todos` context.
  """

  @doc """
  Generate a todo.
  """
  def todo_fixture(attrs \\ %{}) do
    {:ok, todo} =
      attrs
      |> Enum.into(%{
        actual_hours: 120.5,
        assigned_to: "some assigned_to",
        completed_at: ~U[2025-07-08 23:03:00Z],
        complexity: 5,
        description: "some description",
        due_date: ~D[2025-07-08],
        estimated_hours: 120.5,
        is_recurring: true,
        is_urgent: true,
        priority: :low,
        project: "some project",
        status: :pending,
        tags: ["option1", "option2"],
        title: "some title"
      })
      |> TodoApp.Todos.create_todo()

    todo
  end

  @doc """
  Generate multiple todos with varied attributes for filter testing.
  """
  def create_todos_for_filters(opts \\ []) do
    count = Keyword.get(opts, :count, 10)

    # Define variations for each attribute
    statuses = [:pending, :in_progress, :completed, :archived]
    assignees = ["john_doe", "jane_smith", "bob_wilson", "alice_johnson", nil]

    projects = [
      "website_redesign",
      "mobile_app",
      "api_development",
      "data_migration",
      "documentation"
    ]

    tags_options = [
      ["urgent", "bug"],
      ["feature", "enhancement"],
      ["documentation"],
      ["testing", "qa"],
      ["refactoring"],
      []
    ]

    priorities = [:low, :medium, :high, :critical]

    # Generate todos with varied attributes
    Enum.map(1..count, fn i ->
      todo_fixture(%{
        title:
          "Todo ##{i} - #{Enum.random(["Fix", "Implement", "Review", "Test", "Document"])} #{Enum.random(["feature", "bug", "issue", "module", "component"])}",
        description:
          "Description for todo ##{i}. This is a #{Enum.random(["detailed", "brief", "comprehensive"])} description.",
        status: Enum.at(statuses, rem(i, length(statuses))),
        assigned_to: Enum.at(assignees, rem(i, length(assignees))),
        project: Enum.at(projects, rem(i, length(projects))),
        due_date: Date.add(Date.utc_today(), i - div(count, 2)),
        priority: Enum.at(priorities, rem(i, length(priorities))),
        tags: Enum.at(tags_options, rem(i, length(tags_options))),
        is_urgent: rem(i, 3) == 0,
        is_recurring: rem(i, 5) == 0,
        estimated_hours: :rand.uniform() * 40,
        actual_hours:
          if(Enum.at(statuses, rem(i, length(statuses))) == :completed,
            do: :rand.uniform() * 50,
            else: nil
          ),
        complexity: rem(i, 10) + 1,
        completed_at:
          if(Enum.at(statuses, rem(i, length(statuses))) == :completed,
            do: DateTime.utc_now(),
            else: nil
          )
      })
    end)
  end

  @doc """
  Create todos with specific filter criteria for testing.
  """
  def create_todos_matching_filter(filter_criteria, count \\ 5) do
    base_attrs = build_attrs_from_filter(filter_criteria)

    Enum.map(1..count, fn i ->
      todo_fixture(
        Map.merge(base_attrs, %{
          title: "#{base_attrs[:title] || "Filtered todo"} ##{i}"
        })
      )
    end)
  end

  @doc """
  Create todos for date range testing.
  """
  def create_todos_with_date_ranges do
    today = Date.utc_today()

    [
      # Overdue
      todo_fixture(%{title: "Overdue task 1", due_date: Date.add(today, -7), status: :pending}),
      todo_fixture(%{title: "Overdue task 2", due_date: Date.add(today, -3), status: :pending}),

      # Due today
      todo_fixture(%{title: "Due today 1", due_date: today, status: :pending}),
      todo_fixture(%{title: "Due today 2", due_date: today, status: :in_progress}),

      # Due this week
      todo_fixture(%{title: "Due this week 1", due_date: Date.add(today, 2), status: :pending}),
      todo_fixture(%{title: "Due this week 2", due_date: Date.add(today, 5), status: :pending}),

      # Due next month
      todo_fixture(%{title: "Due next month 1", due_date: Date.add(today, 35), status: :pending}),
      todo_fixture(%{title: "Due next month 2", due_date: Date.add(today, 40), status: :pending}),

      # No due date
      todo_fixture(%{title: "No due date", due_date: nil, status: :pending})
    ]
  end

  @doc """
  Create todos for search testing.
  """
  def create_todos_for_search do
    [
      todo_fixture(%{
        title: "Fix critical bug in authentication",
        description: "Users cannot login with special characters in password"
      }),
      todo_fixture(%{
        title: "Implement new dashboard",
        description: "Create analytics dashboard with real-time updates"
      }),
      todo_fixture(%{
        title: "Review pull request #123",
        description: "Fix for memory leak in background jobs"
      }),
      todo_fixture(%{
        title: "Update documentation",
        description: "Add examples for new authentication API"
      }),
      todo_fixture(%{
        title: "Urgent: Security patch",
        description: "Critical vulnerability in dependency needs immediate fix"
      })
    ]
  end

  @doc """
  Create a comprehensive test dataset.
  """
  def create_comprehensive_test_data do
    # Create varied todos
    varied_todos = create_todos_for_filters(count: 30)

    # Create date-specific todos
    date_todos = create_todos_with_date_ranges()

    # Create search-specific todos
    search_todos = create_todos_for_search()

    # Create todos for complex filter scenarios
    complex_todos = [
      # John Doe's urgent pending tasks
      todo_fixture(%{
        title: "John's urgent bug fix",
        assigned_to: "john_doe",
        is_urgent: true,
        status: :pending,
        tags: ["bug", "urgent"]
      }),

      # Completed tasks with tags
      todo_fixture(%{
        title: "Completed feature with tags",
        status: :completed,
        tags: ["feature", "enhancement"],
        completed_at: DateTime.utc_now()
      }),

      # High complexity in-progress tasks
      todo_fixture(%{
        title: "Complex refactoring",
        status: :in_progress,
        complexity: 10,
        estimated_hours: 40.0,
        tags: ["refactoring"]
      })
    ]

    varied_todos ++ date_todos ++ search_todos ++ complex_todos
  end

  # Private functions

  defp build_attrs_from_filter(criteria) do
    Enum.reduce(criteria, %{}, fn {field, value}, acc ->
      Map.put(acc, field, value)
    end)
  end
end
