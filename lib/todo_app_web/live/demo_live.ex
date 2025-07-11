defmodule TodoAppWeb.DemoLive do
  use TodoAppWeb, :live_view
  import LiveFilter.Components.SearchSelect
  
  @impl true
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:selected_tags, [])
      |> assign(:selected_statuses, [:todo, :in_progress])
      |> assign(:tag_options, [
        {:bug, "Bug"},
        {:feature, "Feature"},
        {:documentation, "Documentation"},
        {:enhancement, "Enhancement"},
        {:refactor, "Refactor"},
        {:test, "Test"},
        {:chore, "Chore"}
      ])
      |> assign(:status_options, [
        {:pending, "Pending"},
        {:todo, "Todo"},
        {:in_progress, "In-progress"},
        {:completed, "Completed"},
        {:archived, "Archived"}
      ])
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-8">LiveFilter SearchSelect Demo</h1>
      
      <div class="space-y-8">
        <div>
          <h2 class="text-lg font-semibold mb-4">Status Filter Example (like in Todo app)</h2>
          <div class="flex items-center gap-4">
            <.search_select
              id="status-filter"
              options={@status_options}
              selected={@selected_statuses}
              on_change="update_statuses"
              label="Status"
              icon="hero-circle-stack"
              placeholder="Select status..."
              display_count={3}
            />
            
            <div class="text-sm text-muted-foreground">
              Selected: <%= inspect(@selected_statuses) %>
            </div>
          </div>
        </div>
        
        <div>
          <h2 class="text-lg font-semibold mb-4">Multi-Select Example</h2>
          <div class="flex items-center gap-4">
            <.search_select
              id="tags-filter"
              options={@tag_options}
              selected={@selected_tags}
              on_change="update_tags"
              label="Tags"
              icon="hero-tag"
              placeholder="Select tags..."
              display_count={2}
            />
            
            <div class="text-sm text-muted-foreground">
              Selected: <%= inspect(@selected_tags) %>
            </div>
          </div>
        </div>
        
        <div>
          <h2 class="text-lg font-semibold mb-4">Display Count Examples</h2>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <p class="text-sm mb-2">display_count=1 (shows count after 1 selection)</p>
              <.search_select
                id="tags-filter-1"
                options={@tag_options}
                selected={@selected_tags}
                on_change="update_tags"
                label="Tags"
                placeholder="Select tags..."
                display_count={1}
              />
            </div>
            
            <div>
              <p class="text-sm mb-2">display_count=3 (shows up to 3 selections)</p>
              <.search_select
                id="tags-filter-3"
                options={@tag_options}
                selected={@selected_tags}
                on_change="update_tags"
                label="Tags"
                placeholder="Select tags..."
                display_count={3}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @impl true
  def handle_event("update_tags", %{"toggle" => tag}, socket) do
    selected = socket.assigns.selected_tags
    updated = if tag in selected do
      List.delete(selected, tag)
    else
      [tag | selected]
    end
    
    {:noreply, assign(socket, :selected_tags, updated)}
  end
  
  @impl true
  def handle_event("update_tags", %{"clear" => true}, socket) do
    {:noreply, assign(socket, :selected_tags, [])}
  end
  
  @impl true
  def handle_event("update_statuses", %{"toggle" => status}, socket) do
    selected = socket.assigns.selected_statuses
    updated = if status in selected do
      List.delete(selected, status)
    else
      [status | selected]
    end
    
    {:noreply, assign(socket, :selected_statuses, updated)}
  end
  
  @impl true
  def handle_event("update_statuses", %{"clear" => true}, socket) do
    {:noreply, assign(socket, :selected_statuses, [])}
  end
end