defmodule TodoAppWeb.TodoLive.Index do
  use TodoAppWeb, :live_view
  use LiveFilter.Mountable

  alias TodoApp.Todos
  alias TodoAppUi.{Badge, Button}
  alias LiveFilter.{FilterGroup, UrlSerializer, Sort, QuickFilters, EventRouter, FieldRegistry, UrlUtils}
  alias TodoAppWeb.Components.{LiveFilterLayout, FilterToolbar, PaginationHelper}
  import LiveFilter.Components.SortableHeader

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> mount_filters(
        registry: todo_field_registry(),
        default_sort: Sort.new(:due_date, :asc)
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
      |> assign(:view_type, "table")
      |> assign(:per_page, 10)
      |> assign(:status_counts, %{})
      |> assign(:column_config, column_config())
      |> assign(:visible_columns, default_visible_columns())
      # Initialize empty stream, will be populated in handle_params
      |> stream(:todos, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> handle_filter_params(params, ui_converter: &convert_filters_to_ui_state/2)
      |> load_todos()
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Todo Filter Demo")
  end

  @impl true
  def handle_info({:date_range_selected, date_range}, socket) do
    # Determine which filter sent the message by checking component IDs
    # This is a simplified approach - in production you might want to pass the field name
    socket =
      socket
      |> assign(:date_range, date_range)
      |> apply_quick_filters()

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
      |> push_event("auto_open_filter", %{field: field})

    {:noreply, socket}
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
      |> load_todos()

    # Update URL with new sort
    params = UrlSerializer.update_params(%{}, socket.assigns.filter_group, new_sort)

    {:noreply, push_patch(socket, to: ~p"/todos?#{params}")}
  end

  @impl true
  def handle_info({:column_visibility_changed, new_visible_columns}, socket) do
    IO.inspect(new_visible_columns, label: "New visible columns")

    socket =
      socket
      |> assign(:visible_columns, new_visible_columns)
      # Reload todos to reset the stream
      |> load_todos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_command_filters", _params, socket) do
    # TODO: Implement command palette
    {:noreply, put_flash(socket, :info, "Command filters coming soon!")}
  end

  # Handle dynamic quick filter events using EventRouter
  def handle_event("quick_filter_" <> _rest = event, params, socket) do
    EventRouter.route_event(event, params,
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

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_status_filter", %{"select" => status}, socket) do
    # Convert string to atom if needed
    status = if is_binary(status), do: String.to_existing_atom(status), else: status

    socket =
      socket
      |> assign(:selected_statuses, [status])
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_status_filter", %{"toggle" => status}, socket) do
    # Convert string to atom if needed
    status = if is_binary(status), do: String.to_existing_atom(status), else: status

    selected = socket.assigns.selected_statuses

    updated =
      if status in selected do
        List.delete(selected, status)
      else
        [status | selected]
      end

    socket =
      socket
      |> assign(:selected_statuses, updated)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_status_filter", %{"clear" => true}, socket) do
    socket =
      socket
      |> assign(:selected_statuses, [])
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_assignee_filter", %{"select" => assignee}, socket) do
    # For single select mode
    socket =
      socket
      |> assign(:selected_assignees, [assignee])
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_assignee_filter", %{"toggle" => assignee}, socket) do
    # For multi-select mode
    selected = socket.assigns.selected_assignees

    updated =
      if assignee in selected do
        List.delete(selected, assignee)
      else
        [assignee | selected]
      end

    socket =
      socket
      |> assign(:selected_assignees, updated)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_assignee_filter", %{"clear" => true}, socket) do
    socket =
      socket
      |> assign(:selected_assignees, [])
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("toggle_urgent_filter", _params, socket) do
    # Toggle the urgent filter
    socket =
      socket
      |> assign(:is_urgent, !socket.assigns.is_urgent)
      |> apply_quick_filters()

    {:noreply, socket}
  end

  def handle_event("sort_by", %{"field" => field}, socket) do
    field_atom = String.to_existing_atom(field)
    current_sort = socket.assigns.current_sort

    # Toggle direction if clicking on the same field, otherwise default to asc
    new_sort =
      if current_sort && current_sort.field == field_atom do
        Sort.toggle_direction(current_sort)
      else
        Sort.new(field_atom, :asc)
      end

    socket =
      socket
      |> assign(:current_sort, new_sort)
      |> load_todos()
      |> update_url_state()

    {:noreply, socket}
  end

  def handle_event("change_view", _params, socket) do
    # TODO: Implement view type switching
    {:noreply, put_flash(socket, :info, "View options coming soon!")}
  end

  def handle_event("change_per_page", %{"per_page" => per_page}, socket) do
    socket =
      socket
      |> assign(:per_page, String.to_integer(per_page))
      |> assign(:current_page, 1)
      |> load_todos()
      |> update_url_state()

    {:noreply, socket}
  end

  def handle_event("navigate_page", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:current_page, page)
      |> load_todos()
      |> update_url_state()

    {:noreply, socket}
  end

  def handle_event("remove_filter", %{"filter_index" => filter_index}, socket) do
    filters = List.delete_at(socket.assigns.filter_group.filters, filter_index)
    filter_group = %{socket.assigns.filter_group | filters: filters}

    socket =
      socket
      |> assign(:filter_group, filter_group)
      |> load_todos()
      |> update_url_state()

    {:noreply, socket}
  end

  def handle_event("clear_all_filters", _params, socket) do
    socket =
      socket
      |> assign(:filter_group, %FilterGroup{})
      |> assign(:search_query, "")
      |> assign(:selected_statuses, [])
      |> assign(:selected_assignees, [])
      |> assign(:date_range, nil)
      |> assign(:active_optional_filters, [])
      |> assign(:optional_filter_values, %{})
      # Reset to first page when clearing filters
      |> assign(:current_page, 1)
      |> load_todos()
      |> update_url_state()

    {:noreply, socket}
  end

  # Helper functions for the view
  defp status_variant(status) do
    case status do
      :completed -> "default"
      :in_progress -> "secondary"
      :pending -> "outline"
      :archived -> "secondary"
      _ -> "outline"
    end
  end

  defp format_assignee_name(assignee) do
    assignee
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_project_name(project) do
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

  defp has_any_filters?(assigns) do
    length(assigns.filter_group.filters) > 0 ||
      assigns.search_query != "" ||
      length(assigns.selected_statuses) > 0 ||
      length(assigns.selected_assignees) > 0 ||
      assigns.date_range != nil ||
      assigns.is_urgent == true ||
      length(assigns.active_optional_filters) > 0
  end

  defp format_date(date) do
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

  defp format_datetime(datetime) do
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

  # Override the default URL updater to include our custom reload function
  defp custom_reload_callback(socket) do
    load_todos(socket)
  end

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
    |> assign(:todo_count, length(pagination_result.todos))
    |> assign(:total_count, pagination_result.total_count)
    |> assign(:total_pages, pagination_result.total_pages)
    |> assign(:status_counts, status_counts)
  end

  defp apply_quick_filters(socket) do
    # Build filters using QuickFilters module
    filters = []

    # Search filter
    filters = 
      case QuickFilters.search_filter(socket.assigns.search_query) do
        nil -> filters
        filter -> [filter | filters]
      end

    # Status filter
    filters = 
      case QuickFilters.multi_select_filter(:status, socket.assigns.selected_statuses) do
        nil -> filters
        filter -> [filter | filters]
      end

    # Assignee filter
    filters = 
      case QuickFilters.multi_select_filter(:assigned_to, socket.assigns.selected_assignees) do
        nil -> filters
        filter -> [filter | filters]
      end

    # Date range filter
    filters = 
      case QuickFilters.date_range_filter(:due_date, socket.assigns.date_range) do
        nil -> filters
        filter -> [filter | filters]
      end

    # Urgent filter
    filters = 
      case QuickFilters.boolean_filter(:is_urgent, socket.assigns.is_urgent, true_only: true) do
        nil -> filters
        filter -> [filter | filters]
      end

    # Optional filters using field registry
    registry = todo_field_registry()
    filters =
      Enum.reduce(socket.assigns.active_optional_filters, filters, fn field, acc ->
        value = Map.get(socket.assigns.optional_filter_values, field)
        
        if value != nil && value != "" && value != [] do
          case FieldRegistry.get_field(registry, field) do
            nil -> acc
            field_config ->
              operator = FieldRegistry.get_default_operator(registry, field)
              
              filter = %LiveFilter.Filter{
                field: field,
                operator: operator,
                value: value,
                type: field_config.type
              }
              
              [filter | acc]
          end
        else
          acc
        end
      end)

    socket
    |> apply_filters_and_reload(
      %FilterGroup{filters: filters, groups: [], conjunction: :and},
      reload_callback: &custom_reload_callback/1,
      path: "/todos"
    )
  end

  # Create a field registry for todo fields
  defp todo_field_registry do
    FieldRegistry.from_fields([
      FieldRegistry.string_field(:title, "Title"),
      FieldRegistry.string_field(:description, "Description"),
      FieldRegistry.enum_field(:status, "Status", []),
      FieldRegistry.enum_field(:assigned_to, "Assignee", []),
      FieldRegistry.enum_field(:project, "Project", []),
      FieldRegistry.date_field(:due_date, "Due Date"),
      FieldRegistry.boolean_field(:is_urgent, "Urgent"),
      {:tags, :array, label: "Tags"},
      {:estimated_hours, :float, label: "Estimated Hours"},
      {:actual_hours, :float, label: "Actual Hours"},
      {:complexity, :integer, label: "Complexity"},
      {:inserted_at, :utc_datetime, label: "Created"}
    ])
  end

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

  # Helper functions for new LiveFilter integration
  defp handle_status_filter_change(_field, params, socket) do
    value = EventRouter.extract_event_value(params)
    
    new_statuses = 
      case value do
        {:clear, true} -> []
        {:toggle, status} -> toggle_in_list(socket.assigns.selected_statuses, String.to_existing_atom(status))
        {:select, status} -> [String.to_existing_atom(status)]
        _ -> socket.assigns.selected_statuses
      end
    
    socket
    |> assign(:selected_statuses, new_statuses)
    |> apply_quick_filters()
    |> then(&{:noreply, &1})
  end
  
  defp handle_assignee_filter_change(_field, params, socket) do
    value = EventRouter.extract_event_value(params)
    
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
  
  defp handle_urgent_filter_change(_field, params, socket) do
    value = EventRouter.extract_event_value(params)
    
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
  
  defp handle_optional_filter_change(event, params, socket) do
    case EventRouter.parse_filter_event(event, prefix: "quick_filter_") do
      {:ok, field, _action} ->
        value = EventRouter.extract_event_value(params)
        
        case value do
          {:clear, true} ->
            send(self(), {:quick_filter_cleared, field})
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
  
  
  defp convert_to_atoms(list) when is_list(list) do
    Enum.map(list, fn
      item when is_binary(item) -> String.to_existing_atom(item)
      item -> item
    end)
  end
  defp convert_to_atoms(item) when is_binary(item), do: String.to_existing_atom(item)
  defp convert_to_atoms(other), do: other
  
  defp toggle_in_list(list, item) do
    if item in list do
      List.delete(list, item)
    else
      [item | list]
    end
  end

  # Column configuration
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

  defp default_visible_columns do
    column_config()
    |> Enum.filter(fn {_col, config} -> config.default_visible end)
    |> Enum.map(fn {col, _config} -> col end)
  end

  # Use LiveFilter's update_filter_url function with custom URL builder
  defp update_url_state(socket) do
    update_filter_url(socket,
      url_updater: fn socket, _opts ->
        pagination = %{
          page: socket.assigns.current_page,
          per_page: socket.assigns.per_page
        }

        params =
          UrlSerializer.update_params(
            %{},
            socket.assigns.filter_group,
            socket.assigns.current_sort,
            pagination
          )

        # Convert nested params to proper query string using UrlUtils
        query_string = if params == %{}, do: "", else: UrlUtils.flatten_and_encode_params(params)
        path = if query_string == "", do: "/todos", else: "/todos?#{query_string}"
        push_patch(socket, to: path)
      end
    )
  end

  # Convert filters to UI state - manual implementation for now
  defp convert_filters_to_ui_state(socket, filter_group) do
    # Initialize default values
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:selected_statuses, [])
      |> assign(:selected_assignees, [])
      |> assign(:date_range, nil)
      |> assign(:is_urgent, false)
      |> assign(:active_optional_filters, [])
      |> assign(:optional_filter_values, %{})

    # Extract values from filter_group
    socket =
      Enum.reduce(filter_group.filters, socket, fn filter, acc ->
        case filter do
          # Status filter
          %{field: :status, operator: :in, value: statuses} when is_list(statuses) ->
            assign(acc, :selected_statuses, convert_to_atoms(statuses))

          %{field: :status, operator: :equals, value: status} ->
            assign(acc, :selected_statuses, [convert_to_atoms(status)])

          # Assignee filter
          %{field: :assigned_to, operator: :in, value: assignees} when is_list(assignees) ->
            assign(acc, :selected_assignees, assignees)

          %{field: :assigned_to, operator: :equals, value: assignee} ->
            assign(acc, :selected_assignees, [assignee])

          # Date range filter
          %{field: :due_date, operator: :between, value: {start_date, end_date}} ->
            assign(acc, :date_range, {start_date, end_date})

          # Urgent filter
          %{field: :is_urgent, operator: operator, value: true}
          when operator in [:is_true, :equals] ->
            assign(acc, :is_urgent, true)

          # Search filter
          %{field: :_search, operator: :custom, value: search_query} ->
            assign(acc, :search_query, search_query)

          # Optional filters
          %{field: field} when field not in [:status, :assigned_to, :due_date, :is_urgent, :_search] ->
            if field in get_optional_field_names() do
              current_active = acc.assigns.active_optional_filters
              current_values = acc.assigns.optional_filter_values

              acc
              |> assign(:active_optional_filters, [field | current_active])
              |> assign(:optional_filter_values, Map.put(current_values, field, filter.value))
            else
              acc
            end

          _ ->
            acc
        end
      end)

    socket
  end

  # Get list of optional field names for validation
  defp get_optional_field_names do
    optional_field_options()
    |> Enum.map(fn {field, _, _, _} -> field end)
  end
end
