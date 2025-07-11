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
        complexity: 42,
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
end
