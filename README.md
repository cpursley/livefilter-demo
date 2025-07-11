# LiveFilter Demo - TodoApp

A comprehensive demonstration of the **LiveFilter** library for Phoenix LiveView, showcasing advanced filtering capabilities with real-world data.

## Overview

This application demonstrates the LiveFilter library - a standalone, business-logic agnostic filtering system for Phoenix LiveView applications. The TodoApp serves as a reference implementation showing how to integrate advanced filtering capabilities into your Phoenix apps.

## Features

- **Real-time filtering** with immediate UI updates
- **URL persistence** for shareable filter states
- **Multiple filter types**: search, select, multi-select, date ranges, boolean toggles
- **Extensible architecture** with protocol-based field types
- **Production-ready** URL parameter handling
- **Comprehensive test coverage** (258 tests)

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone <repository>
   cd todo_app
   mix setup
   ```

2. **Start the server:**
   ```bash
   mix phx.server
   ```

3. **Visit the demo:**
   Open [localhost:4000/todos](http://localhost:4000/todos) to see the filtering system in action.

## LiveFilter Library

The core LiveFilter library (`lib/live_filter/`) is designed as a standalone package that can be extracted and used in any Phoenix LiveView application. It provides:

### Core Modules

- **LiveFilter.Mountable** - LiveView integration via `use` macro
- **LiveFilter.Field** - Protocol-based extensible field types  
- **LiveFilter.FieldRegistry** - Central field configuration
- **LiveFilter.UrlSerializer** - URL parameter persistence
- **LiveFilter.QuickFilters** - Composable filter builders
- **LiveFilter.EventRouter** - Dynamic event routing

### Key Features

- ✅ **Business-logic agnostic** - No domain-specific assumptions
- ✅ **Fully customizable** - All functions overridable via options
- ✅ **Protocol-based extensibility** - Custom field types supported
- ✅ **URL-safe** - Handles complex parameter structures
- ✅ **Type-safe** - Strong typing throughout the system
- ✅ **Well-tested** - Comprehensive test coverage

## Integration Example

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use LiveFilter.Mountable

  def mount(_params, _session, socket) do
    socket = mount_filters(socket,
      registry: product_field_registry(),
      default_sort: Sort.new(:name, :asc)
    )
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    socket = handle_filter_params(socket, params)
    {:noreply, load_products(socket)}
  end

  defp product_field_registry do
    FieldRegistry.from_fields([
      FieldRegistry.string_field(:name, "Product Name"),
      FieldRegistry.enum_field(:category, "Category", category_options()),
      FieldRegistry.date_field(:created_at, "Created Date")
    ])
  end
end
```

## Architecture

The TodoApp demonstrates a two-tier filtering system:

1. **Default Filters** (always visible):
   - Search input with multi-field search
   - Status dropdown (single-select)
   - Assignee selector (multi-select)
   - Date range picker with presets
   - Urgent toggle button

2. **Optional Filters** (add via dropdown):
   - Project, Tags, Hours, Complexity, Created date
   - Dynamic UI based on field type
   - Configurable with custom icons and options

## Technical Details

- **Phoenix LiveView** - Real-time web framework
- **SaladUI Components** - Modern UI component library
- **PostgreSQL** - Database with advanced querying
- **Comprehensive Testing** - 258 tests covering all scenarios
- **URL Parameter Handling** - Robust parsing of complex nested structures

## Documentation

For detailed documentation, architectural decisions, and implementation examples, see [notes.md](./notes.md).

## Production Use

The LiveFilter library is production-ready and handles real-world scenarios including:
- Complex URL parameter encoding/decoding
- Phoenix's automatic parameter parsing
- Browser compatibility and URL encoding
- Type-safe value conversion
- Extensible field type system

## Development

```bash
# Run tests
mix test

# Run with coverage
mix test --cover

# Start development server
mix phx.server

# Interactive shell
iex -S mix phx.server
```

## License

[Add your license here]
