# Simple seed script without module definitions
alias TodoApp.Repo
alias TodoApp.Todos.Todo
import Ecto.Query

# Clear existing todos
Repo.delete_all(Todo)

# Today is July 9, 2025
today = ~D[2025-07-09]
now = ~U[2025-07-09 14:30:00Z]

# Define all possible values
priorities = [:low, :medium, :high]
statuses = [:pending, :in_progress, :completed, :archived]
assignees = ["john_doe", "jane_smith", "bob_johnson", "alice_williams", "charlie_brown"]
projects = ["project_alpha", "project_beta", "project_gamma", "internal_tools", "client_work"]
all_tags = ["bug", "feature", "enhancement", "documentation", "testing", "refactoring", "ui", "backend", "urgent", "blocked"]

# Generate todos
todos_data = []

# 1. Urgent tasks due today (5 todos)
for i <- 1..5 do
  todo = %{
    title: "Urgent: Fix critical issue ##{i}",
    description: "Critical production issue that needs immediate attention",
    priority: :high,
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
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 2. Overdue tasks (10 todos)
for _ <- 1..10 do
  days_overdue = :rand.uniform(30)
  todo = %{
    title: "Overdue: #{Enum.random(["Update", "Fix", "Implement"])} #{Enum.random(["API", "UI", "database"])}",
    description: "This task is #{days_overdue} days overdue and needs attention",
    priority: Enum.random(priorities),
    status: Enum.random([:pending, :in_progress]),
    due_date: Date.add(today, -days_overdue),
    estimated_hours: Float.round(:rand.uniform() * 40, 1),
    is_urgent: days_overdue > 14,
    is_recurring: false,
    tags: Enum.take_random(all_tags, :rand.uniform(3)),
    assigned_to: Enum.random(assignees ++ [nil]),
    project: Enum.random(projects),
    complexity: :rand.uniform(10)
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 3. Completed tasks from the past month (20 todos)
for _ <- 1..20 do
  days_ago_completed = :rand.uniform(30)
  estimated = Float.round(:rand.uniform() * 40, 1)
  actual = Float.round(estimated * (0.5 + :rand.uniform()), 1)
  
  todo = %{
    title: "Completed: #{Enum.random(["Built", "Fixed", "Deployed"])} #{Enum.random(["feature", "module", "service"])}",
    description: "Successfully completed task",
    priority: Enum.random(priorities),
    status: :completed,
    due_date: Date.add(today, -(days_ago_completed + 5)),
    completed_at: DateTime.add(now, -days_ago_completed * 24 * 60 * 60, :second),
    estimated_hours: estimated,
    actual_hours: actual,
    is_urgent: false,
    is_recurring: false,
    tags: Enum.take_random(all_tags, :rand.uniform(4)),
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: :rand.uniform(10)
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 4. In-progress tasks (15 todos)
for _ <- 1..15 do
  estimated = Float.round(10.0 + :rand.uniform() * 40, 1)
  progress_percent = :rand.uniform(80)
  actual = Float.round(estimated * progress_percent / 100, 1)
  
  todo = %{
    title: "WIP: #{Enum.random(["Developing", "Refactoring", "Optimizing"])} #{Enum.random(["auth system", "payment gateway", "search"])}",
    description: "Currently #{progress_percent}% complete",
    priority: Enum.random(priorities),
    status: :in_progress,
    due_date: Date.add(today, :rand.uniform(14)),
    estimated_hours: estimated,
    actual_hours: actual,
    is_urgent: false,
    is_recurring: false,
    tags: Enum.take_random(all_tags, :rand.uniform(5)),
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: :rand.uniform(10)
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 5. Future tasks (25 todos)
for _ <- 1..25 do
  days_future = 5 + :rand.uniform(60)
  todo = %{
    title: "Future: #{Enum.random(["Plan", "Design", "Implement"])} #{Enum.random(["new feature", "architecture", "integration"])}",
    description: "Scheduled for future sprint",
    priority: Enum.random(priorities),
    status: :pending,
    due_date: Date.add(today, days_future),
    estimated_hours: Float.round(:rand.uniform() * 40, 1),
    is_urgent: false,
    is_recurring: false,
    tags: Enum.take_random(all_tags, :rand.uniform(5)),
    assigned_to: if(:rand.uniform(100) > 30, do: Enum.random(assignees), else: nil),
    project: Enum.random(projects),
    complexity: :rand.uniform(10)
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 6. Recurring tasks (10 todos)
recurring_types = [
  {"Daily standup", 1, 0.5},
  {"Weekly code review", 7, 2.0},
  {"Monthly security audit", 30, 8.0}
]

for {title_prefix, interval, hours} <- recurring_types do
  for i <- 1..3 do
    todo = %{
      title: "#{title_prefix} - #{Enum.random(["Team A", "Team B", "Platform"])}",
      description: "Regular #{String.downcase(title_prefix)} meeting/task",
      priority: if(String.contains?(title_prefix, "security"), do: :high, else: :medium),
      status: Enum.random([:pending, :completed]),
      due_date: Date.add(today, rem(i * interval, 31)),
      completed_at: if(i == 1, do: DateTime.add(now, -interval * 24 * 60 * 60, :second), else: nil),
      estimated_hours: hours,
      actual_hours: if(i == 1, do: hours, else: nil),
      is_urgent: false,
      is_recurring: true,
      tags: ["recurring"],
      assigned_to: Enum.random(assignees),
      project: "internal_tools",
      complexity: 2
    }
    
    %Todo{}
    |> Todo.changeset(todo)
    |> Repo.insert!()
  end
end

# 7. Bug fixes (15 todos)
for i <- 1..15 do
  severity = Enum.random(["Critical", "Major", "Minor"])
  todo = %{
    title: "Bug: #{severity} - #{Enum.random(["Memory leak", "UI glitch", "API error"])}",
    description: "Bug report #{1000 + i}",
    priority: if(severity in ["Critical", "Major"], do: :high, else: Enum.random([:medium, :low])),
    status: Enum.random([:pending, :in_progress, :completed]),
    due_date: if(severity == "Critical", do: today, else: Date.add(today, :rand.uniform(7))),
    estimated_hours: Float.round(0.5 + :rand.uniform() * 10, 1),
    is_urgent: severity == "Critical",
    is_recurring: false,
    tags: ["bug", String.downcase(severity)],
    assigned_to: Enum.random(assignees),
    project: Enum.random(projects),
    complexity: if(severity == "Critical", do: 8, else: :rand.uniform(6))
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# 8. Feature requests (10 todos)
for _ <- 1..10 do
  todo = %{
    title: "Feature: #{Enum.random(["Add", "Implement"])} #{Enum.random(["dark mode", "export", "real-time updates", "API v2"])}",
    description: "User requested feature",
    priority: Enum.random(priorities),
    status: :pending,
    due_date: Date.add(today, 14 + :rand.uniform(45)),
    estimated_hours: Float.round(8.0 + :rand.uniform() * 32, 1),
    is_urgent: false,
    is_recurring: false,
    tags: ["feature", "enhancement"],
    assigned_to: nil,
    project: Enum.random(projects),
    complexity: 3 + :rand.uniform(5)
  }
  
  %Todo{}
  |> Todo.changeset(todo)
  |> Repo.insert!()
end

# Print summary
todo_count = Repo.aggregate(Todo, :count)
IO.puts("\nSeeding completed! Database now contains #{todo_count} todos.")

# Print distribution
IO.puts("\nTodo distribution:")
IO.puts("By status:")
for status <- statuses do
  count = Repo.aggregate(from(t in Todo, where: t.status == ^status), :count)
  IO.puts("  #{status}: #{count}")
end

IO.puts("\nBy priority:")
for priority <- priorities do
  count = Repo.aggregate(from(t in Todo, where: t.priority == ^priority), :count)
  IO.puts("  #{priority}: #{count}")
end

urgent_count = Repo.aggregate(from(t in Todo, where: t.is_urgent == true), :count)
recurring_count = Repo.aggregate(from(t in Todo, where: t.is_recurring == true), :count)
IO.puts("\nSpecial flags:")
IO.puts("  Urgent: #{urgent_count}")
IO.puts("  Recurring: #{recurring_count}")