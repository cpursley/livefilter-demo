defmodule LiveFilter.TestLive do
  @moduledoc """
  A test LiveView for testing LiveFilter functionality.
  This module can be used in any Phoenix app to test LiveFilter.
  """
  use Phoenix.LiveView

  alias LiveFilter.{FilterGroup, UrlSerializer, Sort}
  import LiveFilter.Components.SortableHeader

  # Simple test schema
  defmodule Item do
    defstruct [:id, :title, :status, :is_active, :tags, :created_at]
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filter_group, %FilterGroup{})
      |> assign(:current_sort, nil)
      |> assign(:items, [])
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_group = UrlSerializer.from_params(params)
    sorts = UrlSerializer.sorts_from_params(params)
    pagination = UrlSerializer.pagination_from_params(params)

    # Simulate data loading
    items = generate_test_items()
    filtered_items = apply_test_filters(items, filter_group)
    sorted_items = apply_test_sorts(filtered_items, sorts)

    # Apply pagination
    page_items =
      Enum.slice(sorted_items, (pagination.page - 1) * pagination.per_page, pagination.per_page)

    socket =
      socket
      |> assign(:filter_group, filter_group)
      |> assign(:current_sort, sorts)
      |> assign(:items, page_items)
      |> assign(:page, pagination.page)
      |> assign(:per_page, pagination.per_page)
      |> assign(:total_count, length(sorted_items))
      |> assign(:total_pages, ceil(length(sorted_items) / pagination.per_page))

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    # Handle filter events
    {:noreply, push_patch(socket, to: self_path(socket, params))}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    new_sort =
      case socket.assigns.current_sort do
        %Sort{field: ^field, direction: :asc} -> Sort.new(field, :desc)
        %Sort{field: ^field, direction: :desc} -> nil
        _ -> Sort.new(String.to_atom(field), :asc)
      end

    params =
      UrlSerializer.update_params(
        %{},
        socket.assigns.filter_group,
        new_sort,
        %{page: socket.assigns.page, per_page: socket.assigns.per_page}
      )

    {:noreply, push_patch(socket, to: self_path(socket, params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="test-live-filter">
      <div class="filters">
        <form phx-change="filter">
          <input type="text" name="filters[title][value]" placeholder="Search..." />
          <select name="filters[status][value]">
            <option value="">All</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
          </select>
        </form>
      </div>

      <table>
        <thead>
          <tr>
            <.sortable_header
              field={:title}
              label="Title"
              current_sort={@current_sort}
              phx-click="sort"
            />
            <.sortable_header
              field={:status}
              label="Status"
              current_sort={@current_sort}
              phx-click="sort"
            />
            <th>Tags</th>
            <.sortable_header
              field={:created_at}
              label="Created"
              current_sort={@current_sort}
              phx-click="sort"
            />
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @items}>
            <td>{item.title}</td>
            <td>{item.status}</td>
            <td>{Enum.join(item.tags || [], ", ")}</td>
            <td>{item.created_at}</td>
          </tr>
        </tbody>
      </table>

      <div class="pagination">
        Page {@page} of {@total_pages} (Total: {@total_count})
      </div>
    </div>
    """
  end

  # Test helpers
  defp self_path(_socket, params) do
    "/test/live-filter?" <> URI.encode_query(params)
  end

  defp generate_test_items do
    for i <- 1..50 do
      %Item{
        id: i,
        title: "Item #{i}",
        status: Enum.random(["active", "inactive"]),
        is_active: rem(i, 2) == 0,
        tags: Enum.take_random(["red", "blue", "green", "yellow"], :rand.uniform(3)),
        created_at: Date.add(Date.utc_today(), -i)
      }
    end
  end

  defp apply_test_filters(items, %FilterGroup{filters: filters}) do
    Enum.reduce(filters, items, fn filter, acc ->
      apply_single_filter(acc, filter)
    end)
  end

  defp apply_single_filter(items, %{field: :title, value: value}) when value != "" do
    Enum.filter(items, fn item ->
      String.contains?(String.downcase(item.title), String.downcase(value))
    end)
  end

  defp apply_single_filter(items, %{field: :status, value: value}) when value != "" do
    Enum.filter(items, fn item ->
      item.status == value
    end)
  end

  defp apply_single_filter(items, _), do: items

  defp apply_test_sorts(items, nil), do: items

  defp apply_test_sorts(items, %Sort{field: field, direction: direction}) do
    Enum.sort_by(items, &Map.get(&1, field), direction)
  end
end
