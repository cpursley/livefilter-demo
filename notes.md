# Todo App - LiveFilter Demo

## Project Overview

This is a demonstration application showcasing the **LiveFilter** library for Phoenix LiveView. The app displays a todo list with advanced filtering capabilities but focuses purely on filter demonstration rather than CRUD operations.

## Current Architecture

### LiveFilter Library (`lib/live_filter/`)
- **Standalone library** built for extraction and reuse
- Uses **SaladUI components** directly (no TodoAppUi dependencies)
- Core components:
  - `SearchSelect` - Multi/single select dropdown with search
  - `DateRangeSelect` - Date range picker with presets and calendar
  - `FilterSelector` - Dropdown for selecting filters to add (NEW)
  - `QuickFilter` - Dynamic filter component based on type (NEW)
  - `QueryBuilder` - Converts filters to Ecto queries
  - `UrlSerializer` - Persists filters in URL parameters
  - `DateUtils` - Date range calculations and timestamp conversions

### Todo Application (`lib/todo_app/`)
- **Read-only demonstration** - no create/edit/delete functionality
- Populated via seeds with 130 diverse sample todos
- Schema includes: status, assignee, due_date, tags, urgency, etc.
- Added "Created" column to table for timestamp filtering demo

### Key Features Implemented

#### Default Filters (Always Visible)
1. **Search Input** - Text search across title and description fields
   - Case-insensitive matching with PostgreSQL `ilike`
   - Whitespace trimming
   - 300ms debounce
   - Clear button when input has content
   - Proper form wrapping for LiveView events
2. **Status Filter** - Single-select dropdown (Pending, In Progress, Completed, Archived)  
3. **Assignee Filter** - Multi-select searchable dropdown
4. **Due Date Filter** - Date range with presets
5. **Urgent Filter** - Toggle button showing "Urgent?" when off, "Urgent ✓" when on

#### Optional Filters (Via "Add Filter" Dropdown)
1. **Project Filter** - Single-select dropdown with actual project values
2. **Tags Filter** - Multi-select searchable dropdown
3. **Est. Hours Filter** - Numeric input for estimated hours
4. **Actual Hours Filter** - Numeric input for actual hours
5. **Complexity Filter** - Integer input (1-10 scale)
6. **Created Filter** - Timestamp range (no presets, direct calendar)

#### UI Components
- Clean table layout with status badges
- Quick filter toolbar with live search
- Modern date range picker with dual calendar view
- Advanced filter builder with add/remove capabilities
- URL persistence for all filter states
- Responsive design using SaladUI/Tailwind

### Database Schema

```elixir
schema "todos" do
  field :title, :string
  field :description, :text
  field :status, Ecto.Enum, values: [:pending, :in_progress, :completed, :archived]
  field :due_date, :date
  field :completed_at, :utc_datetime
  field :estimated_hours, :float
  field :actual_hours, :float
  field :is_urgent, :boolean, default: false
  field :is_recurring, :boolean, default: false
  field :tags, {:array, :string}
  field :assigned_to, :string
  field :project, :string
  field :complexity, :integer
  timestamps()
end
```

### Removed Features
- ❌ Create todo functionality
- ❌ Edit todo functionality  
- ❌ Delete todo functionality
- ❌ Show/detail view
- ❌ Form components and modals
- ❌ Priority field (replaced with boolean urgency)
- ❌ Individual todo routing

### Routes
- `GET /` - Home page
- `GET /todos` - Todo list with filters (main demo)
- `GET /demo` - Additional demo page

## Development Focus

This application serves as a **comprehensive demonstration** of the LiveFilter library's capabilities:

1. **Real-time filtering** with immediate UI updates
2. **URL persistence** for shareable filter states  
3. **Multiple filter types** working together seamlessly
4. **Performance** with large datasets (130+ items)
5. **UX patterns** for complex filter interfaces

## Technical Stack

- **Phoenix LiveView** - Real-time web application framework
- **Elixir/OTP** - Backend language and platform
- **SaladUI** - Elixir port of shadcn/ui components
- **TailwindCSS** - Utility-first CSS framework
- **PostgreSQL** - Database with advanced indexing
- **Ecto** - Database wrapper and query builder

## LiveFilter Library Status

