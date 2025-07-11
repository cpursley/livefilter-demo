defmodule TodoAppWeb.Components.FilterToolbar do
  @moduledoc """
  Toolbar component with search input and quick filter dropdowns.
  Loosely follows shadcn table design pattern.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: TodoAppWeb.Endpoint,
    router: TodoAppWeb.Router,
    statics: TodoAppWeb.static_paths()

  import TodoAppUi.Input
  import TodoAppUi.Button
  import TodoAppUi.DropdownMenu
  import TodoAppUi.Icon
  import TodoAppUi.Badge

  import Phoenix.Component
  import LiveFilter.Components.SearchSelect
  alias LiveFilter.Components.{FilterSelector, QuickFilter}

  alias Phoenix.LiveView.JS

  @doc """
  Renders a search input with debounced search functionality.
  """
  attr :id, :string, default: "search-input"
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search..."
  attr :on_search, :any, default: nil
  attr :class, :string, default: nil

  def search_input(assigns) do
    ~H"""
    <form phx-change={@on_search} class={["relative flex items-center", @class]}>
      <.icon
        name="hero-magnifying-glass"
        class="absolute left-2 h-4 w-4 text-muted-foreground pointer-events-none"
      />
      <.input
        id={@id}
        type="text"
        name="query"
        placeholder={@placeholder}
        value={@value}
        class={["pl-8 h-8", @value != "" && "pr-8"]}
        phx-debounce="300"
        autocomplete="off"
      />
      <%= if @value != "" do %>
        <button
          type="button"
          class="absolute right-2 h-4 w-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 flex items-center justify-center"
          phx-click="clear_search"
        >
          <.icon name="hero-x-mark" class="h-4 w-4" />
          <span class="sr-only">Clear search</span>
        </button>
      <% end %>
    </form>
    """
  end

  @doc """
  Renders a quick filter dropdown button.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :selected_count, :integer, default: 0
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def quick_filter_dropdown(assigns) do
    ~H"""
    <.dropdown_menu id={@id}>
      <.dropdown_menu_trigger>
        <.button variant="outline" size="sm" class={@class}>
          <.icon :if={@icon} name={@icon} class="mr-2 h-4 w-4" />
          {@label}
          <.badge
            :if={@selected_count > 0}
            variant="secondary"
            class="ml-2 rounded-sm px-1 font-normal"
          >
            {@selected_count}
          </.badge>
        </.button>
      </.dropdown_menu_trigger>
      <.dropdown_menu_content align="start" class="w-[200px]">
        {render_slot(@inner_block)}
      </.dropdown_menu_content>
    </.dropdown_menu>
    """
  end

  @doc """
  Renders a status filter dropdown with checkboxes.
  """
  attr :id, :string, default: "status-filter"
  attr :selected_statuses, :list, default: []
  attr :on_status_change, :any, default: nil
  attr :status_counts, :map, default: %{}

  attr :statuses, :list,
    default: [
      {:pending, "Pending", "default"},
      {:in_progress, "In Progress", "secondary"},
      {:completed, "Completed", "default"},
      {:archived, "Archived", "outline"}
    ]

  def status_filter(assigns) do
    # Convert status tuples to SearchSelect format
    options =
      Enum.map(assigns.statuses, fn {value, label, _variant} ->
        {value, label}
      end)

    assigns = assign(assigns, :options, options)

    ~H"""
    <.search_select
      id={@id}
      options={@options}
      selected={@selected_statuses}
      on_change={@on_status_change}
      label="Status"
      icon="hero-circle-stack"
      multiple={false}
      clearable={true}
      display_count={3}
    />
    """
  end

  @doc """
  Renders an assignee filter dropdown.
  """
  attr :id, :string, default: "assignee-filter"
  attr :selected_assignees, :list, default: []
  attr :on_assignee_change, :any, default: nil

  attr :assignees, :list,
    default: [
      {"john_doe", "John Doe"},
      {"jane_smith", "Jane Smith"},
      {"bob_johnson", "Bob Johnson"},
      {"alice_williams", "Alice Williams"},
      {"charlie_brown", "Charlie Brown"}
    ]

  def assignee_filter(assigns) do
    assigns = assign(assigns, :options, assigns.assignees)

    ~H"""
    <.search_select
      id={@id}
      options={@options}
      selected={@selected_assignees}
      on_change={@on_assignee_change}
      label="Assignee"
      icon="hero-user"
      multiple={true}
      clearable={true}
      display_count={2}
      searchable={true}
    />
    """
  end

  @doc """
  Renders a date range filter using the LiveFilter DateRangeSelect component.
  """
  attr :id, :string, default: "date-filter"
  attr :selected_range, :any, default: nil
  attr :on_date_change, :any, default: nil
  attr :label, :string, default: "Created At"
  attr :icon, :string, default: "hero-calendar-days"
  attr :timestamp_type, :atom, default: :date
  attr :enabled_presets, :list, default: nil

  def date_filter(assigns) do
    # Build the attributes dynamically
    attrs = [
      module: LiveFilter.Components.DateRangeSelect,
      id: assigns.id,
      value: assigns.selected_range,
      label: assigns.label,
      icon: assigns.icon,
      size: "sm",
      timestamp_type: assigns.timestamp_type
    ]

    # Only add enabled_presets if it's explicitly set
    attrs =
      if assigns.enabled_presets != nil do
        Keyword.put(attrs, :enabled_presets, assigns.enabled_presets)
      else
        attrs
      end

    assigns = assign(assigns, :attrs, attrs)

    ~H"""
    <.live_component {@attrs} />
    """
  end

  @doc """
  Renders a boolean filter (urgent/not urgent).
  """
  attr :id, :string, default: "urgent-filter"
  attr :selected, :boolean, default: false
  attr :on_change, :any, default: nil
  attr :label, :string, default: "Urgent"
  attr :icon, :string, default: "hero-exclamation-triangle"

  def boolean_filter(assigns) do
    ~H"""
    <.button variant={if @selected, do: "default", else: "outline"} size="sm" phx-click={@on_change}>
      <.icon :if={@icon} name={@icon} class="mr-2 h-4 w-4" />
      <%= if @selected do %>
        {@label}
        <.icon name="hero-check" class="ml-2 h-4 w-4" />
      <% else %>
        {@label}?
      <% end %>
    </.button>
    """
  end

  @doc """
  Renders view controls (sort button only).
  """
  attr :current_sort, :any, default: nil
  attr :field_options, :list, default: []

  def view_controls(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <.live_component
        module={LiveFilter.Components.SortSelector}
        id="sort-selector"
        current_sorts={@current_sort}
        field_options={@field_options}
      />
    </div>
    """
  end

  @doc """
  Renders active filter pills that can be removed.
  """
  attr :filters, :list, default: []
  attr :on_remove_filter, :any, default: nil
  attr :on_clear_all, :any, default: nil

  def active_filters(assigns) do
    ~H"""
    <div :if={@filters != []} class="flex flex-wrap items-center gap-2 p-4 border-t">
      <span class="text-sm text-muted-foreground">Active filters:</span>
      <.badge :for={{filter, index} <- Enum.with_index(@filters)} variant="secondary" class="gap-1">
        {filter_label(filter)}
        <.button
          variant="ghost"
          size="icon"
          class="h-3 w-3 p-0 hover:bg-transparent"
          phx-click={JS.push(@on_remove_filter, value: %{filter_index: index})}
        >
          <.icon name="hero-x-mark" class="h-3 w-3" />
        </.button>
      </.badge>
      <.button variant="ghost" size="sm" class="h-6" phx-click={@on_clear_all}>
        Clear all
      </.button>
    </div>
    """
  end

  # Helper functions

  def view_icon("table"), do: "hero-table-cells"
  def view_icon("cards"), do: "hero-squares-2x2"
  def view_icon("list"), do: "hero-bars-3"
  def view_icon(_), do: "hero-table-cells"

  defp filter_label(%{field: field, operator: operator, value: value}) do
    "#{humanize_field(field)} #{humanize_operator(operator)} #{value}"
  end

  defp humanize_field(field) do
    field |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp humanize_operator(operator) do
    case operator do
      :equals -> "is"
      :contains -> "contains"
      :greater_than -> ">"
      :less_than -> "<"
      :between -> "between"
      _ -> to_string(operator)
    end
  end

  @doc """
  Renders optional filters section with add filter button.
  """
  attr :id, :string, default: "optional-filters"
  attr :available_filters, :list, required: true
  attr :active_filters, :list, default: []
  attr :filter_values, :map, default: %{}
  attr :on_filter_selected, :any, default: nil
  attr :on_filter_changed, :any, default: nil
  attr :class, :string, default: nil

  def optional_filters_section(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-2", @class]}>
      <.live_component
        :for={field <- @active_filters}
        module={QuickFilter}
        id={"optional-filter-#{field}"}
        field={field}
        label={get_filter_label(@available_filters, field)}
        type={get_filter_type(@available_filters, field)}
        value={Map.get(@filter_values, field)}
        icon={get_filter_icon(@available_filters, field)}
        options={get_filter_options(@available_filters, field)}
      />

      <.live_component
        module={FilterSelector}
        id={"#{@id}-selector"}
        available_filters={@available_filters}
        active_filters={@active_filters}
      />
    </div>
    """
  end

  # Helper functions for optional filters
  defp get_filter_label(filters, field) do
    case List.keyfind(filters, field, 0) do
      {_, label, _, _} -> label
      _ -> Phoenix.Naming.humanize(field)
    end
  end

  defp get_filter_type(filters, field) do
    case List.keyfind(filters, field, 0) do
      {_, _, type, _} -> type
      _ -> :string
    end
  end

  defp get_filter_icon(filters, field) do
    case List.keyfind(filters, field, 0) do
      {_, _, _, %{icon: icon}} -> icon
      _ -> nil
    end
  end

  defp get_filter_options(filters, field) do
    case List.keyfind(filters, field, 0) do
      {_, _, _, %{options: options}} -> options
      _ -> []
    end
  end
end
