defmodule LiveFilter.Filter do
  @moduledoc """
  Represents an individual filter with field, operator, value, and type.
  """

  defstruct [:field, :operator, :value, :type]

  @type t :: %__MODULE__{
          field: atom(),
          operator: atom(),
          value: any(),
          type: atom()
        }

  @doc """
  Creates a new filter struct.
  """
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end
end

defmodule LiveFilter.FilterGroup do
  @moduledoc """
  Represents a group of filters with a conjunction (AND/OR) and can contain nested groups.
  """

  defstruct filters: [], groups: [], conjunction: :and

  @type t :: %__MODULE__{
          filters: [LiveFilter.Filter.t()],
          groups: [t()],
          conjunction: :and | :or
        }

  @doc """
  Creates a new filter group.
  """
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Adds a filter to the group.
  """
  def add_filter(%__MODULE__{} = group, %LiveFilter.Filter{} = filter) do
    %{group | filters: group.filters ++ [filter]}
  end

  @doc """
  Removes a filter from the group by index.
  """
  def remove_filter(%__MODULE__{} = group, index) when is_integer(index) do
    %{group | filters: List.delete_at(group.filters, index)}
  end

  @doc """
  Updates a filter in the group by index.
  """
  def update_filter(%__MODULE__{} = group, index, %LiveFilter.Filter{} = filter) when is_integer(index) do
    %{group | filters: List.replace_at(group.filters, index, filter)}
  end

  @doc """
  Adds a nested group.
  """
  def add_group(%__MODULE__{} = group, %__MODULE__{} = nested_group) do
    %{group | groups: group.groups ++ [nested_group]}
  end

  @doc """
  Checks if the group has any active filters.
  """
  def has_filters?(%__MODULE__{} = group) do
    Enum.any?(group.filters) || Enum.any?(group.groups, &has_filters?/1)
  end

  @doc """
  Counts total filters including nested groups.
  """
  def count_filters(%__MODULE__{} = group) do
    filter_count = length(group.filters)
    nested_count = Enum.sum(Enum.map(group.groups, &count_filters/1))
    filter_count + nested_count
  end
end