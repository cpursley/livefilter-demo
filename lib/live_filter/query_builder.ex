defmodule LiveFilter.QueryBuilder do
  @moduledoc """
  Converts filter configurations to Ecto queries using dynamic query building.
  Supports both filtering and sorting operations.
  """

  import Ecto.Query
  alias LiveFilter.Sort

  @doc """
  Builds an Ecto query from a filter group.
  """
  def build_query(query, %LiveFilter.FilterGroup{} = filter_group) do
    dynamic = build_dynamic(filter_group)

    if dynamic do
      where(query, ^dynamic)
    else
      query
    end
  end

  @doc """
  Applies sorting to a query.

  ## Examples

      # Single sort
      apply_sort(query, %Sort{field: :due_date, direction: :asc})
      
      # Multiple sorts (applied in order)
      apply_sort(query, [
        %Sort{field: :priority, direction: :desc},
        %Sort{field: :due_date, direction: :asc}
      ])
  """
  def apply_sort(query, nil), do: query
  def apply_sort(query, []), do: query

  def apply_sort(query, %Sort{} = sort) do
    apply_sort(query, [sort])
  end

  def apply_sort(query, sorts) when is_list(sorts) do
    Enum.reduce(sorts, query, fn %Sort{field: field, direction: direction}, acc ->
      order_by(acc, [t], [{^direction, field(t, ^field)}])
    end)
  end

  defp build_dynamic(%LiveFilter.FilterGroup{
         filters: filters,
         groups: groups,
         conjunction: conjunction
       }) do
    filter_dynamics = Enum.map(filters, &build_filter_dynamic/1)
    group_dynamics = Enum.map(groups, &build_dynamic/1)

    all_dynamics = (filter_dynamics ++ group_dynamics) |> Enum.reject(&is_nil/1)

    case all_dynamics do
      [] ->
        nil

      [single] ->
        single

      multiple ->
        combine_dynamics(multiple, conjunction)
    end
  end

  defp build_filter_dynamic(%LiveFilter.Filter{
         field: field,
         operator: operator,
         value: value,
         type: type
       }) do
    # Skip filters with nil values unless the operator specifically handles nil
    if value == nil and operator not in [:is_empty, :is_not_empty] do
      nil
    else
      build_operator_dynamic(operator, field, value, type)
    end
  end

  defp build_operator_dynamic(operator, field, value, type) do
    case operator do
      :equals ->
        if value == nil do
          dynamic([t], is_nil(field(t, ^field)))
        else
          dynamic([t], field(t, ^field) == ^value)
        end

      :not_equals ->
        if value == nil do
          dynamic([t], not is_nil(field(t, ^field)))
        else
          dynamic([t], field(t, ^field) != ^value)
        end

      :contains ->
        pattern = "%#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :not_contains ->
        pattern = "%#{value}%"
        dynamic([t], not ilike(field(t, ^field), ^pattern))

      :starts_with ->
        pattern = "#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :ends_with ->
        pattern = "%#{value}"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :is_empty ->
        case type do
          t when t in [:string, :text] ->
            dynamic([t], is_nil(field(t, ^field)) or field(t, ^field) == "")

          t when t in [:array, :multi_select] ->
            dynamic([t], is_nil(field(t, ^field)) or field(t, ^field) == [])

          _ ->
            dynamic([t], is_nil(field(t, ^field)))
        end

      :is_not_empty ->
        case type do
          t when t in [:string, :text] ->
            dynamic([t], not is_nil(field(t, ^field)) and field(t, ^field) != "")

          t when t in [:array, :multi_select] ->
            dynamic([t], not is_nil(field(t, ^field)) and field(t, ^field) != [])

          _ ->
            dynamic([t], not is_nil(field(t, ^field)))
        end

      :greater_than ->
        dynamic([t], field(t, ^field) > ^value)

      :less_than ->
        dynamic([t], field(t, ^field) < ^value)

      :greater_than_or_equal ->
        dynamic([t], field(t, ^field) >= ^value)

      :less_than_or_equal ->
        dynamic([t], field(t, ^field) <= ^value)

      :between ->
        case value do
          {min_val, max_val} ->
            dynamic([t], field(t, ^field) >= ^min_val and field(t, ^field) <= ^max_val)

          _ ->
            nil
        end

      :is_true ->
        dynamic([t], field(t, ^field) == true)

      :is_false ->
        dynamic([t], field(t, ^field) == false)

      :before ->
        dynamic([t], field(t, ^field) < ^value)

      :after ->
        dynamic([t], field(t, ^field) > ^value)

      :on_or_before ->
        dynamic([t], field(t, ^field) <= ^value)

      :on_or_after ->
        dynamic([t], field(t, ^field) >= ^value)

      :in ->
        dynamic([t], field(t, ^field) in ^value)

      :not_in ->
        dynamic([t], field(t, ^field) not in ^value)

      :contains_any ->
        # PostgreSQL array overlap operator
        dynamic([t], fragment("? && ?", field(t, ^field), ^value))

      :contains_all ->
        # PostgreSQL array contains operator
        dynamic([t], fragment("? @> ?", field(t, ^field), ^value))

      :not_contains_any ->
        dynamic([t], not fragment("? && ?", field(t, ^field), ^value))

      :matches ->
        pattern = "%#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      _ ->
        nil
    end
  end

  defp combine_dynamics(dynamics, :and) do
    IO.inspect(length(dynamics), label: "Combining AND dynamics count")

    Enum.reduce(dynamics, fn dynamic, acc ->
      IO.puts("Adding another AND condition")
      dynamic([t], ^acc and ^dynamic)
    end)
  end

  defp combine_dynamics(dynamics, :or) do
    Enum.reduce(dynamics, fn dynamic, acc ->
      dynamic([t], ^acc or ^dynamic)
    end)
  end
end