✅ **Successfully extracted** - Core library is now standalone and business-logic agnostic
✅ **Pluggable architecture** - Field protocol and registry system for extensibility
✅ **LiveView integration** - Mountable macro with overridable functions
✅ **URL serialization** - Complete filter state persistence with indexed map support
✅ **Query building** - Automatic Ecto query generation
✅ **Comprehensive testing** - 258 tests covering all edge cases
✅ **Production ready** - Handles real-world URL encoding/parsing scenarios

The library has been successfully extracted into reusable, business-logic agnostic modules ready for standalone distribution.

## Recent Updates (July 2025)

### DateRangeSelect Component Improvements
1. **Modern Calendar Design**
   - Redesigned to match shadcn/ui calendar style
   - Dual calendar view for easy range selection
   - Month/year dropdown selectors in header
   - Improved hover states and range highlighting
   - Proper table structure with semantic HTML
   - Fixed dropdown chevron overlap with proper padding
   - Auto-apply behavior - applies filter after selecting end date
   - Click-outside-to-close functionality with proper layout handling
   - Clear button moved to right side with hero-x-mark icon
   - Configurable year range with sensible defaults

2. **Component Architecture Fix**
   - Fixed assigns error by converting render_calendar to proper Phoenix Component
   - Uses component attributes instead of passing plain maps
   - Proper change tracking for LiveView
   - Fixed event routing for array-type filters using dynamic event names

3. **UI/UX Improvements**
   - Created column added to todo table
   - Relative time formatting (e.g., "3 hours ago", "2 days ago")
   - Direct calendar mode for Created filter (no preset dropdown)
   - Improved navigation styling (only active tab underlined)
   - Docs link opens in new tab
   - Urgent filter implemented as toggle button (not dropdown)
   - New filters always added to end of filter list
   - Project filter uses actual schema values from database
   - Project column added to table between Status and Assignee
   - Boolean filters show configurable icon with "?" when not selected, check mark when selected
   - Improved filter toolbar layout with proper responsive breakpoints
   - Search input with clear button and proper vertical centering using flexbox

## Date Range Select Configuration

The DateRangeSelect component now supports configurable presets and timestamp types:

### Configurable Presets

```elixir
# Use all default presets (default behavior)
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="date-filter"
  value={@selected_range}
  label="Due Date"
/>

# Enable only specific presets
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="date-filter"
  value={@selected_range}
  label="Due Date"
  enabled_presets={[:today, :tomorrow, :last_7_days, :next_30_days]}
/>

# Disable all presets - goes directly to calendar picker
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="date-filter"
  value={@selected_range}
  label="Due Date"
  enabled_presets={[]}
/>

# Custom year range (default is -100 to +20 years from current year)
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="date-filter"
  value={@selected_range}
  label="Due Date"
  year_range={-50, 10}  # 50 years in past, 10 years in future
/>
```

Available preset keys (in chronological order):
- `:last_month` - Last month
- `:last_30_days` - Last 30 days
- `:last_7_days` - Last 7 days
- `:yesterday` - Yesterday
- `:today` - Today
- `:tomorrow` - Tomorrow  
- `:next_7_days` - Next 7 days
- `:this_month` - This month
- `:next_30_days` - Next 30 days
- `:this_year` - This year

### Timestamp Type Support

The DateRangeSelect component supports various Elixir/Ecto timestamp types:

```elixir
# For date fields (default)
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="due-date-filter"
  value={@date_range}
  label="Due Date"
  timestamp_type={:date}
/>

# For UTC datetime fields
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="created-filter"
  value={@created_range}
  label="Created"
  timestamp_type={:utc_datetime}
/>

# For naive datetime fields
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="updated-filter"
  value={@updated_range}
  label="Updated"
  timestamp_type={:naive_datetime}
/>

# For datetime fields (alias for :utc_datetime)
<.live_component
  module={LiveFilter.Components.DateRangeSelect}
  id="completed-filter"
  value={@completed_range}
  label="Completed"
  timestamp_type={:datetime}
/>
```

Supported timestamp types:
- `:date` - Elixir Date (default)
- `:datetime` - Alias for :utc_datetime
- `:utc_datetime` - Ecto.DateTime / DateTime with UTC timezone
- `:naive_datetime` - NaiveDateTime without timezone info

