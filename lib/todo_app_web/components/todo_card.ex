defmodule TodoAppWeb.Components.TodoCard do
  @moduledoc """
  Mobile-friendly card component for displaying todo items.
  """
  use TodoAppUi, :component

  import TodoAppUi.Card
  import TodoAppUi.Badge
  import TodoAppUi.Avatar
  import TodoAppUi.Icon

  import TodoAppWeb.TodoLive.Index,
    only: [format_assignee_name: 1, format_project_name: 1, format_date: 1, status_variant: 1]

  @doc """
  Renders a todo item as a card for mobile display.

  ## Examples:

      <.todo_card todo={@todo} phx-click="show" phx-value-id={@todo.id} />
  """
  attr :todo, :map, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def todo_card(assigns) do
    ~H"""
    <.card class={classes(["cursor-pointer hover:shadow-md transition-shadow", @class])} {@rest}>
      <.card_header class="pb-3">
        <div class="space-y-2">
          <%!-- Title and urgent indicator --%>
          <div class="flex items-start gap-2">
            <%= if @todo.is_urgent do %>
              <.icon
                name="hero-exclamation-triangle"
                class="h-4 w-4 text-destructive mt-0.5 shrink-0"
              />
            <% end %>
            <.card_title class="text-lg leading-tight">
              {@todo.title}
            </.card_title>
          </div>

          <%!-- Status badge below title --%>
          <div>
            <.badge variant={status_variant(@todo.status)} class="text-xs">
              {Phoenix.Naming.humanize(@todo.status)}
            </.badge>
          </div>

          <%!-- Description if present --%>
          <%= if @todo.description do %>
            <.card_description class="line-clamp-2">
              {@todo.description}
            </.card_description>
          <% end %>
        </div>
      </.card_header>

      <.card_content class="space-y-3">
        <%!-- Assignee and Due Date Row --%>
        <div class="flex items-center justify-between text-sm">
          <div class="flex items-center gap-2">
            <%= if @todo.assigned_to do %>
              <.avatar class="h-6 w-6">
                <.avatar_fallback class="text-xs">
                  {initials(@todo.assigned_to)}
                </.avatar_fallback>
              </.avatar>
              <span class="text-muted-foreground">{format_assignee_name(@todo.assigned_to)}</span>
            <% else %>
              <span class="text-muted-foreground">Unassigned</span>
            <% end %>
          </div>

          <%= if @todo.due_date do %>
            <div class={["flex items-center gap-1", due_date_class(@todo.due_date)]}>
              <.icon name="hero-calendar" class="h-3.5 w-3.5" />
              <span class="text-xs">{format_date(@todo.due_date)}</span>
            </div>
          <% end %>
        </div>

        <%!-- Tags Row --%>
        <%= if @todo.tags && length(@todo.tags) > 0 do %>
          <div class="flex flex-wrap gap-1">
            <%= for tag <- Enum.take(@todo.tags, 3) do %>
              <.badge variant="secondary" class="text-xs px-2 py-0.5">
                {tag}
              </.badge>
            <% end %>
            <%= if length(@todo.tags) > 3 do %>
              <span class="text-xs text-muted-foreground">+{length(@todo.tags) - 3} more</span>
            <% end %>
          </div>
        <% end %>

        <%!-- Additional Info Row --%>
        <div class="flex items-center justify-between text-xs text-muted-foreground">
          <%= if @todo.project do %>
            <span class="flex items-center gap-1">
              <.icon name="hero-folder" class="h-3 w-3" />
              {format_project_name(@todo.project)}
            </span>
          <% else %>
            <span></span>
          <% end %>

          <div class="flex items-center gap-3">
            <%= if @todo.estimated_hours do %>
              <span title="Estimated hours">
                {@todo.estimated_hours}h est.
              </span>
            <% end %>
            <%= if @todo.complexity do %>
              <span title="Complexity">
                {complexity_label(@todo.complexity)}
              </span>
            <% end %>
          </div>
        </div>
      </.card_content>
    </.card>
    """
  end

  defp initials(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp due_date_class(due_date) do
    today = Date.utc_today()

    cond do
      Date.compare(due_date, today) == :lt -> "text-destructive"
      Date.diff(due_date, today) <= 3 -> "text-warning"
      true -> "text-muted-foreground"
    end
  end

  defp complexity_label(1), do: "Low"
  defp complexity_label(2), do: "Medium"
  defp complexity_label(3), do: "High"
  defp complexity_label(_), do: "Unknown"
end
