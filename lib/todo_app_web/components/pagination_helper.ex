defmodule TodoAppWeb.Components.PaginationHelper do
  @moduledoc """
  Helper component for rendering pagination with automatic page calculation.
  """
  use Phoenix.Component

  import SaladUI.Pagination
  import Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a complete pagination component with calculated page links.
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :total_items, :integer, required: true
  attr :per_page, :integer, required: true
  attr :on_navigate, :any, required: true
  attr :on_per_page_change, :any, required: true
  attr :selected_count, :integer, default: 0
  attr :class, :string, default: nil

  def data_pagination(assigns) do
    ~H"""
    <div class={["flex flex-col gap-4", @class]}>
      <div class="flex w-full flex-col-reverse items-center justify-between gap-6 overflow-auto sm:flex-row sm:gap-8">
        <div class="flex-1 whitespace-nowrap text-sm text-muted-foreground">
          Page {@current_page || 1} of {@total_pages || 1}
        </div>

        <div class="flex flex-col-reverse items-center gap-4 sm:flex-row sm:gap-6 lg:gap-8">
          <div class="flex items-center space-x-2">
            <p class="whitespace-nowrap text-sm font-medium">Rows per page</p>
            <form phx-change={@on_per_page_change}>
              <select
                id="per-page-select"
                name="per_page"
                value={to_string(@per_page)}
                class="h-9 w-[70px] rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
              >
                <option value="10">10</option>
                <option value="25">25</option>
                <option value="50">50</option>
                <option value="100">100</option>
              </select>
            </form>
          </div>

          <.pagination :if={@total_pages > 1}>
            <.pagination_content>
              <.pagination_item>
                <.pagination_previous
                  phx-click={
                    (@current_page > 1 && JS.push(@on_navigate, value: %{page: @current_page - 1})) ||
                      nil
                  }
                  class={(@current_page == 1 && "pointer-events-none opacity-50") || ""}
                />
              </.pagination_item>

              <%= for page_num <- pagination_range(@current_page, @total_pages) do %>
                <%= if page_num == :ellipsis do %>
                  <.pagination_item>
                    <.pagination_ellipsis />
                  </.pagination_item>
                <% else %>
                  <.pagination_item>
                    <.pagination_link
                      is-active={page_num == @current_page}
                      phx-click={JS.push(@on_navigate, value: %{page: page_num})}
                    >
                      {page_num}
                    </.pagination_link>
                  </.pagination_item>
                <% end %>
              <% end %>

              <.pagination_item>
                <.pagination_next
                  phx-click={
                    (@current_page < @total_pages &&
                       JS.push(@on_navigate, value: %{page: @current_page + 1})) || nil
                  }
                  class={(@current_page >= @total_pages && "pointer-events-none opacity-50") || ""}
                />
              </.pagination_item>
            </.pagination_content>
          </.pagination>
        </div>
      </div>
    </div>
    """
  end

  # Calculate which page numbers to show
  defp pagination_range(_current, total) when total <= 0, do: []

  defp pagination_range(_current, total) when total <= 5 do
    1..total |> Enum.to_list()
  end

  defp pagination_range(current, total) do
    cond do
      # At the beginning (pages 1-3)
      current <= 3 ->
        list = [1, 2, 3]
        if total > 3, do: list ++ [:ellipsis, total], else: list

      # At the end (last 3 pages)
      current >= total - 2 ->
        [1, :ellipsis, total - 2, total - 1, total]

      # In the middle
      true ->
        [1, :ellipsis, current, :ellipsis, total]
    end
  end
end
