defmodule TodoApp.Scheduler do
  @moduledoc """
  Quantum scheduler for TodoApp.

  Handles scheduled jobs like daily data refresh for the demo.
  """

  use Quantum, otp_app: :todo_app
end
