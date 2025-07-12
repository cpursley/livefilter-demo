defmodule TodoAppWeb.TodoLive.Index do
  @moduledoc """
  LiveView module demonstrating comprehensive LiveFilter integration.

  Features:
  - Real-time filtering with URL persistence
  - Multi-select, date range, and boolean filters
  - Dynamic column visibility management
  - Database-level pagination with efficient queries
  - Field registry for extensible filter configuration

  ## LiveFilter Integration

  Uses `LiveFilter.Mountable` for seamless LiveView integration:
  - `mount_filters/2` - Initialize filter state and registry
  - `handle_filter_params/3` - Parse URL parameters and restore UI state
  - `apply_filters_and_reload/3` - Apply filters and update URL

  ## Architecture

  Follows a two-tier filtering approach:
  1. **Default Filters**: Always visible (search, status, assignee, due date, urgent)
  2. **Optional Filters**: Added via dropdown (project, tags, hours, complexity)

  Filter state is managed through:
  - LiveFilter.FilterGroup for query building
  - Socket assigns for UI state (selected values, active filters)
  - Field registry for configuration and validation
  """

  use TodoAppWeb, :live_view
  use LiveFilter.Mountable

  alias TodoApp.Todos
  alias SaladUI.{Badge, Button}
  alias TodoAppWeb.Components.{LiveFilterLayout, FilterToolbar, PaginationHelper, TodoCard}
  alias LiveFilter.QuickFilters
  import LiveFilter.Components.SortableHeader

  @impl true
  @doc """
  Initializes the LiveView with filter state and default assigns.

  Sets up:
  - LiveFilter integration via mount_filters/2 with field registry
  - Default UI state for all filter types
  - Column configuration for dynamic table display
  - Empty todo stream (populated in handle_params/3)

  ## Parameters
  - `_params` - Mount parameters (unused)
  - `_session` - Session data (unused)
  - `socket` - LiveView socket

  Returns `{:ok, socket}` with initialized state.
  """
  def mount(_params, _session, socket) do
    socket =
      socket
      |> mount_filters(
        registry: todo_field_registry(),
        default_sort: LiveFilter.Sort.new(:due_date, :asc)
      )
      |> assign(:search_query, "")
      |> assign(:selected_statuses, [])
      |> assign(:selected_assignees, [])
      |> assign(:date_range, nil)
      |> assign(:is_urgent, false)
      # Track which optional filters are active
      |> assign(:active_optional_filters, [])
      # Store values for optional filters
      |> assign(:optional_filter_values, %{})
      |> assign(:view_mode, "table")
      |> assign(:per_page, 10)
      |> assign(:status_counts, %{})
      |> assign(:column_config, column_config())
      |> assign(:visible_columns, default_visible_columns())
      # Initialize empty streams for desktop table, desktop cards, and mobile views
      |> stream(:todos, [])
      |> stream(:todos_cards, [])
      |> stream(:todos_mobile, [])

    {:ok, socket}
  end

  @impl true
  @doc """
  Handles URL parameter changes and updates filter state.

  Parses filter parameters from URL using LiveFilter.Mountable.handle_filter_params/3,
  loads filtered todos, and applies the current live_action.

  Uses convert_filters_to_ui_state/2 as ui_converter to restore UI state from filters.

  ## Parameters
  - `params` - URL parameters containing filter state
  - `_url` - Current URL (unused)
  - `socket` - Current socket state

  Returns `{:noreply, updated_socket}` with applied filters and loaded data.
  """
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> handle_filter_params(params, ui_converter: &convert_filters_to_ui_state/2)
      |> load_todos()
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  # Sets the page title for the index action
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Todo Filter Demo")
  end

  # Message handlers for filter components

  @impl true
  def handle_info({:date_range_selected, date_range}, socket) do
    # This is from the Due Date filter (no field specified)
    socket =
      socket
      |> assign(:date_range, date_range)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:date_range_selected, field, date_range}, socket) do
    # This is from an optional filter with a datetime field
    send(self(), {:quick_filter_changed, field, date_range})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:filter_selected, field}, socket) do
    # Add the selected filter to active optional filters (at the end)
    active_filters = socket.assigns.active_optional_filters ++ [field]

    socket =
      socket
      |> assign(:active_optional_filters, active_filters)
      |> apply_quick_filters()

    # Send ourselves a message to auto-open after the component has rendered
    Process.send_after(self(), {:auto_open_filter, field}, 100)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:auto_open_filter, field}, socket) do
    {:noreply, push_event(socket, "auto_open_filter", %{field: field})}
  end

  @impl true
  def handle_info({:quick_filter_changed, field, value}, socket) do
    # Update the value for the optional filter
    filter_values = Map.put(socket.assigns.optional_filter_values, field, value)

    socket =
      socket
      |> assign(:optional_filter_values, filter_values)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:quick_filter_cleared, field}, socket) do
    # Remove the filter from active filters and clear its value
    active_filters = List.delete(socket.assigns.active_optional_filters, field)
    filter_values = Map.delete(socket.assigns.optional_filter_values, field)

    socket =
      socket
      |> assign(:active_optional_filters, active_filters)
      |> assign(:optional_filter_values, filter_values)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:sort_changed, new_sort}, socket) do
    socket =
      socket
      |> assign(:current_sort, new_sort)
      |> load_todos_and_update_url_state()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:column_visibility_changed, new_visible_columns}, socket) do
    socket =
      socket
      |> assign(:visible_columns, new_visible_columns)
      |> load_todos()

    {:noreply, socket}
  end

  # Event handlers

  @impl true
  @doc """
  Routes dynamic quick filter events through EventRouter.

  Handles events like "quick_filter_status_changed" by parsing the event name
  and routing to appropriate handlers based on field type.
  """
  def handle_event("quick_filter_" <> _rest = event, params, socket) do
    LiveFilter.EventRouter.route_event(event, params,
      handlers: %{
        "status_changed" => &handle_status_filter_change/3,
        "assignee_changed" => &handle_assignee_filter_change/3,
        "urgent_changed" => &handle_urgent_filter_change/3
      },
      fallback: &handle_optional_filter_change/3,
      parse_opts: [prefix: "quick_filter_"],
      socket: socket
    )
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_status_filter", params, socket) do
    handle_event("quick_filter_status_changed", params, socket)
  end

  def handle_event("toggle_assignee_filter", params, socket) do
    handle_event("quick_filter_assignee_changed", params, socket)
  end

  def handle_event("toggle_urgent_filter", _params, socket) do
    handle_event("quick_filter_urgent_changed", %{"toggle" => "urgent"}, socket)
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("sort_by", %{"field" => field}, socket) do
    # Handle clear sort
    if field == "clear" do
      socket =
        socket
        |> assign(:current_sort, nil)
        |> load_todos_and_update_url_state()

      {:noreply, socket}
    else
      field_atom = String.to_existing_atom(field)
      current_sort = socket.assigns.current_sort

      # Toggle direction if clicking on the same field, otherwise default to asc
      new_sort =
        if current_sort && current_sort.field == field_atom do
          LiveFilter.Sort.toggle_direction(current_sort)
        else
          LiveFilter.Sort.new(field_atom, :asc)
        end

      socket =
        socket
        |> assign(:current_sort, new_sort)
        |> load_todos_and_update_url_state()

      {:noreply, socket}
    end
  end

  def handle_event("mobile_sort_change", %{"value" => value}, socket) do
    # Convert to sort_by event format
    if value == "" do
      # Clear sort
      handle_event("sort_by", %{"field" => "clear"}, socket)
    else
      handle_event("sort_by", %{"field" => value}, socket)
    end
  end

  def handle_event("change_per_page", %{"per_page" => per_page}, socket) do
    socket =
      socket
      |> assign(:per_page, String.to_integer(per_page))
      |> assign(:current_page, 1)
      |> load_todos_and_update_url_state()

    {:noreply, socket}
  end

  def handle_event("navigate_page", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:current_page, page)
      |> load_todos_and_update_url_state()

    {:noreply, socket}
  end

  def handle_event("remove_filter", %{"filter_index" => filter_index}, socket) do
    filters = List.delete_at(socket.assigns.filter_group.filters, filter_index)
    filter_group = %{socket.assigns.filter_group | filters: filters}

    socket =
      socket
      |> assign(:filter_group, filter_group)
      |> load_todos_and_update_url_state()

    {:noreply, socket}
  end

  def handle_event("clear_all_filters", _params, socket) do
    socket =
      socket
      |> assign(:filter_group, %LiveFilter.FilterGroup{})
      |> assign(:search_query, "")
      |> assign(:selected_statuses, [])
      |> assign(:selected_assignees, [])
      |> assign(:date_range, nil)
      |> assign(:is_urgent, false)
      |> assign(:active_optional_filters, [])
      |> assign(:optional_filter_values, %{})
      # Reset to first page when clearing filters
      |> assign(:current_page, 1)
      |> load_todos_and_update_url_state()

    {:noreply, socket}
  end

  def handle_event("change_view_mode", params, socket) do
    # The tabs component sends the value in the "value" key
    mode = params["value"] || params["tab"]

    socket =
      socket
      |> assign(:view_mode, mode)
      |> load_todos()

    {:noreply, socket}
  end

  defp load_todos_and_update_url_state(socket) do
    socket
    |> load_todos()
    |> update_url_state()
  end

  # View helper functions

  # Returns the CSS variant class for status badges based on todo status
  def status_variant(status) do
    case status do
      :completed -> "default"
      :in_progress -> "secondary"
      :pending -> "outline"
      :archived -> "secondary"
      _ -> "outline"
    end
  end

  # Formats assignee names from snake_case to Title Case for display
  def format_assignee_name(assignee) do
    assignee
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Formats project names using options lookup or fallback snake_case to Title Case conversion
  def format_project_name(project) do
    # Get the label from project options
    case Enum.find(TodoApp.Todos.Todo.project_options(), fn %{value: v} -> v == project end) do
      %{label: label} ->
        label

      nil ->
        # Fallback formatting if not found in options
        project
        |> String.split("_")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  # Checks if any filters are currently active - used to show/hide clear filters button
  def has_any_filters?(assigns) do
    length(assigns.filter_group.filters) > 0 ||
      assigns.search_query != "" ||
      length(assigns.selected_statuses) > 0 ||
      length(assigns.selected_assignees) > 0 ||
      assigns.date_range != nil ||
      assigns.is_urgent == true ||
      length(assigns.active_optional_filters) > 0
  end

  # Formats date as human-readable relative time (Today, Tomorrow, In 3 days, etc.)
  def format_date(date) do
    today = Date.utc_today()

    case Date.diff(date, today) do
      0 -> "Today"
      1 -> "Tomorrow"
      -1 -> "Yesterday"
      days when days > 0 and days <= 7 -> "In #{days} days"
      days when days < 0 and days >= -7 -> "#{abs(days)} days ago"
      _ -> Calendar.strftime(date, "%b %d, %Y")
    end
  end

  # Formats datetime as relative time for recent dates (Just now, 5 min ago, Yesterday, etc.)
  def format_datetime(datetime) do
    # Format as relative time for recent dates, otherwise show date
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)
    diff_days = div(diff_seconds, 86_400)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} min ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_days == 1 -> "Yesterday"
      diff_days <= 7 -> "#{diff_days} days ago"
      diff_days <= 30 -> "#{div(diff_days, 7)} weeks ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  # Private functions

  # Loads paginated todos based on current filters and sort, updates stream and counts
  defp load_todos(socket) do
    # Use database-level pagination for better performance
    pagination_result =
      Todos.list_todos_paginated(
        socket.assigns.filter_group,
        socket.assigns.current_sort,
        page: socket.assigns.current_page,
        per_page: socket.assigns.per_page
      )

    # Calculate counts for status filters
    status_counts =
      Todos.count_by_status(socket.assigns.filter_group, socket.assigns.current_sort)

    socket
    |> stream(:todos, pagination_result.todos, reset: true)
    |> stream(:todos_cards, pagination_result.todos,
      reset: true,
      dom_id: fn todo -> "cards-#{todo.id}" end
    )
    |> stream(:todos_mobile, pagination_result.todos,
      reset: true,
      dom_id: fn todo -> "mobile-#{todo.id}" end
    )
    |> assign(:todo_count, length(pagination_result.todos))
    |> assign(:total_count, pagination_result.total_count)
    |> assign(:total_pages, pagination_result.total_pages)
    |> assign(:status_counts, status_counts)
  end

  # Builds filters from UI state and applies them, triggering data reload and URL update
  defp apply_quick_filters(socket) do
    # Build filters from current UI state using functional composition
    filters = build_filters_from_ui_state(socket)

    # Apply filters and trigger reload with URL update
    socket
    |> apply_filters_and_reload(
      %LiveFilter.FilterGroup{filters: filters, groups: [], conjunction: :and},
      reload_callback: &load_todos/1,
      path: "/todos"
    )
  end

  # Converts UI state (search, selects, etc.) into LiveFilter.Filter structs
  defp build_filters_from_ui_state(socket) do
    # Basic filters using QuickFilters helpers
    # Each function returns nil if the filter is empty/inactive
    basic_filters =
      [
        LiveFilter.QuickFilters.search_filter(socket.assigns.search_query),
        LiveFilter.QuickFilters.multi_select_filter(:status, socket.assigns.selected_statuses),
        LiveFilter.QuickFilters.multi_select_filter(
          :assigned_to,
          socket.assigns.selected_assignees
        ),
        LiveFilter.QuickFilters.date_range_filter(:due_date, socket.assigns.date_range),
        LiveFilter.QuickFilters.boolean_filter(:is_urgent, socket.assigns.is_urgent,
          true_only: true
        )
      ]
      # Remove inactive filters
      |> Enum.reject(&is_nil/1)

    # Optional filters from field registry
    # Uses registry to determine field types and default operators
    registry = todo_field_registry()
    optional_filters = build_optional_filters(socket, registry)

    # Combine all filters into single list
    basic_filters ++ optional_filters
  end

  # Builds optional filters from active filter fields and their current values
  defp build_optional_filters(socket, registry) do
    socket.assigns.active_optional_filters
    |> Enum.map(&build_optional_filter(&1, socket.assigns.optional_filter_values, registry))
    |> Enum.reject(&is_nil/1)
  end

  # Builds a single optional filter if field has a value and is in registry
  defp build_optional_filter(field, filter_values, registry) do
    with value when value not in [nil, "", []] <- Map.get(filter_values, field),
         field_config when not is_nil(field_config) <-
           LiveFilter.FieldRegistry.get_field(registry, field) do
      # Use QuickFilters helpers for date/datetime fields with range values
      case {field_config.type, value} do
        {type, {_, _} = range} when type in [:date, :datetime, :utc_datetime, :naive_datetime] ->
          # Use the date_range_filter helper which handles between operator correctly
          LiveFilter.QuickFilters.date_range_filter(field, range, type: type)

        _ ->
          # For other types, use standard filter creation
          %LiveFilter.Filter{
            field: field,
            operator: LiveFilter.FieldRegistry.get_default_operator(registry, field),
            value: value,
            type: field_config.type
          }
      end
    else
      _ -> nil
    end
  end

  # Creates field registry with all available filter fields and their types
  defp todo_field_registry do
    LiveFilter.FieldRegistry.from_fields([
      LiveFilter.FieldRegistry.string_field(:title, "Title"),
      LiveFilter.FieldRegistry.string_field(:description, "Description"),
      LiveFilter.FieldRegistry.enum_field(:status, "Status", []),
      LiveFilter.FieldRegistry.enum_field(:assigned_to, "Assignee", []),
      LiveFilter.FieldRegistry.enum_field(:project, "Project", []),
      LiveFilter.FieldRegistry.date_field(:due_date, "Due Date"),
      LiveFilter.FieldRegistry.boolean_field(:is_urgent, "Urgent"),
      {:tags, :array, label: "Tags"},
      {:estimated_hours, :float, label: "Estimated Hours"},
      {:actual_hours, :float, label: "Actual Hours"},
      {:complexity, :integer, label: "Complexity"},
      {:inserted_at, :utc_datetime, label: "Created"}
    ])
  end

  # Defines optional fields available in the filter dropdown with icons and options
  defp optional_field_options do
    # Define which fields are available as optional filters
    # Format: {field, label, type, options}
    [
      {:project, "Project", :enum,
       %{
         icon: "hero-folder",
         options:
           TodoApp.Todos.Todo.project_options()
           |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
       }},
      {:tags, "Tags", :array,
       %{
         icon: "hero-tag",
         options:
           TodoApp.Todos.Todo.tag_options() |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
       }},
      {:estimated_hours, "Est. Hours", :float, %{icon: "hero-clock"}},
      {:actual_hours, "Actual Hours", :float, %{icon: "hero-check-circle"}},
      {:complexity, "Complexity", :integer, %{icon: "hero-chart-bar"}},
      {:inserted_at, "Created", :utc_datetime, %{icon: "hero-clock"}}
    ]
  end

  # EventRouter handlers

  # Handles status filter changes - toggles, selects, or clears status values
  defp handle_status_filter_change(_field, params, socket) do
    value = LiveFilter.EventRouter.extract_event_value(params)

    new_statuses =
      case value do
        {:clear, true} ->
          []

        {:toggle, status} ->
          toggle_in_list(
            socket.assigns.selected_statuses,
            LiveFilter.TypeUtils.safe_to_atom(status)
          )

        {:select, status} ->
          [LiveFilter.TypeUtils.safe_to_atom(status)]

        _ ->
          socket.assigns.selected_statuses
      end

    socket
    |> assign(:selected_statuses, new_statuses)
    |> apply_quick_filters()
    |> then(&{:noreply, &1})
  end

  # Handles assignee filter changes - toggles, selects, or clears assignee values
  defp handle_assignee_filter_change(_field, params, socket) do
    value = LiveFilter.EventRouter.extract_event_value(params)

    new_assignees =
      case value do
        {:clear, true} -> []
        {:toggle, assignee} -> toggle_in_list(socket.assigns.selected_assignees, assignee)
        {:select, assignee} -> [assignee]
        _ -> socket.assigns.selected_assignees
      end

    socket
    |> assign(:selected_assignees, new_assignees)
    |> apply_quick_filters()
    |> then(&{:noreply, &1})
  end

  # Handles urgent filter changes - toggles boolean urgent flag
  defp handle_urgent_filter_change(_field, params, socket) do
    value = LiveFilter.EventRouter.extract_event_value(params)

    new_urgent =
      case value do
        {:clear, true} -> false
        {:toggle, _} -> !socket.assigns.is_urgent
        _ -> socket.assigns.is_urgent
      end

    socket
    |> assign(:is_urgent, new_urgent)
    |> apply_quick_filters()
    |> then(&{:noreply, &1})
  end

  # Routes optional filter events to appropriate message handlers
  defp handle_optional_filter_change(event, params, socket) do
    case LiveFilter.EventRouter.parse_filter_event(event, prefix: "quick_filter_") do
      {:ok, field, _action} ->
        value = LiveFilter.EventRouter.extract_event_value(params)

        # Get the field type to handle array fields properly
        field_type = get_optional_filter_type(field)

        case value do
          {:clear, true} ->
            send(self(), {:quick_filter_cleared, field})

          {:toggle, toggle_value} when field_type == :array ->
            # For array fields, toggle the value in the existing array
            current_values = Map.get(socket.assigns.optional_filter_values, field, [])
            new_values = toggle_in_list(current_values, toggle_value)
            send(self(), {:quick_filter_changed, field, new_values})

          {_type, new_value} ->
            send(self(), {:quick_filter_changed, field, new_value})

          _ ->
            nil
        end

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # Toggles an item in a list - adds if not present, removes if present
  defp toggle_in_list(list, item) do
    if item in list do
      List.delete(list, item)
    else
      [item | list]
    end
  end

  # Column configuration

  # Defines table column configuration with visibility and toggle settings
  defp column_config do
    %{
      # Always shown - cannot be toggled off
      title: %{label: "Title", toggleable: false, default_visible: true},

      # Active by default - can be toggled
      status: %{label: "Status", toggleable: true, default_visible: true},
      project: %{label: "Project", toggleable: true, default_visible: true},
      assigned_to: %{label: "Assignee", toggleable: true, default_visible: true},
      due_date: %{label: "Due Date", toggleable: true, default_visible: true},
      estimated_hours: %{label: "Est. Hours", toggleable: true, default_visible: true},

      # Optional - hidden by default
      description: %{label: "Description", toggleable: true, default_visible: false},
      tags: %{label: "Tags", toggleable: true, default_visible: false},
      created_at: %{label: "Created", toggleable: true, default_visible: false},
      completed_at: %{label: "Completed", toggleable: true, default_visible: false},
      actual_hours: %{label: "Actual Hours", toggleable: true, default_visible: false},
      is_recurring: %{label: "Recurring", toggleable: true, default_visible: false},
      complexity: %{label: "Complexity", toggleable: true, default_visible: false}
    }
  end

  # Returns list of columns visible by default based on column configuration
  defp default_visible_columns do
    column_config()
    |> Enum.filter(fn {_col, config} -> config.default_visible end)
    |> Enum.map(fn {col, _config} -> col end)
  end

  # Updates URL with current filter, sort, and pagination state
  defp update_url_state(socket) do
    update_filter_url(socket,
      path: "/todos",
      include_pagination: true,
      include_sort: true
    )
  end

  # Converts FilterGroup back to UI state assigns for form controls
  defp convert_filters_to_ui_state(socket, filter_group) do
    # Define extractors for standard filters
    standard_extractors = [
      search_query: fn fg -> QuickFilters.extract_search_query(fg) || "" end,
      selected_statuses: fn fg ->
        QuickFilters.extract_multi_select(fg, :status)
        |> LiveFilter.TypeUtils.safe_to_atom()
      end,
      selected_assignees: fn fg -> QuickFilters.extract_multi_select(fg, :assigned_to) end,
      date_range: fn fg -> QuickFilters.extract_date_range(fg, :due_date) end,
      is_urgent: fn fg -> QuickFilters.extract_boolean(fg, :is_urgent, default: false) end
    ]

    # Apply standard filter extractors
    socket = QuickFilters.extract_all(filter_group, standard_extractors, socket: socket)

    # Extract optional filters (excluding standard fields)
    excluded_fields = [:status, :assigned_to, :due_date, :is_urgent, :_search]
    optional_result = QuickFilters.extract_optional_filters(filter_group, excluded_fields)

    # Filter optional fields to only include those in our configured list
    valid_optional_fields = get_optional_field_names()

    # Get current active filters that don't have values (newly added filters)
    current_active_without_values =
      Enum.filter(socket.assigns[:active_optional_filters] || [], fn field ->
        field in valid_optional_fields &&
          !Map.has_key?(optional_result.optional_filter_values, field)
      end)

    # Merge filters from URL with filters that were just added but have no values yet
    filtered_active =
      (optional_result.active_optional_filters ++ current_active_without_values)
      |> Enum.uniq()
      |> Enum.filter(&(&1 in valid_optional_fields))

    filtered_values =
      Map.take(optional_result.optional_filter_values, valid_optional_fields)

    socket
    |> assign(:active_optional_filters, filtered_active)
    |> assign(:optional_filter_values, filtered_values)
  end

  # Extracts field names from optional field options for validation
  defp get_optional_field_names do
    optional_field_options()
    |> Enum.map(fn {field, _, _, _} -> field end)
  end

  # Gets the type of an optional filter field
  defp get_optional_filter_type(field) do
    case Enum.find(optional_field_options(), fn {f, _, _, _} -> f == field end) do
      {_, _, type, _} -> type
      nil -> nil
    end
  end
end
