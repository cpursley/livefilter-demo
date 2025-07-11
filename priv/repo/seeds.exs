# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TodoApp.Repo.insert!(%TodoApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TodoApp.Repo
alias TodoApp.Todos.Todo
import Ecto.Query

# Clear existing todos
Repo.delete_all(Todo)

# Today is July 9, 2025
today = ~D[2025-07-09]
now = ~U[2025-07-09 14:30:00Z]

# Helper functions
days_ago = fn date, days -> Date.add(date, -days) end
days_from_now = fn date, days -> Date.add(date, days) end

datetime_days_ago = fn datetime, days ->
  DateTime.add(datetime, -days * 24 * 60 * 60, :second)
end

random_tags = fn available_tags, max ->
  count = :rand.uniform(max)
  Enum.take_random(available_tags, count)
end

random_hours = fn -> :rand.uniform() * 40 end
random_complexity = fn -> :rand.uniform(10) end

# Define all possible values
statuses = [:pending, :in_progress, :completed, :archived]
assignees = ["john_doe", "jane_smith", "bob_johnson", "alice_williams", "charlie_brown"]
projects = ["project_alpha", "project_beta", "project_gamma", "internal_tools", "client_work"]
all_tags = ["bug", "feature", "enhancement", "documentation", "testing", "refactoring", "ui", "backend", "urgent", "blocked"]

# Generate diverse todos
todos = []

# 1. Urgent tasks due today (5 todos)
todos = todos ++ Enum.map(1..5, fn i ->
  %{
    title: "Urgent: Fix critical issue ##{i}",
    description: "Critical production issue that needs immediate attention - affecting users in #{Enum.random(["payment", "authentication", "data processing", "API", "UI rendering"])}",
    status: Enum.random([:pending, :in_progress]),
    due_date: today,
    estimated_hours: Float.round(2.0 + :rand.uniform() * 4, 1),
    actual_hours: if(i <= 2, do: Float.round(1.0 + :rand.uniform() * 3, 1), else: nil),
    is_urgent: true,
    is_recurring: false,
    tags: ["urgent", "bug", Enum.random(["backend", "ui"])],
    assigned_to: Enum.random(assignees),
    project: "project_alpha",
    complexity: 7 + :rand.uniform(3)
  }
end)

# 2. Overdue tasks (10 todos)
todos = todos ++ Enum.map(1..10, fn i ->
  days_overdue = :rand.uniform(30)
  %{
    title: "Overdue: #{Enum.random(["Update", "Fix", "Implement", "Review", "Deploy"])} #{Enum.random(["API endpoint", "user interface", "database schema", "security patch", "documentation"])}",
    description: "This task is #{days_overdue} days overdue and needs attention",
    status: Enum.random([:pending, :in_progress]),
    due_date: days_ago.(today, days_overdue),
    estimated_hours: Float.round(random_hours.(), 1),
    actual_hours: nil,
    is_urgent: days_overdue > 14,
    is_recurring: false,
    tags: random_tags.(all_tags, 3),
    assigned_to: Enum.random(assignees ++ [nil]),
    project: Enum.random(projects),
    complexity: random_complexity.()
  }
end)

# 3. Completed tasks from the past month (20 todos)
todos = todos ++ Enum.map(1..20, fn i ->
  days_ago_completed = :rand.uniform(30)
  estimated = Float.round(random_hours.(), 1)
  actual = Float.round(estimated * (0.5 + :rand.uniform()), 1)
  
  %{
    title: "Completed: #{Enum.random(["Built", "Fixed", "Deployed", "Tested", "Documented"])} #{Enum.random(["feature", "module", "service", "component", "integration"])} for #{Enum.random(["users", "admins", "API", "mobile app", "dashboard"])}",
    description: "Successfully completed task that improved system performance by #{:rand.uniform(50)}%",
    status: :completed,
    due_date: days_ago.(today, days_ago_completed - 5),
    completed_at: datetime_days_ago.(now, days_ago_completed),
    estimated_hours: estimated,
    actual_hours: actual,
    is_urgent: false,
    is_recurring: false,
    tags: random_tags.(all_tags, 4),
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: random_complexity.()
  }
end)

