defmodule TodoApp.Todos.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "todos" do
    field :status, Ecto.Enum, values: [:pending, :in_progress, :completed, :archived]
    field :description, :string
    field :title, :string
    field :project, :string
    field :due_date, :date
    field :completed_at, :utc_datetime
    field :estimated_hours, :float
    field :actual_hours, :float
    field :is_urgent, :boolean, default: false
    field :is_recurring, :boolean, default: false
    field :tags, {:array, :string}
    field :assigned_to, :string
    field :complexity, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [
      :title,
      :description,
      :status,
      :due_date,
      :completed_at,
      :estimated_hours,
      :actual_hours,
      :is_urgent,
      :is_recurring,
      :tags,
      :assigned_to,
      :project,
      :complexity
    ])
    |> validate_required([:title, :status])
    |> validate_number(:complexity, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:estimated_hours, greater_than_or_equal_to: 0)
    |> validate_number(:actual_hours, greater_than_or_equal_to: 0)
  end

  # Option lists for filters and forms
  def status_options do
    [
      %{value: "pending", label: "Pending"},
      %{value: "in_progress", label: "In Progress"},
      %{value: "completed", label: "Completed"},
      %{value: "archived", label: "Archived"}
    ]
  end

  def assignee_options do
    [
      %{value: "john_doe", label: "John Doe"},
      %{value: "jane_smith", label: "Jane Smith"},
      %{value: "bob_johnson", label: "Bob Johnson"},
      %{value: "alice_williams", label: "Alice Williams"},
      %{value: "charlie_brown", label: "Charlie Brown"}
    ]
  end

  def project_options do
    [
      %{value: "phoenix_core", label: "Phoenix Core"},
      %{value: "liveview_app", label: "LiveView App"},
      %{value: "filter_library", label: "Filter Library"},
      %{value: "admin_dashboard", label: "Admin Dashboard"},
      %{value: "api_service", label: "API Service"}
    ]
  end

  def tag_options do
    [
      %{value: "bug", label: "Bug"},
      %{value: "feature", label: "Feature"},
      %{value: "enhancement", label: "Enhancement"},
      %{value: "documentation", label: "Documentation"},
      %{value: "testing", label: "Testing"},
      %{value: "refactoring", label: "Refactoring"},
      %{value: "liveview", label: "LiveView"},
      %{value: "ecto", label: "Ecto"},
      %{value: "performance", label: "Performance"},
      %{value: "security", label: "Security"},
      %{value: "pubsub", label: "PubSub"},
      %{value: "genserver", label: "GenServer"},
      %{value: "deployment", label: "Deployment"},
      %{value: "ui/ux", label: "UI/UX"}
    ]
  end
end
