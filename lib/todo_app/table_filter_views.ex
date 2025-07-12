defmodule TodoApp.TableFilterViews do
  @moduledoc """
  GenServer for managing saved filter views in memory.

  Stores filter views per session ID and automatically cleans up
  expired sessions. Views survive page refresh but are
  isolated per browser session.

  ## Usage

      # Get all views for a session
      TableFilterViews.get_views(session_id)
      
      # Save a new view  
      TableFilterViews.save_view(session_id, "My Active Tasks", query_string)
      
      # Delete a view
      TableFilterViews.delete_view(session_id, view_id)
      
      # Update an existing view
      TableFilterViews.update_view(session_id, view_id, "Updated Name", new_query_string)
  """
  use GenServer

  # Client API

  @doc """
  Starts the TableFilterViews GenServer.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets all views for a session ID.
  Returns list of view maps or empty list if no views are stored.
  """
  def get_views(session_id) do
    GenServer.call(__MODULE__, {:get_views, session_id})
  end

  @doc """
  Saves a new view for a session ID.
  Returns {:ok, view} with the created view including its ID.
  """
  def save_view(session_id, name, query_string, color \\ "gray")
      when is_binary(name) and is_binary(query_string) and is_binary(color) do
    GenServer.call(__MODULE__, {:save_view, session_id, name, query_string, color})
  end

  @doc """
  Deletes a view by ID for a session.
  Returns :ok if deleted, {:error, :not_found} if view doesn't exist.
  """
  def delete_view(session_id, view_id) do
    GenServer.call(__MODULE__, {:delete_view, session_id, view_id})
  end

  @doc """
  Updates an existing view's name and/or query string.
  Returns {:ok, view} if updated, {:error, :not_found} if view doesn't exist.
  """
  def update_view(session_id, view_id, name, query_string, color \\ nil)
      when is_binary(name) and is_binary(query_string) do
    GenServer.call(__MODULE__, {:update_view, session_id, view_id, name, query_string, color})
  end

  @doc """
  Cleans up views for sessions older than the specified age.
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
  def handle_call({:get_views, session_id}, _from, state) do
    case Map.get(state, session_id) do
      %{views: views, updated_at: _} -> {:reply, views, state}
      nil -> {:reply, [], state}
    end
  end

  @impl true
  def handle_call({:save_view, session_id, name, query_string, color}, _from, state) do
    # Generate unique ID for the view
    view_id = :erlang.unique_integer([:positive])

    new_view = %{
      id: view_id,
      name: name,
      query_string: query_string,
      color: color,
      created_at: DateTime.utc_now()
    }

    session_data = Map.get(state, session_id, %{views: [], updated_at: DateTime.utc_now()})
    updated_views = session_data.views ++ [new_view]

    updated_session_data = %{
      views: updated_views,
      updated_at: DateTime.utc_now()
    }

    new_state = Map.put(state, session_id, updated_session_data)
    {:reply, {:ok, new_view}, new_state}
  end

  @impl true
  def handle_call({:delete_view, session_id, view_id}, _from, state) do
    case Map.get(state, session_id) do
      %{views: views} = _session_data ->
        if Enum.any?(views, &(&1.id == view_id)) do
          updated_views = Enum.reject(views, &(&1.id == view_id))

          updated_session_data = %{
            views: updated_views,
            updated_at: DateTime.utc_now()
          }

          new_state = Map.put(state, session_id, updated_session_data)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :not_found}, state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_view, session_id, view_id, name, query_string, color}, _from, state) do
    case Map.get(state, session_id) do
      %{views: views} = _session_data ->
        case Enum.find_index(views, &(&1.id == view_id)) do
          nil ->
            {:reply, {:error, :not_found}, state}

          index ->
            view = Enum.at(views, index)
            # Only update color if provided, otherwise keep existing
            updated_view =
              if color do
                %{view | name: name, query_string: query_string, color: color}
              else
                %{view | name: name, query_string: query_string}
              end

            updated_views = List.replace_at(views, index, updated_view)

            updated_session_data = %{
              views: updated_views,
              updated_at: DateTime.utc_now()
            }

            new_state = Map.put(state, session_id, updated_session_data)
            {:reply, {:ok, updated_view}, new_state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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