When using timestamp types, the component automatically:
- Converts date selections to timestamps with appropriate start/end times
- For range start: Sets time to 00:00:00
- For range end: Sets time to 23:59:59
- Handles display formatting to show only dates in the UI
- Returns properly typed values for Ecto queries

## New Filter System (December 2024)

### Deprecated: FilterBuilder
The old FilterBuilder component with inline field/operator/value selection has been completely removed in favor of a modern dropdown-based approach.

### Current Filter Architecture
The todo app now uses a two-tier filter system:
1. **Default Filters** - Always visible in the toolbar: Search, Status, Assignee, Due Date, Urgent
2. **Optional Filters** - Available via "Add Filter" dropdown: Project, Tags, Est. Hours, Actual Hours, Complexity, Created

### New Components

#### FilterSelector
A dropdown component for selecting filters to add:
```elixir
<.live_component
  module={LiveFilter.Components.FilterSelector}
  id="add-filter"
  available_filters={[
    {:description, "Description", :string, %{icon: "hero-document-text"}},
    {:tags, "Tags", :array, %{icon: "hero-tag", options: [{"bug", "Bug"}, {"feature", "Feature"}]}}
  ]}
  active_filters={[:tags]}
  label="Add Filter"
/>
```

Features:
- Shows only inactive filters in dropdown
- Supports custom icons for each filter
- Sends `{:filter_selected, field}` message when selected
- Automatically disables when all filters are active

#### QuickFilter
Dynamic filter component that renders appropriate input based on type:
```elixir
<.live_component
  module={LiveFilter.Components.QuickFilter}
  id="filter-title"
  field={:title}
  label="Title"
  type={:string}
  value={@title_filter}
  icon="hero-document"
/>
```

Supported types:
- `:string` - Text input with debounce
- `:integer`, `:float` - Number input
- `:boolean` - Toggle button
- `:date`, `:datetime` - Date picker integration
- `:enum` - Single select dropdown
- `:array` - Multi-select with SearchSelect

Sends messages:
- `{:quick_filter_changed, field, value}` on value change
- `{:quick_filter_cleared, field}` on clear

**Important**: For array-type filters, the component uses field-specific event names (e.g., `quick_filter_tags_changed`) to properly route events from function components to the parent LiveView.

### Integration Pattern

In your LiveView:
```elixir
# Define available optional filters
defp optional_field_options do
  [
    {:project, "Project", :enum, %{
      icon: "hero-folder",
      options: TodoApp.Todos.Todo.project_options() |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
    }},
    {:tags, "Tags", :array, %{
      icon: "hero-tag",
      options: TodoApp.Todos.Todo.tag_options() |> Enum.map(fn %{value: v, label: l} -> {v, l} end)
    }},
    {:estimated_hours, "Est. Hours", :float, %{icon: "hero-clock"}},
    {:actual_hours, "Actual Hours", :float, %{icon: "hero-check-circle"}},
    {:complexity, "Complexity", :integer, %{icon: "hero-chart-bar"}},
    {:inserted_at, "Created", :utc_datetime, %{icon: "hero-clock"}}
  ]
end

# Track active filters and values
socket
|> assign(:active_optional_filters, [])
|> assign(:optional_filter_values, %{})

# Handle events
def handle_info({:filter_selected, field}, socket) do
  # Add to end of list to maintain order
  active_filters = socket.assigns.active_optional_filters ++ [field]
  {:noreply, assign(socket, :active_optional_filters, active_filters)}
end

def handle_info({:quick_filter_changed, field, value}, socket) do
  filter_values = Map.put(socket.assigns.optional_filter_values, field, value)
  {:noreply, assign(socket, :optional_filter_values, filter_values)}
end

# Handle dynamic events for array filters
def handle_event("quick_filter_" <> field_changed, params, socket) do
  field = field_changed
  |> String.replace("_changed", "")
  |> String.to_existing_atom()
  
  value = case params do
    %{"toggle" => val} -> # Multi-select handling
    %{"select" => val} -> # Single-select handling
    %{"clear" => true} -> # Clear handling
  end
  
  send(self(), {:quick_filter_changed, field, value})
  {:noreply, socket}
end
```

