defmodule TodoAppWeb.TodoLive.Index do
  use TodoAppWeb, :live_view

  alias TodoApp.Todos
  alias TodoAppUi.{Badge, Button}
  alias LiveFilter.{FilterGroup, UrlSerializer, Sort}
  alias TodoAppWeb.Components.{LiveFilterLayout, FilterToolbar, PaginationHelper}
  import LiveFilter.Components.SortableHeader

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filter_group, %FilterGroup{})
      |> assign(:field_options, field_options())
      |> assign(:search_query, "")
      |> assign(:selected_statuses, [])
      |> assign(:selected_assignees, [])
      |> assign(:date_range, nil)
      |> assign(:is_urgent, false)
      |> assign(:active_optional_filters, [])  # Track which optional filters are active
      |> assign(:optional_filter_values, %{})  # Store values for optional filters
      |> assign(:current_sort, Sort.new(:due_date, :asc))  # Default sort by due date
      |> assign(:view_type, "table")
      |> assign(:per_page, 10)
      |> assign(:current_page, 1)
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)
      |> assign(:status_counts, %{})
      |> assign(:column_config, column_config())
      |> assign(:visible_columns, default_visible_columns())
      |> stream(:todos, [])  # Initialize empty stream, will be populated in handle_params
    
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_group = UrlSerializer.from_params(params)
    sorts = UrlSerializer.sorts_from_params(params)
    pagination = UrlSerializer.pagination_from_params(params)
    
    # Use parsed sort or keep the current/default sort
    current_sort = sorts || socket.assigns.current_sort
    
    socket =
      socket
      |> assign(:filter_group, filter_group)
      |> assign(:current_sort, current_sort)
      |> assign(:current_page, pagination.page)
      |> assign(:per_page, pagination.per_page)
      |> restore_quick_filter_ui_state(filter_group)
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
      |> load_todos()  # Reload todos to reset the stream
    {:noreply, socket}
  end



  @impl true
  def handle_event("toggle_command_filters", _params, socket) do
    # TODO: Implement command palette
    {:noreply, put_flash(socket, :info, "Command filters coming soon!")}
  end

  # Handle dynamic quick filter events
  def handle_event("quick_filter_" <> field_changed, params, socket) do
    field = field_changed
    |> String.replace("_changed", "")
    |> String.to_existing_atom()
    
    value = case params do
      %{"toggle" => val} ->
        # For multi-select array fields
        current = Map.get(socket.assigns.optional_filter_values, field, [])
        if val in current do
          List.delete(current, val)
        else
          [val | current]
        end
        
      %{"select" => val} ->
        # For single-select enum fields
        val
        
      %{"clear" => true} ->
        # Clear the filter
        case get_field_type(field, socket) do
          :array -> []
          _ -> nil
        end
        
      _ ->
        nil
    end
    
    send(self(), {:quick_filter_changed, field, value})
    {:noreply, socket}
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
    updated = if status in selected do
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
    updated = if assignee in selected do
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
    new_sort = if current_sort && current_sort.field == field_atom do
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
      |> assign(:current_page, 1)  # Reset to first page when clearing filters
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
      %{label: label} -> label
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
  
  defp get_field_type(field, _socket) do
    case get_field_config(field) do
      {_, _, type, _} -> type
      _ -> :string
    end
  end

  defp load_todos(socket) do
    # Use database-level pagination for better performance
    pagination_result = Todos.list_todos_paginated(
      socket.assigns.filter_group,
      socket.assigns.current_sort,
      page: socket.assigns.current_page,
      per_page: socket.assigns.per_page
    )
    
    # Calculate counts for status filters
    status_counts = Todos.count_by_status(socket.assigns.filter_group, socket.assigns.current_sort)
    
    socket
    |> stream(:todos, pagination_result.todos, reset: true)
    |> assign(:todo_count, length(pagination_result.todos))
    |> assign(:total_count, pagination_result.total_count)
    |> assign(:total_pages, pagination_result.total_pages)
    |> assign(:status_counts, status_counts)
  end
  
  defp apply_quick_filters(socket) do
    # Build filters from quick filter selections
    filters = []
    groups = []
    
    # Add search filter as a nested group for OR search across multiple fields
    {filters, groups} = if socket.assigns.search_query != "" do
      # Trim whitespace and normalize the search query
      normalized_query = String.trim(socket.assigns.search_query)
      
      if normalized_query != "" do
        # Get search configuration - can be customized per implementation
        search_config = search_field_config()
        
        # Create filters for each searchable field with their configured operators
        search_filters = Enum.map(search_config, fn {field, operator} ->
          %LiveFilter.Filter{
            field: field,
            operator: operator,
            value: normalized_query,
            type: :string
          }
        end)
        
        # Create a nested filter group for OR search across fields
        search_group = %LiveFilter.FilterGroup{
          filters: search_filters,
          conjunction: :or
        }
        
        # Add the search group to groups list
        {filters, [search_group | groups]}
      else
        {filters, groups}
      end
    else
      {filters, groups}
    end
    
    # Add status filters
    filters = if socket.assigns.selected_statuses != [] do
      status_filter = %LiveFilter.Filter{
        field: :status,
        operator: :in,
        value: socket.assigns.selected_statuses,
        type: :enum
      }
      [status_filter | filters]
    else
      filters
    end
    
    # Add assignee filters
    filters = if socket.assigns.selected_assignees != [] do
      assignee_filter = %LiveFilter.Filter{
        field: :assigned_to,
        operator: :in,
        value: socket.assigns.selected_assignees,
        type: :enum
      }
      [assignee_filter | filters]
    else
      filters
    end
    
    # Add date range filter
    filters = if socket.assigns.date_range do
      # Due date is stored as :date type in schema
      date_filter = %LiveFilter.Filter{
        field: :due_date,
        operator: :between,
        value: socket.assigns.date_range,
        type: :date
      }
      [date_filter | filters]
    else
      filters
    end
    
    # Add urgent filter
    filters = if socket.assigns.is_urgent do
      urgent_filter = %LiveFilter.Filter{
        field: :is_urgent,
        operator: :equals,
        value: true,
        type: :boolean
      }
      [urgent_filter | filters]
    else
      filters
    end
    
    # Add optional filters
    filters = Enum.reduce(socket.assigns.active_optional_filters, filters, fn field, acc ->
      value = Map.get(socket.assigns.optional_filter_values, field)
      if value != nil && value != "" && value != [] do
        {_field, _label, type, _opts} = get_field_config(field)
        operator = get_default_operator_for_type(type)
        
        filter = %LiveFilter.Filter{
          field: field,
          operator: operator,
          value: value,
          type: type
        }
        [filter | acc]
      else
        acc
      end
    end)
    
    # Update filter group with both filters and nested groups
    filter_group = %FilterGroup{
      filters: filters, 
      groups: groups,
      conjunction: :and
    }
    
    socket
    |> assign(:filter_group, filter_group)
    |> load_todos()
    |> update_url_state()
  end

  defp field_options do
    [
      {:title, "Title", :string, []},
      {:description, "Description", :string, []},
      {:status, "Status", :enum, []},
      {:assigned_to, "Assignee", :enum, []},
      {:project, "Project", :enum, []},
      {:due_date, "Due Date", :date, []},
      {:is_urgent, "Urgent", :boolean, []},
      {:tags, "Tags", :array, []},
      {:estimated_hours, "Estimated Hours", :float, []},
      {:actual_hours, "Actual Hours", :float, []},
      {:complexity, "Complexity", :integer, []}
    ]
  end

  defp optional_field_options do
    # Define which fields are available as optional filters
    # Format: {field, label, type, options}
    [
      {:project, "Project", :enum, %{
        icon: "hero-folder",
        options: TodoApp.Todos.Todo.project_options() |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
      }},
      {:tags, "Tags", :array, %{
        icon: "hero-tag",
        options: TodoApp.Todos.Todo.tag_options() |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
      }},
      {:estimated_hours, "Est. Hours", :float, %{icon: "hero-clock"}},
      {:actual_hours, "Actual Hours", :float, %{icon: "hero-check-circle"}},
      {:complexity, "Complexity", :integer, %{icon: "hero-chart-bar"}},
      {:inserted_at, "Created", :utc_datetime, %{icon: "hero-clock"}}
    ]
  end


  defp get_field_config(field) do
    Enum.find(optional_field_options(), fn {f, _, _, _} -> f == field end) ||
    Enum.find(field_options(), fn {f, _, _, _} -> f == field end) ||
    {field, Phoenix.Naming.humanize(field), :string, %{}}
  end

  defp get_default_operator_for_type(type) do
    case type do
      :string -> :contains
      :integer -> :equals
      :float -> :equals
      :boolean -> :equals
      :date -> :between
      :datetime -> :between
      :utc_datetime -> :between
      :naive_datetime -> :between
      :enum -> :equals
      :array -> :contains_any
      _ -> :equals
    end
  end

  # Configuration for which fields to search and their operators
  # Returns a list of {field, operator} tuples
  defp search_field_config do
    [
      {:title, :contains},
      {:description, :contains}
    ]
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

  # Helper function to update URL with current state
  defp update_url_state(socket) do
    pagination = %{
      page: socket.assigns.current_page,
      per_page: socket.assigns.per_page
    }
    
    params = UrlSerializer.update_params(
      %{},
      socket.assigns.filter_group,
      socket.assigns.current_sort,
      pagination
    )
    
    push_patch(socket, to: ~p"/todos?#{params}")
  end

  # Helper function to restore quick filter UI state from parsed filter_group
  defp restore_quick_filter_ui_state(socket, filter_group) do
    # Initialize default values
    socket = socket
    |> assign(:search_query, "")
    |> assign(:selected_statuses, [])
    |> assign(:selected_assignees, [])
    |> assign(:date_range, nil)
    |> assign(:is_urgent, false)
    |> assign(:active_optional_filters, [])
    |> assign(:optional_filter_values, %{})

    # Extract values from filter_group
    socket = Enum.reduce(filter_group.filters, socket, fn filter, acc ->
      case filter do
        # Status filter (can be single value or list)
        %{field: :status, operator: :in, value: statuses} when is_list(statuses) ->
          assign(acc, :selected_statuses, statuses)
        %{field: :status, operator: :equals, value: status} ->
          assign(acc, :selected_statuses, [status])
        
        # Assignee filter (can be single value or list)
        %{field: :assigned_to, operator: :in, value: assignees} when is_list(assignees) ->
          assign(acc, :selected_assignees, assignees)
        %{field: :assigned_to, operator: :equals, value: assignee} ->
          assign(acc, :selected_assignees, [assignee])
        
        # Date range filter
        %{field: :due_date, operator: :between, value: {start_date, end_date}} ->
          assign(acc, :date_range, {start_date, end_date})
        
        # Urgent filter (can be :is_true or :equals)
        %{field: :is_urgent, operator: operator, value: true} when operator in [:is_true, :equals] ->
          assign(acc, :is_urgent, true)
        
        # Optional filters
        %{field: field} when field not in [:status, :assigned_to, :due_date, :is_urgent] ->
          # Check if this is a known optional field
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

    # Extract search query from nested OR groups
    search_query = extract_search_query_from_groups(filter_group.groups)
    assign(socket, :search_query, search_query)
  end

  # Extract search query from OR groups (title/description contains filters)
  defp extract_search_query_from_groups(groups) do
    Enum.find_value(groups, "", fn group ->
      if group.conjunction == :or do
        # Look for title or description contains filters
        Enum.find_value(group.filters, fn filter ->
          case filter do
            %{field: field, operator: :contains, value: value} when field in [:title, :description] ->
              value
            _ ->
              nil
          end
        end)
      end
    end)
  end

  # Get list of optional field names for validation
  defp get_optional_field_names do
    optional_field_options()
    |> Enum.map(fn {field, _, _, _} -> field end)
  end
end