# 4. In-progress tasks (15 todos)
todos = todos ++ Enum.map(1..15, fn i ->
  estimated = Float.round(10.0 + random_hours.(), 1)
  progress_percent = :rand.uniform(80)
  actual = Float.round(estimated * progress_percent / 100, 1)
  
  %{
    title: "WIP: #{Enum.random(["Developing", "Refactoring", "Optimizing", "Migrating", "Integrating"])} #{Enum.random(["authentication system", "payment gateway", "search functionality", "reporting module", "notification service"])}",
    description: "Currently #{progress_percent}% complete. #{Enum.random(["Making good progress", "Some blockers encountered", "On track for deadline", "Ahead of schedule"])}",
    status: :in_progress,
    due_date: days_from_now.(today, :rand.uniform(14)),
    estimated_hours: estimated,
    actual_hours: actual,
    is_urgent: false,
    is_recurring: false,
    tags: random_tags.(all_tags, 3),
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: random_complexity.()
  }
end)

# 5. Future tasks (25 todos)
todos = todos ++ Enum.map(1..25, fn i ->
  days_future = 5 + :rand.uniform(60)
  %{
    title: "Future: #{Enum.random(["Plan", "Design", "Implement", "Research", "Evaluate"])} #{Enum.random(["new feature", "architecture", "integration", "migration", "optimization"])}",
    description: "Scheduled for future sprint. Requirements: #{Enum.random(["fully defined", "needs refinement", "waiting for dependencies", "approved by stakeholders"])}",
    status: :pending,
    due_date: days_from_now.(today, days_future),
    estimated_hours: Float.round(random_hours.(), 1),
    actual_hours: nil,
    is_urgent: false,
    is_recurring: false,
    tags: random_tags.(all_tags, 3),
    assigned_to: if(:rand.uniform(100) > 30, do: Enum.random(assignees), else: nil),
    project: Enum.random(projects),
    complexity: random_complexity.()
  }
end)

# 6. Recurring tasks (10 todos)
recurring_types = [
  {"Daily standup", 1, 0.5},
  {"Weekly code review", 7, 2.0},
  {"Bi-weekly sprint planning", 14, 3.0},
  {"Monthly security audit", 30, 8.0},
  {"Quarterly performance review", 90, 4.0}
]

todos = todos ++ Enum.flat_map(recurring_types, fn {title_prefix, interval, hours} ->
  Enum.map(1..2, fn i ->
    %{
      title: "#{title_prefix} - #{Enum.random(["Team A", "Team B", "Platform", "Mobile", "Backend"])}",
      description: "Regular #{String.downcase(title_prefix)} meeting/task",
      status: Enum.random([:pending, :completed]),
      due_date: days_from_now.(today, rem(i * interval, 31)),
      completed_at: if(i == 1, do: datetime_days_ago.(now, interval), else: nil),
      estimated_hours: hours,
      actual_hours: if(i == 1, do: hours, else: nil),
      is_urgent: false,
      is_recurring: true,
      tags: ["recurring", Enum.random(["meeting", "review", "audit"])],
      assigned_to: Enum.random(assignees),
      project: "internal_tools",
      complexity: 2
    }
  end)
end)

# 7. Archived old tasks (10 todos)
todos = todos ++ Enum.map(1..10, fn i ->
  %{
    title: "Archived: Legacy #{Enum.random(["system", "feature", "module", "service"])} #{Enum.random(["migration", "deprecation", "removal", "update"])}",
    description: "Archived task from previous quarters. No longer relevant.",
    status: :archived,
    due_date: days_ago.(today, 60 + :rand.uniform(120)),
    estimated_hours: Float.round(random_hours.(), 1),
    actual_hours: nil,
    is_urgent: false,
    is_recurring: false,
    tags: ["archived", Enum.random(["legacy", "deprecated"])],
    assigned_to: Enum.random(assignees ++ [nil]),
    project: Enum.random(projects),
    complexity: random_complexity.()
  }
end)

# 8. High complexity tasks (10 todos)
todos = todos ++ Enum.map(1..10, fn i ->
  %{
    title: "Complex: #{Enum.random(["Architect", "Redesign", "Rewrite", "Scale", "Optimize"])} #{Enum.random(["distributed system", "data pipeline", "microservices", "infrastructure", "algorithm"])}",
    description: "High complexity task requiring senior developer expertise and careful planning",
    status: Enum.random([:pending, :in_progress]),
    due_date: days_from_now.(today, 30 + :rand.uniform(30)),
    estimated_hours: Float.round(40.0 + random_hours.(), 1),
    actual_hours: if(Enum.random([true, false]), do: Float.round(random_hours.(), 1), else: nil),
    is_urgent: false,
    is_recurring: false,
    tags: ["complex", "architecture"] ++ random_tags.(all_tags, 2),
    assigned_to: Enum.random(["john_doe", "jane_smith"]), # Senior devs
    project: Enum.random(["project_alpha", "project_beta"]),
    complexity: 8 + :rand.uniform(2)
  }
end)

