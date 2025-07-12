defmodule TodoAppWeb.Components.SaveViewModal do
  @moduledoc """
  Modal component for saving a filter view with a name.
  """
  use Phoenix.Component
  import SaladUI.{Dialog, Button, Input, Label}
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal for saving the current filter state as a named view.
  """
  attr :on_save, :string, default: "save_current_view", doc: "Event to trigger when saving"
  attr :on_cancel, JS, default: %JS{}, doc: "JS command to run on cancel"

  def modal(assigns) do
    ~H"""
    <.dialog id="save-view-dialog" open={true}>
      <.dialog_content class="sm:max-w-md">
        <.dialog_header>
          <.dialog_title>Save Filter View</.dialog_title>
          <.dialog_description>
            Save the current filter configuration as a reusable view.
          </.dialog_description>
        </.dialog_header>

        <form phx-submit={@on_save} class="space-y-4">
          <div class="space-y-2">
            <.label for="view-name">View Name</.label>
            <.input
              id="view-name"
              name="name"
              type="text"
              placeholder="e.g., My Active Tasks"
              required
              autofocus
              class="w-full"
            />
          </div>

          <div class="space-y-2">
            <.label>Color</.label>
            <div class="flex flex-wrap gap-2">
              <div :for={color <- color_options()} class="flex items-center">
                <input
                  type="radio"
                  id={"color-#{color.name}"}
                  name="color"
                  value={color.name}
                  checked={color.name == "gray"}
                  class="sr-only peer"
                />
                <label
                  for={"color-#{color.name}"}
                  class={[
                    "flex items-center justify-center w-8 h-8 rounded cursor-pointer border-2 transition-all hover:scale-110 hover:shadow-sm",
                    color.inactive_class,
                    color.active_class,
                    color.border_class
                  ]}
                  title={color.label}
                >
                  <svg
                    class="w-3 h-3 text-slate-700 opacity-0 peer-checked:opacity-100 transition-opacity"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </label>
              </div>
            </div>
            <p class="text-sm text-muted-foreground">
              Choose a color to help organize your views.
            </p>
          </div>

          <.dialog_footer>
            <.button type="button" variant="outline" phx-click={@on_cancel}>
              Cancel
            </.button>
            <.button type="submit">
              Save View
            </.button>
          </.dialog_footer>
        </form>
      </.dialog_content>
    </.dialog>
    """
  end

  # Color options: inactive by default, active when selected
  defp color_options do
    [
      %{
        name: "gray",
        label: "Gray",
        inactive_class: "bg-secondary/40",
        active_class: "peer-checked:bg-secondary/80 peer-checked:text-secondary-foreground",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "blue",
        label: "Blue",
        inactive_class: "bg-blue-100 text-blue-800",
        active_class: "peer-checked:bg-blue-200 peer-checked:text-blue-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "purple",
        label: "Purple",
        inactive_class: "bg-purple-100 text-purple-800",
        active_class: "peer-checked:bg-purple-200 peer-checked:text-purple-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "green",
        label: "Green",
        inactive_class: "bg-emerald-100 text-emerald-800",
        active_class: "peer-checked:bg-emerald-200 peer-checked:text-emerald-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "amber",
        label: "Amber",
        inactive_class: "bg-amber-100 text-amber-800",
        active_class: "peer-checked:bg-amber-200 peer-checked:text-amber-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "rose",
        label: "Rose",
        inactive_class: "bg-rose-100 text-rose-800",
        active_class: "peer-checked:bg-rose-200 peer-checked:text-rose-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "cyan",
        label: "Cyan",
        inactive_class: "bg-cyan-100 text-cyan-800",
        active_class: "peer-checked:bg-cyan-200 peer-checked:text-cyan-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      },
      %{
        name: "indigo",
        label: "Indigo",
        inactive_class: "bg-indigo-100 text-indigo-800",
        active_class: "peer-checked:bg-indigo-200 peer-checked:text-indigo-900",
        border_class: "border-slate-300 peer-checked:border-slate-900"
      }
    ]
  end
end
