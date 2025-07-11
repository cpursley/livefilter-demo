defmodule LiveFilter.UrlSerializer do
  @moduledoc """
  Handles serialization and deserialization of filter configurations to/from URL parameters.
  
  Uses a flat parameter structure similar to Backpex:
  - Simple filters: filters[field_name]=value
  - Range filters: filters[field_name][start]=X&filters[field_name][end]=Y  
  - Array filters: filters[field_name][]=value1&filters[field_name][]=value2
  - Operators stored separately: filters[field_name][operator]=contains
  
  Sort parameters:
  - Single sort: sort[field]=due_date&sort[direction]=desc
  - Multiple sorts: sort[0][field]=priority&sort[0][direction]=desc&sort[1][field]=due_date
  """

  alias LiveFilter.Sort

  @doc """
  Updates URL parameters with filter values.
  """
  def update_params(params, %LiveFilter.FilterGroup{} = filter_group) do
    filter_params = build_filter_params(filter_group)
    
    if filter_params == %{} do
      Map.delete(params, "filters")
    else
      Map.put(params, "filters", filter_params)
    end
  end

  @doc """
  Updates URL parameters with filter and sort values.
  """
  def update_params(params, %LiveFilter.FilterGroup{} = filter_group, sorts) do
    params
    |> update_params(filter_group)
    |> update_sort_params(sorts)
  end

  @doc """
  Updates URL parameters with filter, sort, and pagination values.
  """
  def update_params(params, %LiveFilter.FilterGroup{} = filter_group, sorts, pagination) do
    params
    |> update_params(filter_group)
    |> update_sort_params(sorts)
    |> update_pagination_params(pagination)
  end

  @doc """
  Updates URL parameters with sort values only.
  """
  def update_sort_params(params, nil), do: Map.delete(params, "sort")
  def update_sort_params(params, []), do: Map.delete(params, "sort")
  
  def update_sort_params(params, %Sort{} = sort) do
    Map.put(params, "sort", %{
      "field" => to_string(sort.field),
      "direction" => to_string(sort.direction)
    })
  end
  
  def update_sort_params(params, sorts) when is_list(sorts) do
    sort_params = sorts
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {sort, index}, acc ->
      Map.put(acc, to_string(index), %{
        "field" => to_string(sort.field),
        "direction" => to_string(sort.direction)
      })
    end)
    
    if sort_params == %{} do
      Map.delete(params, "sort")
    else
      Map.put(params, "sort", sort_params)
    end
  end

  @doc """
  Updates URL parameters with pagination values.
  """
  def update_pagination_params(params, nil), do: params
  def update_pagination_params(params, pagination) when is_map(pagination) do
    page = Map.get(pagination, :page, 1)
    per_page = Map.get(pagination, :per_page, 10)
    
    params
    |> put_if_not_default(page, 1, "page")
    |> put_if_not_default(per_page, 10, "per_page")
  end

  defp put_if_not_default(params, value, default, key) do
    if value == default do
      Map.delete(params, key)
    else
      Map.put(params, key, to_string(value))
    end
  end

  @doc """
  Extracts filter group from URL parameters.
  """
  def from_params(params) do
    filters_map = params["filters"] || %{}
    
    # Separate regular filters from groups
    {groups_map, filters_map} = filters_map
    |> Enum.split_with(fn {key, _value} -> String.starts_with?(key, "group_") end)
    |> then(fn {groups, filters} -> {Map.new(groups), Map.new(filters)} end)
    
    # Parse regular filters
    filters = filters_map
    |> Enum.map(&parse_filter_entry/1)
    |> Enum.reject(&is_nil/1)
    
    # Parse nested groups
    groups = groups_map
    |> Enum.sort_by(fn {key, _} -> 
      key |> String.replace("group_", "") |> String.to_integer()
    end)
    |> Enum.map(fn {_key, group_data} -> parse_group_entry(group_data) end)
    |> Enum.reject(&is_nil/1)
    
    %LiveFilter.FilterGroup{
      filters: filters,
      groups: groups,
      conjunction: :and
    }
  end
  
  defp parse_group_entry(%{"conjunction" => conjunction, "filters" => filters_map}) do
    conjunction_atom = String.to_existing_atom(conjunction)
    
    filters = filters_map
    |> Enum.sort_by(fn {index, _} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, filter_data} -> 
      parse_simple_filter(filter_data)
    end)
    |> Enum.reject(&is_nil/1)
    
    %LiveFilter.FilterGroup{
      filters: filters,
      groups: [],
      conjunction: conjunction_atom
    }
  end
  defp parse_group_entry(_), do: nil
  
  defp parse_simple_filter(%{"field" => field, "operator" => operator, "value" => value, "type" => type}) do
    %LiveFilter.Filter{
      field: String.to_existing_atom(field),
      operator: String.to_existing_atom(operator),
      value: deserialize_value(value),
      type: String.to_existing_atom(type)
    }
  end
  defp parse_simple_filter(_), do: nil

  @doc """
  Extracts sort configuration from URL parameters.
  
  Returns a list of Sort structs or nil if no sort params.
  """
  def sorts_from_params(params) do
    case params["sort"] do
      nil -> 
        nil
        
      %{"field" => field, "direction" => direction} ->
        # Single sort format
        Sort.new(
          String.to_existing_atom(field),
          String.to_existing_atom(direction)
        )
        
      sort_map when is_map(sort_map) ->
        # Multiple sorts format
        sort_map
        |> Enum.sort_by(fn {index, _} -> String.to_integer(index) end)
        |> Enum.map(fn {_index, %{"field" => field, "direction" => direction}} ->
          Sort.new(
            String.to_existing_atom(field),
            String.to_existing_atom(direction)
          )
        end)
        
      _ -> 
        nil
    end
  end

  @doc """
  Extracts pagination configuration from URL parameters.
  
  Returns a map with :page and :per_page keys, or defaults.
  """
  def pagination_from_params(params) do
    page = case params["page"] do
      nil -> 1
      page_str -> 
        case Integer.parse(page_str) do
          {page, ""} when page > 0 -> page
          _ -> 1
        end
    end
    
    per_page = case params["per_page"] do
      nil -> 10
      per_page_str -> 
        case Integer.parse(per_page_str) do
          {per_page, ""} when per_page > 0 and per_page <= 100 -> per_page
          _ -> 10
        end
    end
    
    %{page: page, per_page: per_page}
  end

  defp build_filter_params(%LiveFilter.FilterGroup{filters: filters, groups: groups}) do
    filter_params = filters
    |> Enum.reduce(%{}, fn filter, acc ->
      add_filter_to_params(acc, filter)
    end)
    
    # Handle nested groups
    if groups != [] do
      groups_params = groups
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {group, index}, acc ->
        group_params = build_group_params(group)
        Map.put(acc, "group_#{index}", group_params)
      end)
      
      Map.merge(filter_params, groups_params)
    else
      filter_params
    end
  end
  
  defp build_group_params(%LiveFilter.FilterGroup{filters: filters, conjunction: conjunction}) do
    %{
      "conjunction" => to_string(conjunction),
      "filters" => filters
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {filter, index}, acc ->
        Map.put(acc, to_string(index), %{
          "field" => to_string(filter.field),
          "operator" => to_string(filter.operator),
          "value" => serialize_value(filter.value),
          "type" => to_string(filter.type)
        })
      end)
    }
  end

  defp add_filter_to_params(params, %LiveFilter.Filter{field: field, operator: operator, value: value, type: type}) do
    field_str = to_string(field)
    
    case {operator, value} do
      {:between, {start_val, end_val}} ->
        params
        |> deep_put([field_str, "start"], serialize_value(start_val))
        |> deep_put([field_str, "end"], serialize_value(end_val))
        |> deep_put([field_str, "operator"], to_string(operator))
        |> deep_put([field_str, "type"], to_string(type))
      
      {_, value} when is_list(value) ->
        filter_map = %{
          "values" => Enum.map(value, &serialize_value/1),
          "operator" => to_string(operator),
          "type" => to_string(type)
        }
        Map.put(params, field_str, filter_map)
      
      {_, nil} ->
        params
      
      {_, value} ->
        Map.put(params, field_str, %{
          "value" => serialize_value(value),
          "operator" => to_string(operator),
          "type" => to_string(type)
        })
    end
  end

  defp parse_filter_entry({field_str, value}) when is_map(value) do
    field = String.to_existing_atom(field_str)
    
    cond do
      # Range filter with start/end
      Map.has_key?(value, "start") or Map.has_key?(value, "end") ->
        %LiveFilter.Filter{
          field: field,
          operator: parse_operator(value["operator"], :between),
          value: {deserialize_value(value["start"]), deserialize_value(value["end"])},
          type: parse_type(value["type"])
        }
      
      # Array filter with values
      Map.has_key?(value, "values") ->
        %LiveFilter.Filter{
          field: field,
          operator: parse_operator(value["operator"], :in),
          value: Enum.map(value["values"], &deserialize_value/1),
          type: parse_type(value["type"], :array)
        }
        
      # Regular filter with value
      Map.has_key?(value, "value") ->
        %LiveFilter.Filter{
          field: field,
          operator: parse_operator(value["operator"], :equals),
          value: deserialize_value(value["value"]),
          type: parse_type(value["type"])
        }
      
      true ->
        nil
    end
  end

  defp parse_filter_entry({field_str, values}) when is_list(values) do
    field = String.to_existing_atom(field_str)
    
    %LiveFilter.Filter{
      field: field,
      operator: :in,
      value: Enum.map(values, &deserialize_value/1),
      type: :array
    }
  end

  defp parse_filter_entry({field_str, value}) do
    field = String.to_existing_atom(field_str)
    
    # Try to infer the type based on the field
    type = infer_type(field, value)
    
    %LiveFilter.Filter{
      field: field,
      operator: :equals,
      value: deserialize_value(value),
      type: type
    }
  end

  defp parse_operator(nil, default), do: default
  defp parse_operator(operator_str, _default) when is_binary(operator_str) do
    String.to_existing_atom(operator_str)
  end
  defp parse_operator(_, default), do: default

  defp parse_type(type_str), do: parse_type(type_str, :string)
  
  defp parse_type(nil, default), do: default
  defp parse_type(type_str, _default) when is_binary(type_str) do
    String.to_existing_atom(type_str)
  end
  defp parse_type(_, default), do: default

  defp serialize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp serialize_value(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp serialize_value(value) when is_atom(value), do: to_string(value)
  defp serialize_value(value), do: value

  defp deserialize_value(nil), do: nil
  defp deserialize_value("true"), do: true
  defp deserialize_value("false"), do: false
  defp deserialize_value(value) when is_binary(value) do
    # Try to parse as date
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> value
    end
  end
  defp deserialize_value(value), do: value

  defp infer_type(field, _value) do
    # This should ideally come from field_options, but for now we'll use defaults
    case field do
      :due_date -> :date
      :completed_at -> :datetime
      :is_urgent -> :boolean
      :is_recurring -> :boolean
      :estimated_hours -> :float
      :actual_hours -> :float
      :complexity -> :integer
      :priority -> :enum
      :status -> :enum
      :tags -> :array
      _ -> :string
    end
  end

  # Helper to handle nested map updates
  defp deep_put(map, [key], value) do
    Map.put(map, key, value)
  end
  
  defp deep_put(map, [key | rest], value) do
    sub_map = Map.get(map, key, %{})
    Map.put(map, key, deep_put(sub_map, rest, value))
  end
end