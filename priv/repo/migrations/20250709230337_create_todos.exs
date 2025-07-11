defmodule TodoApp.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def change do
    create table(:todos) do
      add :title, :string
      add :description, :text
      add :status, :string
      add :due_date, :date
      add :completed_at, :utc_datetime
      add :estimated_hours, :float
      add :actual_hours, :float
      add :is_urgent, :boolean, default: false, null: false
      add :is_recurring, :boolean, default: false, null: false
      add :tags, {:array, :string}
      add :assigned_to, :string
      add :project, :string
      add :complexity, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:todos, [:status])
    create index(:todos, [:due_date])
    create index(:todos, [:assigned_to])
    create index(:todos, [:project])
    create index(:todos, [:is_urgent])
    create index(:todos, [:tags], using: :gin)
  end
end
