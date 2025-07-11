defmodule LiveFilter.TestRouter do
  @moduledoc """
  A test router for LiveFilter tests.
  This can be included in any Phoenix app's test suite to test LiveFilter functionality.
  """
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveFilter.TestLayouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/test", LiveFilter do
    pipe_through :browser

    live "/live-filter", TestLive, :index
  end
end

defmodule LiveFilter.TestLayouts do
  @moduledoc """
  Minimal layouts for LiveFilter tests.
  """
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>LiveFilter Test</title>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.0/priv/static/phoenix.min.js">
        </script>
        <script
          src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.18.0/priv/static/phoenix_live_view.min.js"
        >
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end