### Benefits Over Old System
1. **Cleaner UI** - Filters only appear when needed
2. **Better UX** - Consistent with GitHub, Linear, and modern apps
3. **Type-aware** - Each filter type has optimized UI
4. **Flexible** - Mix default and optional filters
5. **No breaking changes** - Old FilterBuilder users can continue using it

## Enhanced Search Functionality

The search input now supports:

1. **Multi-field Search** - Searches across both title and description fields
2. **Case-insensitive** - Uses PostgreSQL's `ilike` operator for case-insensitive matching
3. **Normalized Input** - Automatically trims whitespace from search queries
4. **OR Logic** - Matches if the query appears in ANY of the configured fields
5. **Configurable Fields** - Easy to customize which fields are searched via `search_field_config/0`
6. **Proper Form Handling** - Search input wrapped in form element for correct Phoenix LiveView event handling
7. **Debounced Input** - 300ms debounce to reduce server requests while typing
8. **Clear Button** - Shows X button when search has content, properly centered with flexbox
9. **Autocomplete Disabled** - Prevents browser autocomplete from interfering with live search

### Search Configuration

```elixir
# In your LiveView, define which fields to search and their operators
defp search_field_config do
  [
    {:title, :contains},        # Searches anywhere in title
    {:description, :contains},  # Searches anywhere in description
    # Add more fields as needed:
    # {:tags, :contains_any},   # For array fields
    # {:project, :equals},      # For exact match
    # {:assignee, :starts_with} # For prefix match
  ]
end
```

### Supported Search Operators

- `:contains` - Substring match (case-insensitive)
- `:starts_with` - Prefix match
- `:ends_with` - Suffix match
- `:equals` - Exact match
- `:matches` - Pattern match (same as contains)

The search creates a nested FilterGroup with OR conjunction, ensuring that matching ANY field will return results. This is properly translated to optimized Ecto queries using dynamic query building.

### Migration Guide
1. Remove `show_filters` state and toggle button
2. Define optional filters with `optional_field_options/0`
3. Add FilterSelector component to toolbar
4. Handle new event messages
5. Update `apply_quick_filters` to include optional filters

## LiveFilter Library Extraction (January 2025)

### Core Architecture Overhaul

The LiveFilter library has been completely restructured into a standalone, business-logic agnostic library with the following core modules:

#### New Core Modules

**LiveFilter.UIState** (`lib/live_filter/ui_state.ex`)
- Bidirectional conversion between UI state and filter data structures
- Pluggable converter functions via options
- Pure type-based logic without business-specific assumptions
- Supports custom field type detection

**LiveFilter.Field** (`lib/live_filter/field.ex`)
- Protocol-based system for extensible field types
- Built-in implementations for common types: `:string`, `:integer`, `:float`, `:boolean`, `:date`, `:datetime`, `:enum`, `:array`
- Custom field types can implement the protocol for specialized behavior
- Type-safe value conversion and validation

**LiveFilter.FieldRegistry** (`lib/live_filter/field_registry.ex`)
- Central registry for field configurations
- Supports field definitions with types, labels, default operators, and custom options
- Helper functions for common field types (string_field, enum_field, date_field, etc.)
- Extensible via Field protocol for custom types

**LiveFilter.Mountable** (`lib/live_filter/mountable.ex`)
- LiveView integration macro with `use LiveFilter.Mountable`
- Provides mount_filters/2, handle_filter_params/3, apply_filters_and_reload/3
- All functions are overridable and customizable via options
- Pluggable URL updaters, parameter handlers, and reload callbacks
- Supports custom UI state converters

**LiveFilter.QuickFilters** (`lib/live_filter/quick_filters.ex`)
- Composable filter builder functions
- High-level helpers: search_filter/2, multi_select_filter/3, date_range_filter/3, boolean_filter/3
- Configurable minimum search length and field targeting
- Handles empty values and edge cases gracefully

**LiveFilter.EventRouter** (`lib/live_filter/event_router.ex`)
- Dynamic event routing for LiveView events
- Parses events like "quick_filter_status_changed" into {:ok, :status, :changed}
- Supports custom separators and action extraction
- Handler map routing with fallback support
- Handles clear, toggle, and select actions for different filter types

