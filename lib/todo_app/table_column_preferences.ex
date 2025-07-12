defmodule TodoApp.TableColumnPreferences do
  @moduledoc """
  GenServer for managing table column visibility preferences in memory.

  Stores column preferences per session ID and automatically cleans up
  expired sessions. Preferences survive page refresh but are
  isolated per browser session.

  ## Usage

      # Get column preferences for a session
      TableColumnPreferences.get_column_preferences(session_id)
      
      # Set column preferences for a session  
      TableColumnPreferences.set_column_preferences(session_id, [:title, :status, :due_date])
      
      # Clean up expired sessions
      TableColumnPreferences.cleanup_expired()
  """
  use GenServer

  # Client API

  @doc """
  Starts the TableColumnPreferences GenServer.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets column preferences for a session ID.
  Returns list of column atoms or nil if no preferences are stored.
  """
  def get_column_preferences(session_id) do
    GenServer.call(__MODULE__, {:get_column_preferences, session_id})
  end

  @doc """
  Sets column preferences for a session ID.
  """
  def set_column_preferences(session_id, columns) when is_list(columns) do
    GenServer.cast(__MODULE__, {:set_column_preferences, session_id, columns})
  end

  @doc """
  Cleans up preferences for sessions older than the specified age.
  Default is 24 hours.
  """
  def cleanup_expired(max_age_hours \\ 24) do
    GenServer.cast(__MODULE__, {:cleanup_expired, max_age_hours})
  end

  @doc """
  Gets the current state (for debugging).
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(_args) do
    # Schedule periodic cleanup every hour
    Process.send_after(self(), :cleanup, :timer.hours(1))
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_column_preferences, session_id}, _from, state) do
    case Map.get(state, session_id) do
      %{columns: columns, updated_at: _} -> {:reply, columns, state}
      nil -> {:reply, nil, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:set_column_preferences, session_id, columns}, state) do
    session_data = %{
      columns: columns,
      updated_at: DateTime.utc_now()
    }

    new_state = Map.put(state, session_id, session_data)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:cleanup_expired, max_age_hours}, state) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -max_age_hours, :hour)

    new_state =
      Enum.reduce(state, %{}, fn {session_id, session_data}, acc ->
        if DateTime.compare(session_data.updated_at, cutoff_time) == :gt do
          Map.put(acc, session_id, session_data)
        else
          acc
        end
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Periodic cleanup - remove sessions older than 24 hours
    send(self(), {:cleanup_expired, 24})

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, :timer.hours(1))

    {:noreply, state}
  end

  @impl true
  def handle_info({:cleanup_expired, max_age_hours}, state) do
    handle_cast({:cleanup_expired, max_age_hours}, state)
  end
end
