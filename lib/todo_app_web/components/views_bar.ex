defmodule TodoAppWeb.Components.ViewsBar do
  @moduledoc """
  Component for displaying and managing saved filter views.
  Renders a horizontal bar of view buttons similar to Linear's projects.
  """
  use Phoenix.Component
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.DropdownMenu

  @doc """
  Renders the views bar with saved filter views.
  """
  attr :views, :list, required: true, doc: "List of saved view maps"

  attr :current_query_string, :string,
    default: "",
    doc: "Current filter query string to highlight active view"

  attr :active_view, :any,
    default: :no_active_view,
    doc: "Currently active view (not used in rendering but passed from parent)"

  attr :on_apply, :string, default: "apply_view", doc: "Event to trigger when applying a view"
  attr :on_delete, :string, default: "delete_view", doc: "Event to trigger when deleting a view"
  attr :class, :string, default: nil

  def views_bar(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2 px-4 py-2 border-b overflow-x-auto",
      @class
    ]}>
      <%!-- Views label with icon --%>
      <div class="flex items-center gap-1.5 text-sm font-medium text-foreground">
        <.icon name="hero-square-3-stack-3d" class="h-4 w-4" />
        <span>Views</span>
      </div>

      <%!-- All badge (default view - no filters) --%>
      <div
        class={[
          "inline-flex items-center border py-0.5 text-sm transition-colors rounded-sm px-1.5 font-normal cursor-pointer",
          if @current_query_string == "" do
            "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80"
          else
            "border-transparent hover:bg-secondary/40"
          end
        ]}
        phx-click={@on_apply}
        phx-value-query_string=""
      >
        All
      </div>

      <%!-- Saved views --%>
      <div :for={view <- @views} class="relative group">
        <div class={[
          "inline-flex items-center gap-1 border py-0.5 text-sm transition-colors rounded-sm px-1.5 pr-1 font-normal cursor-pointer border-transparent",
          view_color_classes(
            Map.get(view, :color) || Map.get(view, "color") || "gray",
            @current_query_string == view.query_string
          )
        ]}>
          <span phx-click={@on_apply} phx-value-query_string={view.query_string}>
            {view.name}
          </span>
          <%!-- Delete button inside the badge --%>
          <button
            type="button"
            class="inline-flex items-center justify-center h-4 w-4 rounded-sm hover:bg-secondary/60 transition-colors"
            phx-click={@on_delete}
            phx-value-view_id={view.id}
            data-confirm="Are you sure you want to delete this view?"
            title="Delete view"
          >
            <.icon name="hero-x-mark" class="h-3 w-3" />
          </button>
        </div>
      </div>

      <%!-- More views dropdown if there are many --%>
      <%= if length(@views) > 5 do %>
        <.dropdown_menu id="more-views-dropdown">
          <.dropdown_menu_trigger>
            <.button variant="ghost" size="sm" class="h-7 px-2">
              <.icon name="hero-ellipsis-horizontal" class="h-4 w-4" />
            </.button>
          </.dropdown_menu_trigger>
          <.dropdown_menu_content align="start" class="w-56">
            <.dropdown_menu_label>All Views</.dropdown_menu_label>
            <.dropdown_menu_separator />
            <.dropdown_menu_item :for={view <- Enum.drop(@views, 5)} class="cursor-pointer">
              <button
                type="button"
                class="w-full text-left flex items-center justify-between"
                phx-click={@on_apply}
                phx-value-query_string={view.query_string}
              >
                <span>{view.name}</span>
                <button
                  type="button"
                  class="ml-2 opacity-60 hover:opacity-100"
                  phx-click={@on_delete}
                  phx-value-view_id={view.id}
                  onclick="event.stopPropagation()"
                >
                  <.icon name="hero-x-mark" class="h-3 w-3" />
                </button>
              </button>
            </.dropdown_menu_item>
          </.dropdown_menu_content>
        </.dropdown_menu>
      <% end %>
    </div>
    """
  end

  # Helper function to get color classes for view badges
  # Active views match hover state, inactive get lighter background
  defp view_color_classes(color, is_active) do
    case {color, is_active} do
      {"gray", true} -> "bg-secondary/80 text-secondary-foreground hover:bg-secondary/80"
      {"gray", false} -> "bg-secondary/40 hover:bg-secondary/80"
      {"blue", true} -> "bg-blue-200 text-blue-900 hover:bg-blue-200"
      {"blue", false} -> "bg-blue-100 text-blue-800 hover:bg-blue-200"
      {"purple", true} -> "bg-purple-200 text-purple-900 hover:bg-purple-200"
      {"purple", false} -> "bg-purple-100 text-purple-800 hover:bg-purple-200"
      {"green", true} -> "bg-emerald-200 text-emerald-900 hover:bg-emerald-200"
      {"green", false} -> "bg-emerald-100 text-emerald-800 hover:bg-emerald-200"
      {"amber", true} -> "bg-amber-200 text-amber-900 hover:bg-amber-200"
      {"amber", false} -> "bg-amber-100 text-amber-800 hover:bg-amber-200"
      {"rose", true} -> "bg-rose-200 text-rose-900 hover:bg-rose-200"
      {"rose", false} -> "bg-rose-100 text-rose-800 hover:bg-rose-200"
      {"cyan", true} -> "bg-cyan-200 text-cyan-900 hover:bg-cyan-200"
      {"cyan", false} -> "bg-cyan-100 text-cyan-800 hover:bg-cyan-200"
      {"indigo", true} -> "bg-indigo-200 text-indigo-900 hover:bg-indigo-200"
      {"indigo", false} -> "bg-indigo-100 text-indigo-800 hover:bg-indigo-200"
      # Fallback to gray for unknown colors
      {_, true} -> "bg-secondary/80 text-secondary-foreground hover:bg-secondary/80"
      {_, false} -> "bg-secondary/40 hover:bg-secondary/80"
    end
  end
end
