defmodule LiveFilter.Components.FilterBuilder do
  use Phoenix.LiveComponent
  alias LiveFilter.{FilterGroup, Filter}
  alias TodoAppUi.Button
  import TodoAppWeb.CoreComponents, only: [icon: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-submit="apply_filters" phx-target={@myself} class="space-y-4">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold">Filters</h3>
        <div class="flex gap-2">
          <Button.button
            phx-click="add_filter"
            phx-target={@myself}
            variant="outline"
            size="sm"
            type="button"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-1" />
            Add Filter
          </Button.button>
          <%= if FilterGroup.has_filters?(@filter_group) do %>
            <Button.button
              phx-click="clear_filters"
              phx-target={@myself}
              variant="ghost"
              size="sm"
              type="button"
            >
              Clear All
            </Button.button>
          <% end %>
        </div>
      </div>

      <div class="space-y-2">
        <%= for {filter, index} <- Enum.with_index(@filter_group.filters) do %>
          <.live_component
            module={LiveFilter.Components.FilterItem}
            id={"filter-#{index}"}
            filter={filter}
            index={index}
            field_options={@field_options}
          />
        <% end %>
      </div>

      <%= if FilterGroup.has_filters?(@filter_group) do %>
        <div class="flex justify-end">
          <Button.button type="submit">
            Apply Filters
          </Button.button>
        </div>
      <% end %>
    </form>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:filter_group, fn -> %FilterGroup{} end)}
  end

  @impl true
  def handle_event("add_filter", _params, socket) do
    {field, _label, type, _opts} = List.first(socket.assigns.field_options)
    operators = LiveFilter.FilterTypes.operators_for_type(type)
    operator = List.first(operators)

    filter = %Filter{
      field: field,
      operator: operator,
      type: type,
      value: nil
    }

    updated_group = FilterGroup.add_filter(socket.assigns.filter_group, filter)

    send(self(), {:filter_group_updated, updated_group})
    {:noreply, assign(socket, :filter_group, updated_group)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    updated_group = %FilterGroup{}
    send(self(), {:filter_group_updated, updated_group})
    {:noreply, assign(socket, :filter_group, updated_group)}
  end

  @impl true
  def handle_event("apply_filters", _params, socket) do
    IO.inspect(socket.assigns.filter_group, label: "FilterBuilder applying filters")
    send(self(), {:apply_filters, socket.assigns.filter_group})
    {:noreply, socket}
  end

  # Note: LiveComponents don't have handle_info, these messages will be sent to the parent LiveView
  # The parent LiveView should handle {:filter_updated, index, filter} and {:filter_removed, index}

end
