defmodule RoomSanctumNative do
  @moduledoc """
  The entrypoint for defining your native interfaces, such
  as components, render components, layouts, and live views.

  This can be used in your application as:

      use RoomSanctumNative, :live_view

  The definitions below will be executed for every
  component, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  import RoomSanctumWeb, only: [verified_routes: 0]

  @doc ~S'''
  Set up an existing LiveView module for use with LiveView Native

      defmodule MyAppWeb.HomeLive do
        use MyAppWeb, :live_view
        use MyAppNative, :live_view
      end

  An `on_mount` callback will be injected that will negotiate
  the inbound connection content type. If it is a LiveView Native
  type the `render/1` will be delegated to the format-specific
  render component.
  '''
  def live_view() do
    quote do
      use LiveViewNative.LiveView,
        formats: [
          :jetpack
        ],
        layouts: [
          jetpack: {RoomSanctumWeb.Layouts.Jetpack, :app}
        ]

      unquote(verified_routes())
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Native format-specific render component

      defmodule MyAppWeb.HomeLive.SwiftUI do
        use MyAppNative, [:render_component, format: :swiftui]

        def render(assigns, _interface) do
          ~LVN"""
          <Text>Hello, world!</Text>
          """
        end
      end
  '''
  def render_component(opts) do
    opts =
      opts
      |> Keyword.take([:format])
      |> Keyword.put(:as, :render)

    quote do
      use LiveViewNative.Component, unquote(opts)

      unquote(helpers(opts[:format]))
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Native Component

      defmodule MyAppWeb.Components.CustomSwiftUI do
        use MyAppNative, [:component, format: :swiftui]

        attr :msg, :string, :required
        def home_textk(assigns) do
          ~LVN"""
          <Text>@msg</Text>
          """
        end
      end

  LiveView Native Components are identical to Phoenix Components. Please
  refer to the `Phoenix.Component` documentation for more information.
  '''
  def component(opts) do
    opts = Keyword.take(opts, [:format, :root, :as])

    quote do
      use LiveViewNative.Component, unquote(opts)

      unquote(helpers(opts[:format]))
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Natve Layout Component

      defmodule MyAppWeb.Layouts.SwiftUI do
        use MyAppNative, [:layout, format: :swiftui]

        embed_templates "layouts_swiftui/*"
      end
  '''
  def layout(opts) do
    opts = Keyword.take(opts, [:format, :root])

    quote do
      use LiveViewNative.Component, unquote(opts)

      import LiveViewNative.Component, only: [csrf_token: 1]

      unquote(helpers(opts[:format]))
    end
  end

  defp helpers(_format) do
    gettext_quoted = quote do
      import RoomSanctumWeb.Gettext
    end
    

    [
        gettext_quoted,
        verified_routes()
      ]
      
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__([which | opts]) when is_atom(which) do
    apply(__MODULE__, which, [opts])
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
