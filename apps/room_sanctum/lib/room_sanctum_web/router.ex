defmodule RoomSanctumWeb.Router do
  use RoomSanctumWeb, :router

  forward("/health/live", Healthchex.Probes.Liveness)
  forward("/health/ready", Healthchex.Probes.Readiness)

  import RoomSanctumWeb.UserAuth

  pipeline :browser do
    plug :accepts, [
      "html",
      "jetpack",
      "swiftui"
    ]

    plug :fetch_session
    plug :fetch_live_flash

    plug :put_root_layout,
      html: {RoomSanctumWeb.Layouts, :root},
      jetpack: {MyAppWeb.Layouts.Jetpack, :root},
      swiftui: {MyAppWeb.Layouts.SwiftUI, :root}

    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RoomSanctumWeb do
    pipe_through [:browser]
    live "/", LandingLive.Index, :index
    #    live "/p/p/:name", PythiaeLive.Public, :show

    live_session :public, root_layout: {RoomSanctumWeb.Layouts, :root_public} do
      live "/p/p/:name", PythiaeLive.Public, :show
      live "/p/s/c/:id", ScribusLive.Public, :show # color version
    end
    live_session :public_inky, root_layout: {RoomSanctumWeb.Layouts, :root_public_inky} do
      live "/p/s/i/:id", ScribusLive.Public, :show # monochrome
    end
    live_session :public_afterdark, root_layout: {RoomSanctumWeb.Layouts, :root_public_afterdark} do
      live "/p/s/a/:id", ScribusLive.Public, :show # monochrome
    end
    live_session :public_her, root_layout: {RoomSanctumWeb.Layouts, :root_public_her} do
      live "/p/s/h/:id", ScribusLive.Public, :show # monochrome
    end
  end

  scope "/", RoomSanctumWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/cfg/offerings", SourceLive.Index, :index
    live "/cfg/offerings/new", SourceLive.Index, :new
    live "/cfg/offerings/:id/edit", SourceLive.Index, :edit
    live "/cfg/offerings/:id", SourceLive.Show, :show
    live "/cfg/offerings/:id/show/edit", SourceLive.Show, :edit

    live "/cfg/queries", QueryLive.Index, :index
    live "/cfg/queries/new", QueryLive.Index, :new
    live "/cfg/queries/:id/edit", QueryLive.Index, :edit
    live "/cfg/queries/:id", QueryLive.Show, :show
    live "/cfg/queries/:id/show/edit", QueryLive.Show, :edit

    live "/cfg/visions", VisionLive.Index, :index
    live "/cfg/visions/new", VisionLive.Index, :new
    live "/cfg/visions/:id/edit", VisionLive.Index, :edit
    live "/cfg/visions/:id", VisionLive.Show, :show
    live "/cfg/visions/:id/show/edit", VisionLive.Show, :edit
    # live "/p/v/:id/:name", VisionLive.Public, :show

    live "/cfg/focis", FociLive.Index, :index
    live "/cfg/focis/new", FociLive.Index, :new
    live "/cfg/focis/:id/edit", FociLive.Index, :edit
    live "/cfg/focis/:id", FociLive.Show, :show
    live "/cfg/focis/:id/show/edit", FociLive.Show, :edit

    live "/cfg/ankyra", AnkyraLive.Index, :index
    live "/cfg/ankyra/new", AnkyraLive.Index, :new
    live "/cfg/ankyra/:id/edit", AnkyraLive.Index, :edit
    live "/cfg/ankyra/:id", AnkyraLive.Show, :show
    live "/cfg/ankyra/:id/show/edit", AnkyraLive.Show, :edit

    live "/cfg/pythiæ", PythiaeLive.Index, :index
    live "/cfg/pythiæ/new", PythiaeLive.Index, :new
    live "/cfg/pythiæ/:id/edit", PythiaeLive.Index, :edit
    live "/cfg/pythiæ/:id", PythiaeLive.Show, :show
    live "/cfg/pythiæ/:id/show/edit", PythiaeLive.Show, :edit

    live "/cfg/scribus", ScribusLive.Index, :index
    live "/cfg/scribus/new", ScribusLive.Index, :new
    live "/cfg/scribus/:id/edit", ScribusLive.Index, :edit

    live "/cfg/scribus/:id", ScribusLive.Show, :show
    live "/cfg/scribus/:id/show/edit", ScribusLive.Show, :edit

    if Mix.env() == :dev do
      live "/storage/gtfs/agencies", AgencyLive.Index, :index
      live "/storage/gtfs/agencies/new", AgencyLive.Index, :new
      live "/storage/gtfs/agencies/:id/edit", AgencyLive.Index, :edit
      live "/storage/gtfs/agencies/:id", AgencyLive.Show, :show
      live "/storage/gtfs/agencies/:id/show/edit", AgencyLive.Show, :edit

      live "/storage/gtfs/calendars", CalendarLive.Index, :index
      live "/storage/gtfs/calendars/new", CalendarLive.Index, :new
      live "/storage/gtfs/calendars/:id/edit", CalendarLive.Index, :edit
      live "/storage/gtfs/calendars/:id", CalendarLive.Show, :show
      live "/storage/gtfs/calendars/:id/show/edit", CalendarLive.Show, :edit

      live "/storage/gtfs/directions", DirectionLive.Index, :index
      live "/storage/gtfs/directions/new", DirectionLive.Index, :new
      live "/storage/gtfs/directions/:id/edit", DirectionLive.Index, :edit
      live "/storage/gtfs/directions/:id", DirectionLive.Show, :show
      live "/storage/gtfs/directions/:id/show/edit", DirectionLive.Show, :edit

      live "/storage/gtfs/routes", RouteLive.Index, :index
      live "/storage/gtfs/routes/new", RouteLive.Index, :new
      live "/storage/gtfs/routes/:id/edit", RouteLive.Index, :edit
      live "/storage/gtfs/routes/:id", RouteLive.Show, :show
      live "/storage/gtfs/routes/:id/show/edit", RouteLive.Show, :edit

      live "/storage/gtfs/stop_times", StopTimeLive.Index, :index
      live "/storage/gtfs/stop_times/new", StopTimeLive.Index, :new
      live "/storage/gtfs/stop_times/:id/edit", StopTimeLive.Index, :edit
      live "/storage/gtfs/stop_times/:id", StopTimeLive.Show, :show
      live "/storage/gtfs/stop_times/:id/show/edit", StopTimeLive.Show, :edit

      live "/storage/gtfs/stops", StopLive.Index, :index
      live "/storage/gtfs/stops/new", StopLive.Index, :new
      live "/storage/gtfs/stops/:id/edit", StopLive.Index, :edit
      live "/storage/gtfs/stops/:id", StopLive.Show, :show
      live "/storage/gtfs/stops/:id/show/edit", StopLive.Show, :edit

      live "/storage/gtfs/trips", TripLive.Index, :index
      live "/storage/gtfs/trips/new", TripLive.Index, :new
      live "/storage/gtfs/trips/:id/edit", TripLive.Index, :edit
      live "/storage/gtfs/trips/:id", TripLive.Show, :show
      live "/storage/gtfs/trips/:id/show/edit", TripLive.Show, :edit

      live "/storage/gbfs/v1/system/information", SysInfoLive.Index, :index
      live "/storage/gbfs/v1/system/information/new", SysInfoLive.Index, :new
      live "/storage/gbfs/v1/system/information/:id/edit", SysInfoLive.Index, :edit
      live "/storage/gbfs/v1/system/information/:id", SysInfoLive.Show, :show
      live "/storage/gbfs/v1/system/information/:id/show/edit", SysInfoLive.Show, :edit

      live "/storage/gbfs/v1/station/information", StationInfoLive.Index, :index
      live "/storage/gbfs/v1/station/information/new", StationInfoLive.Index, :new
      live "/storage/gbfs/v1/station/information/:id/edit", StationInfoLive.Index, :edit
      live "/storage/gbfs/v1/station/information/:id", StationInfoLive.Show, :show
      live "/storage/gbfs/v1/station/information/:id/show/edit", StationInfoLive.Show, :edit

      live "/storage/gbfs/v1/station/status", StationStatusLive.Index, :index
      live "/storage/gbfs/v1/station/status/new", StationStatusLive.Index, :new
      live "/storage/gbfs/v1/station/status/:id/edit", StationStatusLive.Index, :edit
      live "/storage/gbfs/v1/station/status/:id", StationStatusLive.Show, :show
      live "/storage/gbfs/v1/station/status/:id/show/edit", StationStatusLive.Show, :edit

      live "/storage/gbfs/v1/alerts", AlertLive.Index, :index
      live "/storage/gbfs/v1/alerts/new", AlertLive.Index, :new
      live "/storage/gbfs/v1/alerts/:id/edit", AlertLive.Index, :edit
      live "/storage/gbfs/v1/alerts/:id", AlertLive.Show, :show
      live "/storage/gbfs/v1/alerts/:id/show/edit", AlertLive.Show, :edit

      live "/storage/gbfs_ebikes_stations", EbikesAtStationsLive.Index, :index
      live "/storage/gbfs_ebikes_stations/new", EbikesAtStationsLive.Index, :new
      live "/storage/gbfs_ebikes_stations/:id/edit", EbikesAtStationsLive.Index, :edit
      live "/storage/gbfs_ebikes_stations/:id", EbikesAtStationsLive.Show, :show
      live "/storage/gbfs_ebikes_stations/:id/show/edit", EbikesAtStationsLive.Show, :edit

      live "/storage/gbfs_free_bike_status", FreeBikeStatusLive.Index, :index
      live "/storage/gbfs_free_bike_status/new", FreeBikeStatusLive.Index, :new
      live "/storage/gbfs_free_bike_status/:id/edit", FreeBikeStatusLive.Index, :edit
      live "/storage/gbfs_free_bike_status/:id", FreeBikeStatusLive.Show, :show
      live "/storage/gbfs_free_bike_status/:id/show/edit", FreeBikeStatusLive.Show, :edit

      live "/storage/gbfs_vehicle_types", VehicleTypesLive.Index, :index
      live "/storage/gbfs_vehicle_types/new", VehicleTypesLive.Index, :new
      live "/storage/gbfs_vehicle_types/:id/edit", VehicleTypesLive.Index, :edit
      live "/storage/gbfs_vehicle_types/:id", VehicleTypesLive.Show, :show
      live "/storage/gbfs_vehicle_types/:id/show/edit", VehicleTypesLive.Show, :edit

      live "/storage/gbfs_system_pricing_plans", SystemPricingPlansLive.Index, :index
      live "/storage/gbfs_system_pricing_plans/new", SystemPricingPlansLive.Index, :new
      live "/storage/gbfs_system_pricing_plans/:id/edit", SystemPricingPlansLive.Index, :edit

      live "/storage/gbfs_system_pricing_plans/:id", SystemPricingPlansLive.Show, :show
      live "/storage/gbfs_system_pricing_plans/:id/show/edit", SystemPricingPlansLive.Show, :edit

      live "/airnow/reporting_area", ReportingAreaLive.Index, :index
      live "/airnow/reporting_area/new", ReportingAreaLive.Index, :new
      live "/airnow/reporting_area/:id/edit", ReportingAreaLive.Index, :edit
      live "/airnow/reporting_area/:id", ReportingAreaLive.Show, :show
      live "/airnow/reporting_area/:id/show/edit", ReportingAreaLive.Show, :edit

      live "/airnow/hourly_data", HourlyDataLive.Index, :index
      live "/airnow/hourly_data/new", HourlyDataLive.Index, :new
      live "/airnow/hourly_data/:id/edit", HourlyDataLive.Index, :edit
      live "/airnow/hourly_data/:id", HourlyDataLive.Show, :show
      live "/airnow/hourly_data/:id/show/edit", HourlyDataLive.Show, :edit

      live "/airnow/monitoring_sites", MonitoringSiteLive.Index, :index
      live "/airnow/monitoring_sites/new", MonitoringSiteLive.Index, :new
      live "/airnow/monitoring_sites/:id/edit", MonitoringSiteLive.Index, :edit
      live "/airnow/monitoring_sites/:id", MonitoringSiteLive.Show, :show
      live "/airnow/monitoring_sites/:id/show/edit", MonitoringSiteLive.Show, :edit

      live "/airnow/hourly_observations", HourlyObsDataLive.Index, :index
      live "/airnow/hourly_observations/new", HourlyObsDataLive.Index, :new
      live "/airnow/hourly_observations/:id/edit", HourlyObsDataLive.Index, :edit
      live "/airnow/hourly_observations/:id", HourlyObsDataLive.Show, :show
      live "/airnow/hourly_observations/:id/show/edit", HourlyObsDataLive.Show, :edit

      live "/calendar_entries", ICalendarLive.Index, :index
      live "/calendar_entries/new", ICalendarLive.Index, :new
      live "/calendar_entries/:id/edit", ICalendarLive.Index, :edit
      live "/calendar_entries/:id", ICalendarLive.Show, :show
      live "/calendar_entries/:id/show/edit", ICalendarLive.Show, :edit

      live "/cfg/webhooks", AgyrLive.Index, :index
      live "/cfg/webhooks/new", AgyrLive.Index, :new
      live "/cfg/webhooks/:id/edit", AgyrLive.Index, :edit

      live "/cfg/webhooks/:id", AgyrLive.Show, :show
      live "/cfg/webhooks/:id/show/edit", AgyrLive.Show, :edit

      live "/cfg/mailboxes", TaxidLive.Index, :index
      live "/cfg/mailboxes/new", TaxidLive.Index, :new
      live "/cfg/mailboxes/:id/edit", TaxidLive.Index, :edit

      live "/cfg/mailboxes/:id", TaxidLive.Show, :show
      live "/cfg/mailboxes/:id/show/edit", TaxidLive.Show, :edit

      live "/storage/mail", TaxidaeLive.Index, :index
      live "/storage/mail/new", TaxidaeLive.Index, :new
      live "/storage/mail/:id/edit", TaxidaeLive.Index, :edit
      live "/storage/mail/:id", TaxidaeLive.Show, :show
      live "/storage/mail/:id/show/edit", TaxidaeLive.Show, :edit
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", RoomSanctumWeb do
    pipe_through :api
    resources "/data/:path", DataController, only: [:create, :index]
  end

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

      live_dashboard "/dashboard",
        metrics: RoomSanctumWeb.Telemetry,
        additional_pages: [
          oban: Oban.LiveDashboard
        ]
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

  ## Authentication routes

  scope "/", RoomSanctumWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{RoomSanctumWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
      live "/p/p/:name", PythiaeLive.Public, :show
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", RoomSanctumWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{RoomSanctumWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", RoomSanctumWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{RoomSanctumWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