**LiveFilter.UrlUtils** (`lib/live_filter/url_utils.ex`)
- URL parameter flattening utilities
- Converts nested maps to flat parameter structures for URL encoding
- Handles arrays, nested objects, and complex structures
- Integration point for Phoenix URL parameter handling

#### Enhanced Existing Modules

**LiveFilter.UrlSerializer** (`lib/live_filter/url_serializer.ex`)
- **Critical Fix**: Added `convert_indexed_map_to_list/1` to handle Phoenix URL parsing
- Resolves Ecto cast errors when array parameters are parsed as indexed maps
- Supports non-sequential indices and mixed value types
- Complete round-trip compatibility between URL encoding and parsing

### TodoLive.Index Integration

The TodoApp has been refactored to demonstrate the new LiveFilter integration:

```elixir
defmodule TodoAppWeb.TodoLive.Index do
  use TodoAppWeb, :live_view
  use LiveFilter.Mountable  # <-- New integration

  def mount(_params, _session, socket) do
    socket = mount_filters(socket,
      registry: todo_field_registry(),
      default_sort: Sort.new(:due_date, :asc)
    )
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    socket = handle_filter_params(socket, params, 
      ui_converter: &convert_filters_to_ui_state/2
    )
    {:noreply, socket}
  end

  # Dynamic event routing with EventRouter
  def handle_event("quick_filter_" <> _rest = event, params, socket) do
    EventRouter.route_event(event, params,
      handlers: %{
        "status_changed" => &handle_status_filter_change/3,
        "assignee_changed" => &handle_assignee_filter_change/3,
        "urgent_changed" => &handle_urgent_filter_change/3
      },
      fallback: &handle_optional_filter_change/3,
      socket: socket
    )
  end
end
```

### Key Architectural Improvements

1. **Business Logic Separation**: All business-specific logic removed from core modules
2. **Protocol-Based Extensibility**: Field protocol allows custom field types
3. **Overridable Everything**: All functions can be customized via options or overriding
4. **URL Parsing Robustness**: Handles real-world Phoenix URL parameter parsing edge cases
5. **Comprehensive Testing**: 258 tests covering all modules and edge cases
6. **Zero Breaking Changes**: Existing TodoApp functionality preserved while demonstrating new patterns

### Technical Solutions Implemented

#### Phoenix URL Parameter Parsing Fix
**Problem**: URLs like `/todos?filters[status][values][0]=pending&filters[status][values][1]=active` were parsed by Phoenix as:
```elixir
%{"filters" => %{"status" => %{"values" => %{"0" => "pending", "1" => "active"}}}}
```
Instead of proper lists:
```elixir
%{"filters" => %{"status" => %{"values" => ["pending", "active"]}}}
```

**Solution**: Added `convert_indexed_map_to_list/1` in UrlSerializer that:
- Detects indexed map structures
- Converts them back to proper lists
- Handles non-sequential indices
- Sorts by numeric index for predictable ordering
- Maintains backward compatibility with existing list structures

#### Event Routing Architecture
**Problem**: Dynamic filter events needed flexible routing to different handlers

**Solution**: EventRouter module provides:
- Pattern-based event parsing with configurable prefixes
- Handler map routing with fallback support
- Standardized action extraction (clear, toggle, select)
- Type-safe event value extraction

### Testing Coverage

- **UrlSerializer**: 37 tests including indexed map edge cases and complete round-trip validation
- **UrlUtils**: 10 tests covering flattening, encoding, and Phoenix integration
- **Field Protocol**: Tests for all built-in types and extensibility patterns
- **FieldRegistry**: Configuration and lookup functionality
- **EventRouter**: Dynamic routing and action parsing
- **Integration Tests**: End-to-end filter workflows and URL persistence

### Production Readiness

The library now handles real-world scenarios including:
- Complex nested URL parameter structures
- Phoenix's automatic parameter parsing behavior
- Browser URL encoding/decoding round-trips
- Multi-select filter state persistence
- Type-safe value conversion and validation
- Customizable UI state management
- Pluggable business logic integration

The TodoApp serves as a comprehensive reference implementation demonstrating all library capabilities while remaining business-logic agnostic at the core library level.