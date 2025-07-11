defmodule LiveFilter.QuickFilters do
  @moduledoc """
  Composable filter builder functions for common patterns.

  This module provides simple, focused functions for creating filters.
  Each function returns a Filter struct that can be used individually
  or combined with others. There's no magic - just convenience functions
  that save you from writing boilerplate.

  ## Philosophy

  These are building blocks, not a framework. Use what you need,
  ignore what you don't, and write your own when these don't fit.

  ## Examples

      # Use individual builders
      search = QuickFilters.search_filter("user input")
      status = QuickFilters.multi_select_filter(:status, [:active, :pending])
      date = QuickFilters.date_range_filter(:created_at, {~D[2025-01-01], ~D[2025-01-31]})
      
      # Combine into a filter group
      filter_group = %FilterGroup{
        filters: [search, status, date] |> Enum.reject(&is_nil/1)
      }
      
      # Or use in your own functions
      def build_my_filters(params) do
        [
          params["q"] && QuickFilters.search_filter(params["q"]),
          params["urgent"] == "true" && QuickFilters.boolean_filter(:is_urgent, true),
          # ... your custom logic
        ]
        |> Enum.reject(&is_nil/1)
      end
  """

  alias LiveFilter.Filter

  @doc """
  Create a search filter.

  By default creates a virtual `_search` filter that your application
  can expand to search multiple fields. You can customize everything.

  ## Options

    * `:field` - Field name (default: `:_search`)
    * `:operator` - Operator to use (default: `:custom`)
    * `:type` - Field type (default: `:string`)
    * `:min_length` - Minimum query length to create filter (default: 0)
    * `:trim` - Whether to trim whitespace (default: true)

  ## Examples

      # Simple search
      QuickFilters.search_filter("user query")
      
      # Search specific field
      QuickFilters.search_filter("john", field: :author_name, operator: :contains)
      
      # Require minimum length
      QuickFilters.search_filter(query, min_length: 3)

  Returns nil if query is empty or below min_length.
  """
  def search_filter(query, opts \\ []) when is_binary(query) do
    field = Keyword.get(opts, :field, :_search)
    operator = Keyword.get(opts, :operator, :custom)
    type = Keyword.get(opts, :type, :string)
    min_length = Keyword.get(opts, :min_length, 0)
    trim = Keyword.get(opts, :trim, true)

    query = if trim, do: String.trim(query), else: query

    if query != "" && String.length(query) >= min_length do
      %Filter{
        field: field,
        operator: operator,
        value: query,
        type: type
      }
    else
      nil
    end
  end

  @doc """
  Create a multi-select filter for enum fields.

  ## Options

    * `:operator` - Operator to use (default: `:in` for lists, `:equals` for single values)
    * `:type` - Field type (default: `:enum`)
    * `:reject_empty` - Whether to return nil for empty values (default: true)

  ## Examples

      # Multiple values
      QuickFilters.multi_select_filter(:status, [:active, :pending])
      
      # Single value (uses :equals operator)
      QuickFilters.multi_select_filter(:status, :active)
      
      # Force operator
      QuickFilters.multi_select_filter(:tags, ["urgent", "bug"], operator: :contains_all)
  """
  def multi_select_filter(field, values, opts \\ []) do
    type = Keyword.get(opts, :type, :enum)
    reject_empty = Keyword.get(opts, :reject_empty, true)

    cond do
      is_nil(values) && reject_empty ->
        nil

      is_list(values) && values == [] && reject_empty ->
        nil

      is_list(values) ->
        operator = Keyword.get(opts, :operator, :in)

        %Filter{
          field: field,
          operator: operator,
          value: values,
          type: type
        }

      true ->
        operator = Keyword.get(opts, :operator, :equals)

        %Filter{
          field: field,
          operator: operator,
          value: values,
          type: type
        }
    end
  end

  @doc """
  Create a date range filter.

  Handles both date tuples and preset strings.

  ## Options

    * `:operator` - Operator to use (default: `:between` for ranges, `:equals` for single dates)
    * `:type` - Field type (default: `:date`)
    * `:timezone` - Timezone for date calculations (default: "Etc/UTC")

  ## Examples

      # Date range
      QuickFilters.date_range_filter(:created_at, {~D[2025-01-01], ~D[2025-01-31]})
      
      # Single date
      QuickFilters.date_range_filter(:due_date, ~D[2025-01-15])
      
      # Preset (requires LiveFilter.DateUtils)
      QuickFilters.date_range_filter(:created_at, "last_30_days")
  """
  def date_range_filter(field, date_or_range, opts \\ []) do
    type = Keyword.get(opts, :type, :date)

    case date_or_range do
      nil ->
        nil

      {start_date, end_date} = range when not is_nil(start_date) and not is_nil(end_date) ->
        operator = Keyword.get(opts, :operator, :between)

        %Filter{
          field: field,
          operator: operator,
          value: range,
          type: type
        }

      %Date{} = date ->
        operator = Keyword.get(opts, :operator, :equals)

        %Filter{
          field: field,
          operator: operator,
          value: date,
          type: type
        }

      preset when is_binary(preset) ->
        # Try to parse preset if DateUtils is available
        if Code.ensure_loaded?(LiveFilter.DateUtils) do
          case apply(LiveFilter.DateUtils, :parse_date_range, [preset, type]) do
            nil -> nil
            parsed_range -> date_range_filter(field, parsed_range, opts)
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Create a boolean filter.

  ## Options

    * `:operator` - Operator to use (default: `:equals`)
    * `:true_only` - Only create filter for true values (default: false)

  ## Examples

      # Simple boolean
      QuickFilters.boolean_filter(:is_active, true)
      
      # Only filter when true
      QuickFilters.boolean_filter(:is_urgent, value, true_only: true)
  """
  def boolean_filter(field, value, opts \\ []) do
    operator = Keyword.get(opts, :operator, :equals)
    true_only = Keyword.get(opts, :true_only, false)

    cond do
      true_only && value != true ->
        nil

      is_boolean(value) ->
        %Filter{
          field: field,
          operator: operator,
          value: value,
          type: :boolean
        }

      true ->
        nil
    end
  end

  @doc """
  Create a numeric filter.

  ## Options

    * `:operator` - Operator (default: `:equals`)
    * `:type` - `:integer` or `:float` (default: auto-detect)

  ## Examples

      # Exact value
      QuickFilters.numeric_filter(:price, 99.99)
      
      # Comparison
      QuickFilters.numeric_filter(:age, 21, operator: :greater_than_or_equal)
      
      # Range
      QuickFilters.numeric_filter(:score, {80, 100}, operator: :between)
  """
  def numeric_filter(field, value, opts \\ []) do
    operator = Keyword.get(opts, :operator, :equals)

    {value, type} =
      case value do
        {min, max} when is_number(min) and is_number(max) ->
          type = if is_integer(min) && is_integer(max), do: :integer, else: :float
          {{min, max}, type}

        num when is_integer(num) ->
          {num, :integer}

        num when is_float(num) ->
          {num, :float}

        _ ->
          {nil, nil}
      end

    if value do
      type = Keyword.get(opts, :type, type)

      %Filter{
        field: field,
        operator: operator,
        value: value,
        type: type
      }
    else
      nil
    end
  end

  @doc """
  Create an array/tags filter.

  ## Options

    * `:operator` - Operator (default: `:contains_any`)
    * `:type` - Field type (default: `:array`)

  ## Examples

      # Contains any
      QuickFilters.array_filter(:tags, ["urgent", "bug"])
      
      # Contains all
      QuickFilters.array_filter(:tags, ["urgent", "bug"], operator: :contains_all)
  """
  def array_filter(field, values, opts \\ []) when is_list(values) do
    operator = Keyword.get(opts, :operator, :contains_any)
    type = Keyword.get(opts, :type, :array)

    if values == [] do
      nil
    else
      %Filter{
        field: field,
        operator: operator,
        value: values,
        type: type
      }
    end
  end

  @doc """
  Build multiple filters from a parameter map.

  This is a convenience function for handling common parameter patterns.

  ## Options

    * `:definitions` - List of {param_key, builder_fun} tuples
    * `:prefix` - Parameter key prefix to strip

  ## Examples

      params = %{
        "q" => "search term",
        "status" => ["active", "pending"],
        "urgent" => "true"
      }
      
      filters = QuickFilters.from_params(params,
        definitions: [
          {"q", fn v -> search_filter(v) end},
          {"status", fn v -> multi_select_filter(:status, v) end},
          {"urgent", fn "true" -> boolean_filter(:urgent, true); _ -> nil end}
        ]
      )
  """
  def from_params(params, opts \\ []) when is_map(params) do
    definitions = Keyword.get(opts, :definitions, [])
    prefix = Keyword.get(opts, :prefix, "")

    Enum.reduce(definitions, [], fn {param_key, builder}, acc ->
      key = if prefix != "", do: "#{prefix}#{param_key}", else: param_key

      case Map.get(params, key) do
        nil ->
          acc

        value ->
          case builder.(value) do
            nil -> acc
            filter -> [filter | acc]
          end
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Example event handler for search with debounce.

  This is just an example - implement your own based on your needs.
  """
  def example_search_handler(socket, query, opts \\ []) do
    debounce_ms = Keyword.get(opts, :debounce, 300)

    # Cancel previous timer if exists
    if timer = socket.assigns[:search_timer] do
      Process.cancel_timer(timer)
    end

    # Set new timer
    timer = Process.send_after(self(), {:apply_search, query}, debounce_ms)

    Phoenix.Component.assign(socket, search_timer: timer, search_query: query)
  end

  @doc """
  Example handler for multi-select toggle.

  This is just an example pattern.
  """
  def example_multi_select_handler(socket, field, value, :toggle) do
    current = socket.assigns[field] || []

    updated =
      if value in current do
        List.delete(current, value)
      else
        [value | current]
      end

    Phoenix.Component.assign(socket, field, updated)
  end

  def example_multi_select_handler(socket, field, values, :replace) do
    Phoenix.Component.assign(socket, field, values)
  end
end
