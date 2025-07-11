defmodule TodoApp.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias TodoApp.Repo

  alias TodoApp.Todos.Todo

  @doc """
  Returns the list of todos.

  ## Examples

      iex> list_todos()
      [%Todo{}, ...]
      
      iex> list_todos(filter_group, [%LiveFilter.Sort{field: :due_date, direction: :asc}])
      [%Todo{}, ...]

  """
  def list_todos(filter_group \\ nil, sorts \\ nil) do
    Todo
    |> apply_filters(filter_group)
    |> apply_sorts(sorts)
    |> Repo.all()
  end

  @doc """
  Returns paginated todos with metadata.

  ## Examples

      iex> list_todos_paginated(filter_group, sorts, page: 1, per_page: 10)
      %{
        todos: [%Todo{}, ...],
        total_count: 150,
        page: 1,
        per_page: 10,
        total_pages: 15
      }

  """
  def list_todos_paginated(filter_group \\ nil, sorts \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    base_query =
      Todo
      |> apply_filters(filter_group)
      |> apply_sorts(sorts)

    # Get total count before pagination
    total_count = Repo.aggregate(base_query, :count, :id)

    # Apply pagination
    todos =
      base_query
      |> apply_pagination(page, per_page)
      |> Repo.all()

    total_pages = ceil(total_count / per_page)

    %{
      todos: todos,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
  end

  @doc """
  Returns total count of todos matching the filter.
  """
  def count_todos(filter_group \\ nil) do
    Todo
    |> apply_filters(filter_group)
    |> Repo.aggregate(:count, :id)
  end

  defp apply_filters(query, nil), do: query

  defp apply_filters(query, filter_group) do
    # Check if there's a special _search filter
    {search_filters, regular_filters} =
      Enum.split_with(filter_group.filters, fn filter ->
        filter.field == :_search
      end)

    # Build a new filter group with search filters expanded
    expanded_filters =
      case search_filters do
        [%{value: search_term}] ->
          # Expand search into OR conditions for title and description
          search_group = %LiveFilter.FilterGroup{
            filters: [
              %LiveFilter.Filter{
                field: :title,
                operator: :contains,
                value: search_term,
                type: :string
              },
              %LiveFilter.Filter{
                field: :description,
                operator: :contains,
                value: search_term,
                type: :string
              }
            ],
            conjunction: :or
          }

          {regular_filters, [search_group]}

        _ ->
          {regular_filters, []}
      end

    # Create the final filter group
    final_filter_group = %LiveFilter.FilterGroup{
      filters: elem(expanded_filters, 0),
      groups: elem(expanded_filters, 1) ++ filter_group.groups,
      conjunction: filter_group.conjunction
    }

    LiveFilter.QueryBuilder.build_query(query, final_filter_group)
  end

  defp apply_sorts(query, nil), do: query

  defp apply_sorts(query, sorts) do
    LiveFilter.QueryBuilder.apply_sort(query, sorts)
  end

  defp apply_pagination(query, page, per_page) do
    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  @doc """
  Creates a todo.

  ## Examples

      iex> create_todo(%{field: value})
      {:ok, %Todo{}}

      iex> create_todo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_todo(attrs \\ %{}) do
    %Todo{}
    |> Todo.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns counts of todos grouped by status.
  Optionally accepts a filter_group to apply existing filters.
  """
  def count_by_status(filter_group \\ nil, _sorts \\ nil) do
    base_query =
      if filter_group do
        # Apply filters but exclude status filter to get counts for all statuses
        filters_without_status = Enum.reject(filter_group.filters, &(&1.field == :status))
        filter_group_without_status = %{filter_group | filters: filters_without_status}
        apply_filters(Todo, filter_group_without_status)
      else
        Todo
      end

    base_query
    |> group_by([t], t.status)
    |> select([t], {t.status, count(t.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets a single todo.

  Raises `Ecto.NoResultsError` if the Todo does not exist.

  ## Examples

      iex> get_todo!(123)
      %Todo{}

      iex> get_todo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_todo!(id), do: Repo.get!(Todo, id)
end
