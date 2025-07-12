defmodule TodoApp.Seeds.DataGenerator do
  @moduledoc """
  Generates fresh todo data for the demo application.
  
  This module is used both for initial seeding and daily refresh
  to keep date-based filters relevant.
  """
  
  alias TodoApp.Repo
  alias TodoApp.Todos.Todo
  import Ecto.Query
  require Logger

  @doc """
  Seeds the database with fresh todo data.
  Clears existing todos and generates new ones with current dates.
  """
  def seed_database do
    Logger.info("Starting database seeding...")
    
    # Clear existing todos
    {deleted_count, _} = Repo.delete_all(Todo)
    Logger.info("Deleted #{deleted_count} existing todos.")
    
    # Generate and insert new todos
    todos = generate_todos()
    Logger.info("Seeding #{length(todos)} todos...")
    
    # Insert todos with error handling
    results = Enum.map(todos, fn todo_attrs ->
      case %Todo{}
           |> Todo.changeset(todo_attrs)
           |> Repo.insert() do
        {:ok, todo} ->
          {:ok, todo}
        
        {:error, changeset} ->
          Logger.error("Failed to insert todo: #{inspect(todo_attrs)}")
          Logger.error("Errors: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    
    # Print summary statistics
    print_summary_statistics()
    
    Logger.info("Seeding completed! Inserted #{success_count} todos successfully.")
    :ok
  end

  @doc """
  Generates todo data with relative dates based on current time.
  Returns a list of todo attribute maps.
  """
  def generate_todos do
    # Use current date/time as reference point
    today = Date.utc_today()
    now = DateTime.utc_now()
    
    # Helper functions
    days_ago = fn date, days -> Date.add(date, -days) end
    days_from_now = fn date, days -> Date.add(date, days) end
    
    datetime_days_ago = fn datetime, days ->
      DateTime.add(datetime, -days * 24 * 60 * 60, :second)
    end
    
    random_hours = fn -> :rand.uniform() * 40 end
    random_complexity = fn -> :rand.uniform(10) end
    
    # Define all possible values
    assignees = ["john_doe", "jane_smith", "bob_johnson", "alice_williams", "charlie_brown"]
    projects = ["phoenix_core", "liveview_app", "filter_library", "admin_dashboard", "api_service"]
    
    todos = []
    
    # 1. Urgent tasks due today (5 todos)
    todos = todos ++ generate_urgent_tasks(today, assignees, projects)
    
    # 2. Overdue tasks (10 todos)  
    todos = todos ++ generate_overdue_tasks(today, now, days_ago, assignees, projects, random_hours, random_complexity)
    
    # 3. Completed tasks from the past month (20 todos)
    todos = todos ++ generate_completed_tasks(today, now, days_ago, datetime_days_ago, assignees, projects, random_hours, random_complexity)
    
    # 4. In-progress tasks (15 todos)
    todos = todos ++ generate_in_progress_tasks(today, days_from_now, assignees, projects, random_hours, random_complexity)
    
    # 5. Future tasks (25 todos)
    todos = todos ++ generate_future_tasks(today, days_from_now, assignees, projects, random_hours, random_complexity)
    
    # 6. Recurring tasks (10 todos)
    todos = todos ++ generate_recurring_tasks(today, now, days_from_now, datetime_days_ago, assignees, projects)
    
    # 7. Archived old tasks (10 todos)
    todos = todos ++ generate_archived_tasks(today, days_ago, assignees, projects, random_hours, random_complexity)
    
    # 8. High complexity tasks (10 todos)
    todos = todos ++ generate_complex_tasks(today, days_from_now, assignees, projects, random_hours)
    
    # 9. Bug fixes (15 todos)
    todos = todos ++ generate_bug_fixes(today, days_from_now, assignees, projects, random_hours)
    
    # 10. Feature requests (10 todos)
    todos = todos ++ generate_feature_requests(today, days_from_now, assignees, projects, random_hours)
    
    # Add timestamps to all todos
    add_timestamps_to_todos(todos, today, now, datetime_days_ago)
  end

  # Private helper functions

  defp generate_urgent_tasks(today, assignees, _projects) do
    urgent_issues = [
      {"Fix LiveView websocket disconnection under heavy load", "Users experiencing random disconnections when server processes 1000+ concurrent LiveView connections. Need to investigate Ranch configuration and implement connection pooling.", ["liveview", "performance", "bug"]},
      {"Resolve Ecto pool timeout in checkout flow", "Database connection pool exhausted during peak hours causing 500 errors. Need to optimize N+1 queries in OrderController and increase pool size.", ["ecto", "bug", "performance"]},
      {"Patch CSRF token validation bypass", "Security audit revealed potential CSRF vulnerability in custom upload component. Must validate tokens properly in handle_event callbacks.", ["security", "liveview", "bug"]},
      {"Fix PubSub message ordering in distributed setup", "Messages arriving out of order when running multiple nodes. Critical for real-time collaboration features. Investigate Phoenix.PubSub adapter configuration.", ["pubsub", "bug", "genserver"]},
      {"Memory leak in LiveView process state", "LiveView processes consuming excessive memory after 24h uptime. Telemetry shows assigns growing unbounded. Need to implement proper cleanup in terminate callback.", ["liveview", "performance", "bug"]}
    ]
    
    Enum.map(urgent_issues, fn {title, desc, tags} ->
      %{
        title: title,
        description: desc,
        status: Enum.random([:pending, :in_progress]),
        due_date: today,
        estimated_hours: Float.round(2.0 + :rand.uniform() * 4, 1),
        actual_hours: if(:rand.uniform(100) > 50, do: Float.round(1.0 + :rand.uniform() * 3, 1), else: nil),
        is_urgent: true,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees),
        project: Enum.random(["phoenix_core", "liveview_app"]),
        complexity: 7 + :rand.uniform(3)
      }
    end)
  end

  defp generate_overdue_tasks(today, _now, days_ago, assignees, projects, random_hours, random_complexity) do
    overdue_tasks = [
      {"Implement LiveView presence tracking", "Add presence tracking to show online users in collaborative editor. Requires Phoenix.Presence integration with LiveView hooks.", ["liveview", "feature", "pubsub"]},
      {"Upgrade to Phoenix 1.7.14", "Security patches and performance improvements available. Need to update router syntax and test all LiveView components.", ["deployment", "security", "testing"]},
      {"Write ExDoc documentation for GenServer modules", "Public API lacks proper documentation. Add @moduledoc, @doc, and doctests for all GenServer behaviours.", ["documentation", "genserver"]},
      {"Optimize Ecto preload queries", "Dashboard loading 3+ seconds due to nested preloads. Implement custom preload functions with select statements.", ["ecto", "performance", "refactoring"]},
      {"Add telemetry instrumentation to background jobs", "No visibility into Oban job performance. Implement :telemetry events for job duration and failure tracking.", ["feature", "performance", "genserver"]},
      {"Migrate from npm to esbuild", "Simplify asset pipeline by removing node dependency. Configure esbuild for Phoenix 1.7 asset management.", ["deployment", "refactoring"]},
      {"Fix flaky LiveView integration tests", "Random failures in CI due to timing issues. Add proper wait_for helpers and stabilize async test execution.", ["testing", "liveview", "bug"]},
      {"Implement rate limiting for API endpoints", "API vulnerable to abuse. Add Hammer or implement custom GenServer-based rate limiter.", ["security", "feature", "genserver"]},
      {"Refactor LiveComponent to use streams", "TodoList component re-rendering entire list. Convert to use Phoenix.LiveView.stream for better performance.", ["liveview", "performance", "refactoring"]},
      {"Set up Dialyzer for type checking", "No static type analysis in place. Configure Dialyxir and add initial typespecs to critical modules.", ["testing", "enhancement"]}
    ]
    
    Enum.map(overdue_tasks, fn {title, desc, tags} ->
      days_overdue = :rand.uniform(30)
      
      %{
        title: title,
        description: desc <> " (#{days_overdue} days overdue)",
        status: Enum.random([:pending, :in_progress]),
        due_date: days_ago.(today, days_overdue),
        estimated_hours: Float.round(random_hours.(), 1),
        actual_hours: nil,
        is_urgent: days_overdue > 14,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees ++ [nil]),
        project: Enum.random(projects),
        complexity: random_complexity.()
      }
    end)
  end

  defp generate_completed_tasks(today, now, days_ago, datetime_days_ago, assignees, projects, random_hours, random_complexity) do
    completed_tasks = [
      {"Built real-time collaborative text editor", "Implemented OT (Operational Transformation) algorithm using Phoenix.Presence and LiveView. Supports concurrent editing with conflict resolution.", ["liveview", "feature", "pubsub", "ui/ux"]},
      {"Migrated authentication to Pow library", "Replaced custom auth with Pow. Added MFA support, session management, and proper password reset flow.", ["security", "feature", "refactoring"]},
      {"Implemented GraphQL subscriptions", "Added Absinthe subscriptions for real-time data updates. Integrated with Phoenix.PubSub for efficient message broadcasting.", ["feature", "pubsub", "performance"]},
      {"Optimized database indexes for search", "Reduced search query time from 2s to 50ms by adding GIN indexes for full-text search and proper compound indexes.", ["ecto", "performance", "refactoring"]},
      {"Created LiveView component library", "Built reusable LiveView components: DataTable, FilterBar, Modal, and FormBuilder. Added Storybook for component documentation.", ["liveview", "feature", "ui/ux", "documentation"]},
      {"Fixed N+1 query issues in API", "Identified and resolved 15 N+1 queries using Ecto.Query.preload and custom join queries. API response time improved by 60%.", ["ecto", "bug", "performance"]},
      {"Deployed multi-region Phoenix cluster", "Set up libcluster for automatic node discovery across AWS regions. Configured global Phoenix.PubSub for cross-region messaging.", ["deployment", "pubsub", "performance"]},
      {"Added comprehensive ExUnit test suite", "Achieved 92% test coverage. Added property-based tests with StreamData and integration tests for LiveView components.", ["testing", "liveview"]},
      {"Integrated Oban for background jobs", "Replaced manual GenServer workers with Oban. Added job scheduling, retries, and telemetry integration.", ["genserver", "feature", "performance"]},
      {"Built admin dashboard with LiveView", "Created full-featured admin panel using LiveView, including real-time analytics, user management, and system monitoring.", ["liveview", "feature", "ui/ux"]},
      {"Implemented event sourcing with EventStore", "Added event sourcing for audit trail. Integrated commanded library for CQRS pattern implementation.", ["feature", "ecto", "refactoring"]},
      {"Upgraded Elixir to 1.17", "Updated codebase for Elixir 1.17. Refactored to use new language features and fixed deprecation warnings.", ["deployment", "refactoring"]},
      {"Created Phoenix installer template", "Built custom Phoenix installer for company projects. Includes standard dependencies, CI/CD setup, and coding standards.", ["feature", "deployment", "documentation"]},
      {"Optimized LiveView diff tracking", "Reduced payload size by 70% through strategic use of temporary assigns and phx-update='ignore' attributes.", ["liveview", "performance", "refactoring"]},
      {"Implemented SSO with SAML", "Added SAML 2.0 support for enterprise SSO. Integrated with Samly library and tested with Okta, Auth0.", ["security", "feature"]},
      {"Built real-time notification system", "Created notification system using Phoenix.Channel and LiveView. Supports in-app, email, and webhook notifications.", ["liveview", "feature", "pubsub"]},
      {"Dockerized Phoenix application", "Created multi-stage Docker build for 90% smaller images. Added docker-compose for local development.", ["deployment", "performance"]},
      {"Implemented API versioning", "Added versioning strategy for REST API. Created v2 endpoints while maintaining backwards compatibility.", ["feature", "refactoring"]},
      {"Created Ecto data migration toolkit", "Built mix tasks for complex data migrations. Includes rollback support and progress tracking.", ["ecto", "feature", "deployment"]},
      {"Added distributed caching layer", "Implemented Cachex with cross-node invalidation. Reduced database load by 40% for frequently accessed data.", ["genserver", "performance", "feature"]}
    ]
    
    Enum.map(completed_tasks, fn {title, desc, tags} ->
      days_ago_completed = :rand.uniform(30)
      estimated = Float.round(random_hours.(), 1)
      actual = Float.round(estimated * (0.5 + :rand.uniform()), 1)
      
      %{
        title: title,
        description: desc,
        status: :completed,
        due_date: days_ago.(today, days_ago_completed - 5),
        completed_at: datetime_days_ago.(now, days_ago_completed),
        estimated_hours: estimated,
        actual_hours: actual,
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees),
        project: Enum.random(projects),
        complexity: random_complexity.()
      }
    end)
  end

  defp generate_in_progress_tasks(today, days_from_now, assignees, projects, random_hours, random_complexity) do
    in_progress_tasks = [
      {"Implementing LiveFilter library extraction", "Extracting filtering logic into standalone hex package. Currently working on protocol definitions and API design.", ["liveview", "feature", "refactoring"]},
      {"Building Phoenix LiveView file upload", "Creating drag-and-drop file upload with progress tracking. Integrating with S3 using ExAws for direct uploads.", ["liveview", "feature", "ui/ux"]},
      {"Refactoring GenServer to use Registry", "Converting singleton GenServers to use Registry for dynamic process management. Adding proper supervision tree.", ["genserver", "refactoring", "performance"]},
      {"Developing Ecto multi-tenant system", "Implementing row-level security with Ecto. Using prefix strategy for schema isolation per tenant.", ["ecto", "feature", "security"]},
      {"Creating Phoenix API documentation", "Writing OpenAPI 3.0 specs for all endpoints. Integrating with open_api_spex for automatic validation.", ["documentation", "feature"]},
      {"Optimizing LiveView memory usage", "Profiling LiveView processes with :recon. Implementing temporary assigns and reducing socket state size.", ["liveview", "performance", "refactoring"]},
      {"Migrating from Webpack to Vite", "Updating asset pipeline for faster builds. Configuring Vite with Phoenix for HMR support.", ["deployment", "performance", "refactoring"]},
      {"Integrating Stripe payment processing", "Adding subscription billing with Stripe. Implementing webhooks for payment events using Oban.", ["feature", "security"]},
      {"Building LiveView form wizard", "Multi-step form with state persistence. Using LiveView.JS commands for smooth transitions.", ["liveview", "feature", "ui/ux"]},
      {"Implementing Commanded event store", "Adding CQRS pattern for complex domain logic. Setting up projections and process managers.", ["genserver", "feature", "ecto"]},
      {"Creating Phoenix hook system", "Building plugin architecture for extending core functionality. Using behaviours and dynamic module loading.", ["feature", "refactoring"]},
      {"Developing real-time analytics dashboard", "Building dashboard with LiveView and Contex charts. Streaming data updates via Phoenix.PubSub.", ["liveview", "feature", "ui/ux", "pubsub"]},
      {"Optimizing Ecto query compilation", "Reducing query compilation time using prepared statements. Implementing query result caching.", ["ecto", "performance", "refactoring"]},
      {"Adding LiveView testing helpers", "Creating custom ExUnit assertions for LiveView. Building page object pattern for integration tests.", ["testing", "liveview", "feature"]},
      {"Implementing Phoenix rate limiter", "Building token bucket rate limiter as Plug middleware. Using ETS for distributed rate limit tracking.", ["security", "feature", "genserver"]}
    ]
    
    Enum.map(in_progress_tasks, fn {title, desc, tags} ->
      estimated = Float.round(10.0 + random_hours.(), 1)
      progress_percent = :rand.uniform(80)
      actual = Float.round(estimated * progress_percent / 100, 1)
      
      %{
        title: title,
        description: desc <> " Currently #{progress_percent}% complete.",
        status: :in_progress,
        due_date: days_from_now.(today, :rand.uniform(14)),
        estimated_hours: estimated,
        actual_hours: actual,
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees),
        project: Enum.random(projects),
        complexity: random_complexity.()
      }
    end)
  end

  defp generate_future_tasks(today, days_from_now, assignees, projects, random_hours, random_complexity) do
    future_tasks = [
      {"Research Phoenix LiveView Native", "Evaluate LiveView Native for mobile app development. Create POC for iOS/Android apps sharing LiveView logic.", ["liveview", "feature", "ui/ux"]},
      {"Design microservices communication", "Architecture for splitting monolith into services. Evaluate Broadway vs GenStage for event streaming.", ["genserver", "feature", "pubsub"]},
      {"Plan Kubernetes deployment strategy", "Design K8s manifests for Phoenix cluster. Include auto-scaling, health checks, and rolling updates.", ["deployment", "performance"]},
      {"Implement machine learning pipeline", "Integrate Nx for ML model serving. Build recommendation engine using collaborative filtering.", ["feature", "performance"]},
      {"Create GraphQL federation gateway", "Design federated GraphQL architecture. Implement Apollo Federation with Absinthe.", ["feature", "refactoring"]},
      {"Build LiveView component marketplace", "Platform for sharing reusable LiveView components. Include versioning and dependency management.", ["liveview", "feature", "ui/ux"]},
      {"Develop Phoenix cluster monitoring", "Real-time monitoring for distributed Phoenix nodes. Track PubSub metrics and node health.", ["genserver", "feature", "performance"]},
      {"Research WASM integration", "Evaluate running Elixir in browser via WASM. Explore Lumen project for client-side Elixir.", ["feature", "performance"]},
      {"Design event-driven architecture", "Implement event sourcing with Kafka integration. Use Broadway for event processing pipeline.", ["genserver", "feature", "pubsub"]},
      {"Plan zero-downtime deployments", "Design blue-green deployment strategy. Implement database migration coordination.", ["deployment", "feature"]},
      {"Create LiveView accessibility toolkit", "Build a11y testing tools for LiveView. Add ARIA live regions support.", ["liveview", "feature", "testing"]},
      {"Implement distributed tracing", "Add OpenTelemetry integration. Trace requests across Phoenix nodes and services.", ["performance", "feature", "deployment"]},
      {"Design multi-database architecture", "Implement Ecto adapters for multiple databases. Add read replica support.", ["ecto", "feature", "performance"]},
      {"Build Phoenix API gateway", "Create API gateway with rate limiting, auth, and routing. Implement circuit breakers.", ["feature", "security", "performance"]},
      {"Research Gleam integration", "Evaluate Gleam for type-safe modules. Create interop layer with Elixir.", ["feature", "testing"]},
      {"Plan LiveView offline support", "Design offline-first LiveView apps. Implement local state sync with CRDTs.", ["liveview", "feature", "ui/ux"]},
      {"Create Ecto performance analyzer", "Build query analysis tool. Suggest index improvements and N+1 detection.", ["ecto", "performance", "feature"]},
      {"Implement service mesh", "Add Istio integration for Phoenix microservices. Handle service discovery and load balancing.", ["deployment", "feature", "performance"]},
      {"Design Phoenix plugin system", "Create extensible plugin architecture. Support runtime loading and hot code swapping.", ["feature", "genserver"]},
      {"Build distributed task scheduler", "Implement cron-like scheduler across cluster. Use consistent hashing for job distribution.", ["genserver", "feature", "deployment"]},
      {"Research blockchain integration", "Evaluate Web3 libraries for Elixir. Build smart contract interaction layer.", ["feature", "security"]},
      {"Plan LiveView testing framework", "Create BDD testing framework for LiveView. Support visual regression testing.", ["testing", "liveview", "feature"]},
      {"Implement API mocking service", "Build service virtualization for testing. Support dynamic response generation.", ["testing", "feature"]},
      {"Design data pipeline architecture", "Create ETL pipeline with Flow. Implement data warehouse integration.", ["ecto", "feature", "performance"]},
      {"Build LiveView IDE plugin", "Create VS Code extension for LiveView. Add component autocomplete and live preview.", ["liveview", "feature", "documentation"]}
    ]
    
    Enum.map(future_tasks, fn {title, desc, tags} ->
      days_future = 5 + :rand.uniform(60)
      
      %{
        title: title,
        description: desc,
        status: :pending,
        due_date: days_from_now.(today, days_future),
        estimated_hours: Float.round(random_hours.(), 1),
        actual_hours: nil,
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: if(:rand.uniform(100) > 30, do: Enum.random(assignees), else: nil),
        project: Enum.random(projects),
        complexity: random_complexity.()
      }
    end)
  end

  defp generate_recurring_tasks(today, now, days_from_now, datetime_days_ago, assignees, _projects) do
    recurring_types = [
      {"Review Dependabot PRs", 7, 1.5, "Review and merge dependency updates. Check for breaking changes and update tests.", ["security", "deployment"]},
      {"Update LiveView components docs", 7, 3.0, "Keep component documentation in sync with code changes. Update examples and type specs.", ["documentation", "liveview"]},
      {"Run Dialyzer type checks", 3, 1.0, "Execute Dialyzer analysis on codebase. Fix any type inconsistencies found.", ["testing", "refactoring"]},
      {"Monitor Oban job performance", 7, 2.0, "Review job execution metrics. Optimize slow jobs and adjust concurrency settings.", ["genserver", "performance"]},
      {"Backup database snapshots", 1, 0.5, "Verify automated backups completed. Test restore procedure monthly.", ["deployment", "ecto"]},
      {"Phoenix security patches", 14, 4.0, "Check for security advisories. Apply patches and test affected functionality.", ["security", "deployment"]},
      {"Profile LiveView memory usage", 7, 2.5, "Run memory profiling on production. Identify and fix memory leaks.", ["liveview", "performance"]},
      {"Clean up old Ecto migrations", 30, 3.0, "Squash old migrations. Update schema.rb and test fresh installs.", ["ecto", "deployment"]},
      {"Review error tracking alerts", 1, 1.0, "Check Sentry/AppSignal for new errors. Prioritize fixes based on occurrence.", ["bug", "performance"]},
      {"Update API documentation", 14, 4.0, "Sync OpenAPI specs with code changes. Generate updated client SDKs.", ["documentation", "feature"]}
    ]
    
    Enum.flat_map(recurring_types, fn {title, interval, hours, desc, tags} ->
      Enum.map(1..1, fn _i ->
        %{
          title: title,
          description: desc,
          status: if(:rand.uniform(100) > 50, do: :pending, else: :completed),
          due_date: days_from_now.(today, rem(interval, 31)),
          completed_at: if(:rand.uniform(100) > 50, do: datetime_days_ago.(now, interval), else: nil),
          estimated_hours: hours,
          actual_hours: if(:rand.uniform(100) > 50, do: hours, else: nil),
          is_urgent: false,
          is_recurring: true,
          tags: tags,
          assigned_to: Enum.random(assignees),
          project: Enum.random(["phoenix_core", "liveview_app", "api_service"]),
          complexity: 2 + :rand.uniform(3)
        }
      end)
    end)
  end

  defp generate_archived_tasks(today, days_ago, assignees, projects, random_hours, random_complexity) do
    archived_tasks = [
      {"Migrate from Phoenix 1.5 contexts", "Legacy migration task for old context structure. Superseded by new domain design.", ["refactoring", "deployment"]},
      {"Remove deprecated Ecto associations", "Clean up has_many through associations. Replaced with many_to_many in v3.", ["ecto", "refactoring"]},
      {"Update legacy JavaScript views", "Convert old Brunch/jQuery views to LiveView. Project cancelled in favor of full rewrite.", ["ui/ux", "liveview"]},
      {"Deprecate REST API v1", "Sunset old API version. All clients migrated to GraphQL.", ["feature", "deployment"]},
      {"Remove Phoenix.HTML.Raw usage", "Security audit flagged raw HTML rendering. Replaced with safe alternatives.", ["security", "refactoring"]},
      {"Migrate from Distillery to Mix releases", "Update deployment scripts for Mix releases. Completed in Q3 2023.", ["deployment", "refactoring"]},
      {"Replace Poison with Jason", "JSON library migration. All modules updated to use Jason.", ["refactoring", "performance"]},
      {"Remove deprecated Phoenix.Channel callbacks", "Update to new callback signatures. Part of Phoenix 1.6 upgrade.", ["pubsub", "refactoring"]},
      {"Migrate from Webpack to esbuild", "Asset bundling modernization. Completed but kept for reference.", ["deployment", "performance"]},
      {"Clean up pre-LiveView controllers", "Remove old controller actions replaced by LiveView. Historical reference only.", ["refactoring", "liveview"]}
    ]
    
    Enum.map(archived_tasks, fn {title, desc, tags} ->
      %{
        title: title,
        description: desc,
        status: :archived,
        due_date: days_ago.(today, 60 + :rand.uniform(120)),
        estimated_hours: Float.round(random_hours.(), 1),
        actual_hours: nil,
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees ++ [nil]),
        project: Enum.random(projects),
        complexity: random_complexity.()
      }
    end)
  end

  defp generate_complex_tasks(today, days_from_now, _assignees, _projects, random_hours) do
    complex_tasks = [
      {"Architect distributed CRDT system", "Design conflict-free replicated data types for offline-first LiveView. Implement vector clocks and merge strategies.", ["liveview", "genserver", "feature"]},
      {"Redesign Ecto query optimizer", "Build intelligent query planner that automatically optimizes N+1 queries. Use metaprogramming for compile-time optimization.", ["ecto", "performance", "feature"]},
      {"Rewrite LiveView diff engine", "Optimize DOM diffing algorithm for 10x performance improvement. Implement virtual DOM with minimal memory footprint.", ["liveview", "performance", "refactoring"]},
      {"Scale Phoenix to 1M connections", "Design architecture for million concurrent websocket connections. Implement custom Ranch acceptor pool and connection draining.", ["performance", "deployment", "pubsub"]},
      {"Build distributed GenServer registry", "Create globally distributed process registry with consistent hashing. Handle network partitions and split-brain scenarios.", ["genserver", "feature", "deployment"]},
      {"Implement custom Ecto adapter", "Build Ecto adapter for time-series database. Support specialized queries and data retention policies.", ["ecto", "feature", "performance"]},
      {"Create LiveView server-side rendering", "Implement SSR for LiveView with hydration. Optimize for SEO and initial page load performance.", ["liveview", "performance", "feature"]},
      {"Design multi-tenant isolation", "Build complete tenant isolation at database and application level. Implement row-level security with performance optimization.", ["ecto", "security", "feature"]},
      {"Optimize BEAM scheduler for ML", "Tune BEAM scheduler for machine learning workloads. Integrate with Nx for GPU computation scheduling.", ["performance", "feature", "deployment"]},
      {"Build Phoenix service mesh", "Create native Elixir service mesh without external dependencies. Implement circuit breakers, retries, and observability.", ["genserver", "deployment", "performance"]}
    ]
    
    Enum.map(complex_tasks, fn {title, desc, tags} ->
      %{
        title: title,
        description: desc <> " Requires extensive research and proof of concept phase.",
        status: Enum.random([:pending, :in_progress]),
        due_date: days_from_now.(today, 30 + :rand.uniform(30)),
        estimated_hours: Float.round(40.0 + random_hours.(), 1),
        actual_hours: if(Enum.random([true, false]), do: Float.round(random_hours.(), 1), else: nil),
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(["john_doe", "jane_smith"]),
        project: Enum.random(["phoenix_core", "liveview_app"]),
        complexity: 8 + :rand.uniform(2)
      }
    end)
  end

  defp generate_bug_fixes(today, days_from_now, assignees, projects, random_hours) do
    bug_fixes = [
      {"LiveView form losing focus on validation", "Input field loses focus after changeset validation. Caused by improper phx-feedback-for usage.", "Minor", ["liveview", "bug", "ui/ux"]},
      {"Ecto changeset race condition", "Concurrent updates causing constraint violations. Need to implement optimistic locking.", "Major", ["ecto", "bug", "security"]},
      {"Phoenix.PubSub dropping messages", "Messages lost under high load. Buffer overflow in PubSub adapter.", "Critical", ["pubsub", "bug", "performance"]},
      {"LiveView memory leak in hooks", "JavaScript hooks not cleaning up event listeners. Memory grows unbounded.", "Major", ["liveview", "bug", "performance"]},
      {"Oban jobs stuck in executing state", "Jobs not releasing after completion. Database connection leak suspected.", "Critical", ["genserver", "bug", "ecto"]},
      {"LiveView upload progress incorrect", "Progress bar showing 100% before upload complete. Chunking calculation error.", "Minor", ["liveview", "bug", "ui/ux"]},
      {"Ecto association preload N+1", "Nested preloads causing exponential queries. Missing join optimization.", "Major", ["ecto", "bug", "performance"]},
      {"Phoenix router compilation timeout", "Large router files causing compilation timeout. Need to split routes.", "Minor", ["bug", "performance", "deployment"]},
      {"LiveView assigns not updating", "Nested assigns changes not triggering re-render. Immutability issue.", "Major", ["liveview", "bug"]},
      {"GenServer timeout under load", "Process mailbox overflow causing timeouts. Need backpressure mechanism.", "Critical", ["genserver", "bug", "performance"]},
      {"Telemetry events missing metadata", "Custom telemetry events losing context. Metadata not properly attached.", "Minor", ["bug", "performance"]},
      {"LiveView test flakiness", "Integration tests randomly failing. Async rendering timing issues.", "Major", ["liveview", "bug", "testing"]},
      {"Ecto migration rollback fails", "Down migration missing reverse operations. Data loss risk.", "Critical", ["ecto", "bug", "deployment"]},
      {"Phoenix Channel join race", "Channel join/leave causing state corruption. Need proper synchronization.", "Major", ["pubsub", "bug", "genserver"]},
      {"CSRF token expiry handling", "Users getting logged out due to token expiry. Need graceful refresh.", "Minor", ["security", "bug", "liveview"]}
    ]
    
    Enum.map(bug_fixes, fn {title, desc, severity, tags} ->
      %{
        title: "Bug: #{severity} - #{title}",
        description: desc <> " Issue ##{1000 + :rand.uniform(100)}. Affects #{:rand.uniform(1000)} users.",
        status: Enum.random([:pending, :in_progress, :completed]),
        due_date: if(severity == "Critical", do: today, else: days_from_now.(today, :rand.uniform(7))),
        estimated_hours: Float.round(0.5 + random_hours.() / 4, 1),
        actual_hours: if(Enum.random([true, false]), do: Float.round(random_hours.() / 4, 1), else: nil),
        is_urgent: severity == "Critical",
        is_recurring: false,
        tags: tags,
        assigned_to: Enum.random(assignees),
        project: Enum.random(projects),
        complexity: case severity do
          "Critical" -> 7 + :rand.uniform(3)
          "Major" -> 5 + :rand.uniform(3)
          _ -> 1 + :rand.uniform(4)
        end
      }
    end)
  end

  defp generate_feature_requests(today, days_from_now, _assignees, projects, random_hours) do
    feature_requests = [
      {"Add LiveView presence indicators", "Show real-time user presence in collaborative features. Display typing indicators and cursor positions.", 87, "High", ["liveview", "feature", "pubsub", "ui/ux"]},
      {"Implement Phoenix.Tracker for distributed state", "Use Phoenix.Tracker for maintaining distributed state across nodes. Enable cross-region state synchronization.", 65, "High", ["pubsub", "feature", "genserver"]},
      {"Create Ecto sandbox mode for demos", "Safe read-only mode for demo environments. Rollback all changes after session ends.", 42, "Medium", ["ecto", "feature", "security"]},
      {"Build LiveView component inspector", "Developer tool for inspecting LiveView component tree. Show assigns and event handlers in dev mode.", 93, "High", ["liveview", "feature", "testing"]},
      {"Add Telemetry dashboard", "Real-time metrics dashboard using Telemetry.Metrics. Include custom business metrics.", 78, "High", ["feature", "performance", "ui/ux"]},
      {"Implement LiveView SEO helpers", "Server-side rendering for meta tags. Dynamic social media previews for LiveView pages.", 56, "Medium", ["liveview", "feature", "performance"]},
      {"Create Phoenix API versioning", "Automatic API versioning with deprecation warnings. Support multiple API versions concurrently.", 71, "High", ["feature", "deployment"]},
      {"Add Ecto query builder UI", "Visual query builder for admin panel. Generate Ecto queries from UI selections.", 34, "Low", ["ecto", "feature", "ui/ux"]},
      {"Build distributed rate limiter", "Cluster-wide rate limiting using GenServer. Support multiple strategies and time windows.", 89, "High", ["genserver", "feature", "security"]},
      {"Implement LiveView offline mode", "Queue actions when offline. Sync when connection restored using Phoenix.Presence.", 95, "High", ["liveview", "feature", "ui/ux"]}
    ]
    
    Enum.map(feature_requests, fn {title, desc, upvotes, priority, tags} ->
      %{
        title: "Feature: #{title}",
        description: desc <> " Requested by users with #{upvotes} upvotes. Business value: #{priority}.",
        status: :pending,
        due_date: days_from_now.(today, 14 + :rand.uniform(45)),
        estimated_hours: Float.round(8.0 + random_hours.(), 1),
        actual_hours: nil,
        is_urgent: false,
        is_recurring: false,
        tags: tags,
        assigned_to: nil,
        project: Enum.random(projects),
        complexity: 3 + :rand.uniform(5)
      }
    end)
  end

  defp add_timestamps_to_todos(todos, today, now, datetime_days_ago) do
    Enum.map(todos, fn todo_attrs ->
      # Add timestamps based on the todo's characteristics
      inserted_at = cond do
        # Completed tasks were created before they were completed
        todo_attrs[:completed_at] ->
          datetime_days_ago.(todo_attrs.completed_at, 7 + :rand.uniform(14))
        
        # Overdue tasks were created before their due date
        todo_attrs[:due_date] && Date.compare(todo_attrs.due_date, today) == :lt ->
          due_datetime = DateTime.new!(todo_attrs.due_date, ~T[00:00:00], "Etc/UTC")
          datetime_days_ago.(due_datetime, 7 + :rand.uniform(14))
        
        # Future tasks were created recently
        todo_attrs[:due_date] && Date.compare(todo_attrs.due_date, today) == :gt ->
          datetime_days_ago.(now, :rand.uniform(7))
        
        # Default: created within the last month
        true ->
          datetime_days_ago.(now, :rand.uniform(30))
      end
      
      # Add timestamps to the attributes
      Map.merge(todo_attrs, %{
        inserted_at: inserted_at,
        updated_at: inserted_at  # Initially, updated_at equals inserted_at
      })
    end)
  end

  defp print_summary_statistics do
    todo_count = Repo.aggregate(Todo, :count)
    Logger.info("Database now contains #{todo_count} todos.")
    
    # Print distribution statistics
    Logger.info("Todo distribution:")
    Logger.info("By status:")
    
    [:pending, :in_progress, :completed, :archived]
    |> Enum.each(fn status ->
      count = Repo.aggregate(from(t in Todo, where: t.status == ^status), :count)
      Logger.info("  #{status}: #{count}")
    end)
    
    Logger.info("By assignee:")
    
    ["john_doe", "jane_smith", "bob_johnson", "alice_williams", "charlie_brown"]
    |> Enum.each(fn assignee ->
      count = Repo.aggregate(from(t in Todo, where: t.assigned_to == ^assignee), :count)
      Logger.info("  #{assignee}: #{count}")
    end)
    
    unassigned_count = Repo.aggregate(from(t in Todo, where: is_nil(t.assigned_to)), :count)
    Logger.info("  unassigned: #{unassigned_count}")
    
    urgent_count = Repo.aggregate(from(t in Todo, where: t.is_urgent == true), :count)
    recurring_count = Repo.aggregate(from(t in Todo, where: t.is_recurring == true), :count)
    Logger.info("Special flags:")
    Logger.info("  Urgent: #{urgent_count}")
    Logger.info("  Recurring: #{recurring_count}")
  end
end