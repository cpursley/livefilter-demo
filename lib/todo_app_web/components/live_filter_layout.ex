defmodule TodoAppWeb.Components.LiveFilterLayout do
  @moduledoc """
  Main layout component for the LiveFilter interface.
  Provides a modern, shadcn-inspired layout with header, toolbar, and content areas.
  """
  use Phoenix.Component
  use Phoenix.VerifiedRoutes,
    endpoint: TodoAppWeb.Endpoint,
    router: TodoAppWeb.Router,
    statics: TodoAppWeb.static_paths()
    
  import TodoAppUi.Icon
  import TodoAppUi.Badge
  
  # Import Phoenix.Component for attrs and slots
  import Phoenix.Component
  

  @doc """
  Renders the main layout wrapper with header navigation.
  """
  attr :current_tab, :string, default: "table"
  attr :class, :string, default: nil
  slot :toolbar, required: true
  slot :content, required: true
  slot :inner_block

  def live_filter_layout(assigns) do
    ~H"""
    <div class={["min-h-screen bg-background", @class]}>
      <.header current_tab={@current_tab} />
      
      <main class="container mx-auto px-4 py-6 space-y-4">
        <div class="rounded-lg border bg-card">
          {render_slot(@toolbar)}
        </div>
        
        <div class="rounded-lg border bg-card">
          {render_slot(@content)}
        </div>
      </main>
    </div>
    """
  end

  # Renders the header with navigation tabs and user menu.
  attr :current_tab, :string, default: "table"

  defp header(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="container mx-auto px-4">
        <div class="flex h-14 items-center justify-between">
          <div class="flex items-center gap-6">
            <.link navigate="/" class="flex items-center gap-2 font-semibold">
              <div class="h-6 w-6 rounded bg-primary flex items-center justify-center">
                <span class="text-primary-foreground text-xs">LF</span>
              </div>
              <span class="hidden sm:inline-block">LiveFilter</span>
            </.link>
            
            <nav class="flex items-center h-full">
              <.link navigate="/todos" class={[
                "inline-flex items-center justify-center whitespace-nowrap rounded-none px-3 py-1.5 text-sm font-medium ring-offset-background transition-all h-full border-b-2",
                if(@current_tab == "table", do: "border-primary text-foreground", else: "border-transparent text-muted-foreground hover:text-foreground")
              ]}>
                <.icon name="hero-table-cells" class="w-4 h-4 mr-2" />
                Table
              </.link>
              <a href="https://hexdocs.pm/livefilter" target="_blank" class="inline-flex items-center justify-center whitespace-nowrap rounded-none px-3 py-1.5 text-sm font-medium ring-offset-background transition-all h-full text-muted-foreground hover:text-foreground no-underline">
                <.icon name="hero-document-text" class="w-4 h-4 mr-2" />
                Docs
              </a>
            </nav>
          </div>
          
          <div class="flex items-center gap-4">
            <a href="https://github.com/yourusername/livefilter" target="_blank" class="text-sm text-muted-foreground hover:text-foreground transition-colors">
              GitHub
            </a>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Renders the toolbar with filter controls and view options.
  """
  attr :show_advanced_filters, :boolean, default: false
  attr :filter_count, :integer, default: 0
  attr :on_toggle_advanced_filters, :any, default: nil
  slot :quick_filters
  slot :view_controls

  def toolbar(assigns) do
    ~H"""
    <div class="p-4">
      <div class="flex items-start justify-between gap-4">
        <%!-- Filters container - takes available space --%>
        <div :if={@quick_filters != []} class="flex-1 min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            {render_slot(@quick_filters)}
          </div>
        </div>
        
        <%!-- View controls - fixed position on the right --%>
        <div :if={@view_controls != []} class="flex-shrink-0">
          {render_slot(@view_controls)}
        </div>
      </div>
    </div>
    """
  end

  # Renders a badge showing the filter count.
  attr :count, :integer, required: true

  defp filter_count_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class="ml-2 rounded-sm px-1 font-normal">
      {@count}
    </.badge>
    """
  end

  @doc """
  Renders the data table container with consistent styling.
  """
  slot :inner_block, required: true

  def data_container(assigns) do
    ~H"""
    <div class="w-full overflow-auto">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders an empty state when no data is available.
  """
  attr :title, :string, default: "No results found"
  attr :description, :string, default: "Try adjusting your filters or search criteria."
  attr :icon, :string, default: "hero-magnifying-glass"
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 text-center">
      <div class="rounded-full bg-muted p-3 mb-4">
        <.icon name={@icon} class="h-6 w-6 text-muted-foreground" />
      </div>
      <h3 class="text-lg font-semibold">{@title}</h3>
      <p class="text-sm text-muted-foreground mt-1">{@description}</p>
      <div :if={@action != []} class="mt-4">
        {render_slot(@action)}
      </div>
    </div>
    """
  end
end