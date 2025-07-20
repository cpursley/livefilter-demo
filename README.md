# LiveFilter Demonstration

A Phoenix LiveView application demonstrating [LiveFilter](https://github.com/cpursley/livefilter) - a comprehensive, reusable filtering library for Phoenix LiveView applications, inspired by Notion, Airtable and similar apps with advanced filter builders. It provides for filtering, sorting, and pagination with clean URL state management and a modern UI built on [SaladUI](https://salad-storybook.fly.dev/) and inspired by [shadcn/ui data tables](https://tablecn.com/).

## Overview

This is a read-only todo app that showcases LiveFilter's capabilities. The LiveFilter library (`lib/live_filter/`) will be extracted as a standalone hex package.

## Features

- Real-time filtering with URL persistence
- Text search, single/multi-select, date ranges, boolean toggles, numeric inputs
- Protocol-based extensible field types
- Type-safe filter state management
- Daily data refresh via Quantum scheduler
- UI built with [SaladUI](https://salad-storybook.fly.dev/) components

## Installation

1. **Prerequisites:**
   - Elixir 1.15 or later
   - PostgreSQL
   - Node.js (for assets)

2. **Setup:**
   ```bash
   # Clone the repository
   git clone <repository>
   cd todo_app
   
   # Install dependencies and setup database
   mix setup
   ```

3. **Start the server:**
   ```bash
   mix phx.server
   ```

4. **Visit the demo:**
   Open [localhost:4000/todos](http://localhost:4000/todos)

## LiveFilter Library

The LiveFilter library (`lib/live_filter/`) is designed to be extracted as a standalone hex package. It provides a complete filtering solution for Phoenix LiveView applications.

### Core Architecture

- **`LiveFilter.Mountable`** - LiveView integration with overridable callbacks
- **`LiveFilter.Field`** - Protocol for extensible field types
- **`LiveFilter.FieldRegistry`** - Centralized field configuration
- **`LiveFilter.UIState`** - Filter state management with URL serialization
- **`LiveFilter.QueryBuilder`** - Ecto query generation from filters
- **`LiveFilter.QuickFilters`** - Helper functions for common filter patterns

## Development

```bash
# Run tests
mix test

# Run with coverage  
mix test --cover

# Format code
mix format

# Interactive console
iex -S mix phx.server
```

### Database Seeds

```bash
# Seed the database (also runs automatically on setup)
mix run priv/repo/seeds.exs

# Reset and reseed the database
mix ecto.reset
```

Seeds automatically regenerate daily at 2 AM UTC to keep date filters relevant. The seed data includes todos with various statuses, assignees, due dates, and project categories.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

MIT License - see LICENSE file for details