# 9. Bug fixes (15 todos)
todos = todos ++ Enum.map(1..15, fn i ->
  severity = Enum.random(["Critical", "Major", "Minor", "Trivial"])
  %{
    title: "Bug: #{severity} - #{Enum.random(["Memory leak", "UI glitch", "API error", "Data inconsistency", "Performance issue"])} in #{Enum.random(["production", "staging", "development"])}",
    description: "Bug report #{1000 + i}. Steps to reproduce included. Affects #{:rand.uniform(1000)} users.",
    status: Enum.random([:pending, :in_progress, :completed]),
    due_date: if(severity == "Critical", do: today, else: days_from_now.(today, :rand.uniform(7))),
    estimated_hours: Float.round(0.5 + random_hours.() / 4, 1),
    actual_hours: if(Enum.random([true, false]), do: Float.round(random_hours.() / 4, 1), else: nil),
    is_urgent: severity == "Critical",
    is_recurring: false,
    tags: ["bug", severity |> String.downcase()] ++ random_tags.(["backend", "ui", "testing"], 1),
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: case severity do
      "Critical" -> 7 + :rand.uniform(3)
      "Major" -> 5 + :rand.uniform(3)
      _ -> 1 + :rand.uniform(4)
    end
  }
end)

# 10. Feature requests (10 todos)
todos = todos ++ Enum.map(1..10, fn i ->
  %{
    title: "Feature: #{Enum.random(["Add", "Implement", "Create", "Build"])} #{Enum.random(["dark mode", "export functionality", "real-time updates", "mobile app", "API versioning", "webhooks", "2FA", "audit logs"])}",
    description: "User requested feature with #{10 + :rand.uniform(90)} upvotes. Business value: #{Enum.random(["High", "Medium", "Low"])}",
    status: :pending,
    due_date: days_from_now.(today, 14 + :rand.uniform(45)),
    estimated_hours: Float.round(8.0 + random_hours.(), 1),
    actual_hours: nil,
    is_urgent: false,
    is_recurring: false,
    tags: ["feature", "enhancement"] ++ random_tags.(all_tags, 2),
    assigned_to: nil, # Unassigned feature requests
    project: Enum.random(projects),
    complexity: 3 + :rand.uniform(5)
  }
end)

# Insert all todos with error handling
IO.puts("Seeding #{length(todos)} todos...")

Enum.each(todos, fn todo_attrs ->
  case %Todo{}
       |> Todo.changeset(todo_attrs)
       |> Repo.insert() do
    {:ok, _todo} ->
      # Success, continue
      :ok
    {:error, changeset} ->
      IO.puts("Failed to insert todo: #{inspect(todo_attrs)}")
      IO.puts("Errors: #{inspect(changeset.errors)}")
  end
end)

# Print summary statistics
todo_count = Repo.aggregate(Todo, :count)
IO.puts("\nSeeding completed! Database now contains #{todo_count} todos.")

# Print distribution statistics
IO.puts("\nTodo distribution:")
IO.puts("By status:")
Enum.each(statuses, fn status ->
  count = Repo.aggregate(from(t in Todo, where: t.status == ^status), :count)
  IO.puts("  #{status}: #{count}")
end)


IO.puts("\nBy assignee:")
Enum.each(assignees, fn assignee ->
  count = Repo.aggregate(from(t in Todo, where: t.assigned_to == ^assignee), :count)
  IO.puts("  #{assignee}: #{count}")
end)
unassigned_count = Repo.aggregate(from(t in Todo, where: is_nil(t.assigned_to)), :count)
IO.puts("  unassigned: #{unassigned_count}")

urgent_count = Repo.aggregate(from(t in Todo, where: t.is_urgent == true), :count)
recurring_count = Repo.aggregate(from(t in Todo, where: t.is_recurring == true), :count)
IO.puts("\nSpecial flags:")
IO.puts("  Urgent: #{urgent_count}")
IO.puts("  Recurring: #{recurring_count}")