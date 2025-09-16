defmodule RoomSanctumWeb.ThemePicker do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @themes [
    %{name: "system", title: "System", description: "Follow system preference",
      colors: %{primary: "#6b7280", secondary: "#9ca3af", accent: "#fef3c7", neutral: "#374151", base: "#f9fafb"}},
    %{name: "afterdark", title: "After Dark", description: "Dark purple theme", 
      colors: %{primary: "#7B79B5", secondary: "#ACABD5", accent: "#fef3c7", neutral: "#38357F", base: "#201D65"}},
    %{name: "black", title: "Black", description: "True black theme",
      colors: %{primary: "#373737", secondary: "#a6adbb", accent: "#66cc8a", neutral: "#2a2e37", base: "#1d232a"}},
    %{name: "clays", title: "Clays", description: "Warm earth tones",
      colors: %{primary: "#d97706", secondary: "#f59e0b", accent: "#fef3c7", neutral: "#92400e", base: "#451a03"}},
    %{name: "forest", title: "Forest", description: "Green nature theme",
      colors: %{primary: "#4ade80", secondary: "#86efac", accent: "#fef3c7", neutral: "#166534", base: "#052e16"}},
    %{name: "her", title: "Her", description: "Orange/warm theme",
      colors: %{primary: "#b57979", secondary: "#d5abab", accent: "#fef3c7", neutral: "#7f3535", base: "#651d1d"}},
    %{name: "lofi", title: "Lo-Fi", description: "Neutral minimalist",
      colors: %{primary: "#0f0f23", secondary: "#a6adbb", accent: "#66cc8a", neutral: "#2a2e37", base: "#1d232a"}},
    %{name: "sky", title: "Sky", description: "Blue sky theme",
      colors: %{primary: "#38bdf8", secondary: "#7dd3fc", accent: "#fef3c7", neutral: "#0c4a6e", base: "#082f49"}},
    %{name: "stones", title: "Stones", description: "Gray/stone theme",
      colors: %{primary: "#6b7280", secondary: "#9ca3af", accent: "#fef3c7", neutral: "#57534e", base: "#292524"}}
  ]

  @doc """
  Renders a theme picker with preview cards for each theme.
  
  The current theme is determined client-side and doesn't need to be passed as an attribute.
  The component will automatically detect which theme is currently active.
  
  ## Examples
  
      <.theme_picker />
  """
  attr :class, :string, default: nil
  attr :id, :string, default: "theme-picker"

  def theme_picker(assigns) do
    themes = [
      %{name: "system", title: "System", description: "Follow system preference",
        colors: %{primary: "#6b7280", secondary: "#9ca3af", accent: "#fef3c7", neutral: "#374151", base: "#f9fafb"}},
      %{name: "afterdark", title: "After Dark", description: "Dark purple theme", 
        colors: %{primary: "#7B79B5", secondary: "#ACABD5", accent: "#fef3c7", neutral: "#38357F", base: "#201D65"}},
      %{name: "black", title: "Black", description: "True black theme",
        colors: %{primary: "#373737", secondary: "#a6adbb", accent: "#66cc8a", neutral: "#2a2e37", base: "#1d232a"}},
      %{name: "clays", title: "Clays", description: "Warm earth tones",
        colors: %{primary: "#d97706", secondary: "#f59e0b", accent: "#fef3c7", neutral: "#92400e", base: "#451a03"}},
      %{name: "forest", title: "Forest", description: "Green nature theme",
        colors: %{primary: "#4ade80", secondary: "#86efac", accent: "#fef3c7", neutral: "#166534", base: "#052e16"}},
      %{name: "her", title: "Her", description: "Orange/warm theme",
        colors: %{primary: "#b57979", secondary: "#d5abab", accent: "#fef3c7", neutral: "#7f3535", base: "#651d1d"}},
      %{name: "lofi", title: "Lo-Fi", description: "Neutral minimalist",
        colors: %{primary: "#0f0f23", secondary: "#a6adbb", accent: "#66cc8a", neutral: "#2a2e37", base: "#1d232a"}},
      %{name: "sky", title: "Sky", description: "Blue sky theme",
        colors: %{primary: "#38bdf8", secondary: "#7dd3fc", accent: "#fef3c7", neutral: "#0c4a6e", base: "#082f49"}},
      %{name: "stones", title: "Stones", description: "Gray/stone theme",
        colors: %{primary: "#6b7280", secondary: "#9ca3af", accent: "#fef3c7", neutral: "#57534e", base: "#292524"}}
    ]

    assigns = assign(assigns, :themes, themes)

    ~H"""
    <div class={["theme-picker", @class]} id={@id} phx-hook="ThemeDetector">
      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
        Choose Theme
      </h3>
      
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <.theme_card
          :for={theme <- @themes}
          theme={theme}
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders a single theme preview card.
  """
  attr :theme, :map, required: true

  def theme_card(assigns) do
    ~H"""
    <div class="theme-card relative rounded-lg border-2 cursor-pointer transition-all hover:scale-105 border-gray-200 dark:border-gray-700 hover:border-gray-300 overflow-hidden"
         data-theme-name={@theme.name}>
      
      <!-- Theme indicator -->
      <div class="absolute top-2 right-2 theme-indicator hidden z-10">
        <div class="w-3 h-3 bg-blue-500 rounded-full shadow-lg"></div>
      </div>
      
      <!-- Theme preview with name overlay -->
      <button
        type="button"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme={@theme.name}
        class="w-full h-24 flex items-center justify-center text-center transition-all hover:brightness-110"
        style={
          if @theme.name == "system" do
            "background: linear-gradient(135deg, #{@theme.colors.base} 0%, #{@theme.colors.primary} 100%); color: #{@theme.colors.neutral};"
          else
            "background-color: #{@theme.colors.base}; color: #{if String.starts_with?(@theme.colors.base, "#0") or String.starts_with?(@theme.colors.base, "#1") or String.starts_with?(@theme.colors.base, "#2"), do: @theme.colors.accent, else: @theme.colors.neutral};"
          end
        }
      >
        <%= if @theme.name == "system" do %>
          <div class="flex flex-col items-center">
            <svg class="w-6 h-6 mb-1 opacity-80" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3 5a2 2 0 012-2h10a2 2 0 012 2v8a2 2 0 01-2 2h-2.22l.123.489.804.804A1 1 0 0113 18H7a1 1 0 01-.707-1.707l.804-.804L7.22 15H5a2 2 0 01-2-2V5zm5.771 7H5V5h10v7H8.771z" clip-rule="evenodd" />
            </svg>
            <span class="text-sm font-medium">{@theme.title}</span>
          </div>
        <% else %>
          <span class="text-sm font-medium">{@theme.title}</span>
        <% end %>
      </button>
    </div>
    """
  end
end
