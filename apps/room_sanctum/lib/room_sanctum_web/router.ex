defmodule RoomSanctumWeb.Router do
  use RoomSanctumWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RoomSanctumWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RoomSanctumWeb do
    pipe_through :browser

    get "/", PageController, :index
    live "/cfg/sources", SourceLive.Index, :index
    live "/cfg/sources/new", SourceLive.Index, :new
    live "/cfg/sources/:id/edit", SourceLive.Index, :edit

    live "/cfg/sources/:id", SourceLive.Show, :show
    live "/cfg/sources/:id/show/edit", SourceLive.Show, :edit


    live "/cfg/queries", QueryLive.Index, :index
    live "/cfg/queries/new", QueryLive.Index, :new
    live "/cfg/queries/:id/edit", QueryLive.Index, :edit

    live "/cfg/queries/:id", QueryLive.Show, :show
    live "/cfg/queries/:id/show/edit", QueryLive.Show, :edit

  end

  # Other scopes may use custom stacks.
  # scope "/api", RoomSanctumWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RoomSanctumWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
