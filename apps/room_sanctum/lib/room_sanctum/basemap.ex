defmodule RoomSanctum.Basemap do
  @moduledoc """
  Which tile server the Leaflet basemaps draw from.

  Nothing is configured by default: the frontend falls back to CARTO's keyless
  greyscale basemaps, which is what every map used before this existed. An
  installation that would rather not send its users' viewports to a third party
  -- or that runs its own server -- points these at it instead.

  Set in `config/runtime.exs` from the environment, so a release is repointed
  without a rebuild:

      TILE_URL             template for the base tiles, e.g.
                           "https://tiles.example/styles/light/{z}/{x}/{y}.png"
      TILE_URL_DARK        same, drawn instead when the theme is dark
                           (defaults to TILE_URL -- one style for both themes)
      TILE_LABELS_URL      optional label-only overlay, drawn above the theme
                           wash so place names keep their contrast
      TILE_LABELS_URL_DARK dark counterpart of TILE_LABELS_URL
      TILE_ATTRIBUTION     attribution HTML for the corner of the map
      TILE_SUBDOMAINS      e.g. "abcd", only if the URL contains `{s}`
      TILE_MAX_ZOOM        deepest zoom the server has tiles for

  Only `TILE_URL` is required to switch servers; the rest refine it. The values
  reach the browser as `<meta name="basemap-*">` tags, read by
  `assets/js/leaflet/basemap.js`.

  Our own server publishes exactly the pair this expects -- a Positron-like
  grayscale and a Dark Matter-like dark, the same two CARTO styles the default
  draws from:

      TILE_URL=https://tiles.neiam.org/grayscale/{z}/{x}/{y}.png
      TILE_URL_DARK=https://tiles.neiam.org/dark/{z}/{x}/{y}.png
      TILE_MAX_ZOOM=20

  It is not the default, because it is not a drop-in replacement for CARTO in
  two ways an installation has to decide about rather than inherit: its import
  is north america only, so anywhere else renders as empty tiles rather than an
  error, and it publishes no label-only layer, so the theme wash goes over the
  place names instead of under them. Neither is visible until someone pans off
  the continent or reads a tinted label.

  It serves no `@2x` tiles either, which needs nothing here -- retina is opt-in
  via `{r}` in `TILE_URL`, see the note in `assets/js/leaflet/basemap.js`.
  """

  @keys [
    url: "url",
    dark_url: "dark-url",
    labels_url: "labels-url",
    dark_labels_url: "dark-labels-url",
    attribution: "attribution",
    subdomains: "subdomains",
    max_zoom: "max-zoom"
  ]

  @doc """
  The configured basemap as `{meta_name, value}` pairs, blank entries dropped.

  Empty when nothing is configured, which is the signal to the frontend to use
  its built-in default rather than an explicit instruction to draw nothing.
  """
  def meta_tags do
    config = Application.get_env(:room_sanctum, :basemap, [])

    for {key, name} <- @keys,
        value = present(config[key]),
        do: {name, value}
  end

  defp present(nil), do: nil
  defp present(value) when is_integer(value), do: Integer.to_string(value)

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
