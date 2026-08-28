# Custom map tiles

Every Leaflet map in room_sanctum draws its basemap from one tile server,
chosen by configuration. Unset, it is CARTO's keyless greyscale basemaps —
which is what every map used before this was configurable. Set, it is whatever
server you point it at.

The moving parts:

| Where | What |
| --- | --- |
| `config/runtime.exs` | reads `TILE_*` from the environment |
| `apps/room_sanctum/lib/room_sanctum/basemap.ex` | drops the blank keys, names the meta tags |
| `<.basemap_meta />` in `CoreComponents`, in both root layouts | writes `<meta name="basemap-*">` into `<head>` |
| `apps/room_sanctum/assets/js/leaflet/basemap.js` | resolves the source once per page, falls back to CARTO |

Meta tags rather than an attribute per map because maps are created from half a
dozen places — including the `<leaflet-map>` web component, inside a shadow
root — and every one of them draws from the same server.

## Configuration

Read at runtime, so a release is repointed by restarting it rather than
rebuilding it.

| Variable | Meaning |
| --- | --- |
| `TILE_URL` | base tiles. The only one required to switch servers |
| `TILE_URL_DARK` | drawn instead under a dark theme (defaults to `TILE_URL`) |
| `TILE_LABELS_URL` | label-only overlay, drawn *above* the theme wash |
| `TILE_LABELS_URL_DARK` | dark counterpart (defaults to `TILE_LABELS_URL`) |
| `TILE_ATTRIBUTION` | attribution HTML for the corner of the map |
| `TILE_SUBDOMAINS` | e.g. `abcd`, only if the URL contains `{s}` |
| `TILE_MAX_ZOOM` | deepest zoom the server has tiles for |

Set none of them and nothing is emitted into `<head>` at all, which the
frontend reads as "use your default" rather than as "draw nothing".

Light and dark are chosen per theme by `isDarkTheme()`, which reads daisyUI's
`--b1` off the map container — so the maps follow the theme picker, not the OS.
A caller can pin one with `variant: 'light' | 'dark'`; the web component takes
that from its `basemap` attribute.

`TILE_MAX_ZOOM` wins over the `maxZoom` a caller passes `addBasemap`. Callers
pass the zoom the view wants, which a server without tiles that deep can only
answer with 404s.

Retina is opt-in: put `{r}` in `TILE_URL` only for a server that really serves
`@2x` tiles. Leaflet's `detectRetina` has two modes and only one is safe to
assume — with `{r}` it asks for the @2x tile, without it it requests the *next
zoom down at half size*, which is four times the tiles and nothing at all at
the server's deepest zoom.

## tiles.neiam.org

Our own renderd server, and what the deployment points at — see the `TILE_*`
block in `app.yml`. Its landing page is a live layer switcher that prints the
template of whichever layer is showing, so it is its own reference.

```
TILE_URL=https://tiles.neiam.org/grayscale/{z}/{x}/{y}.png
TILE_URL_DARK=https://tiles.neiam.org/dark/{z}/{x}/{y}.png
TILE_LABELS_URL=https://tiles.neiam.org/grayscale_only_labels/{z}/{x}/{y}.png
TILE_LABELS_URL_DARK=https://tiles.neiam.org/dark_only_labels/{z}/{x}/{y}.png
TILE_MAX_ZOOM=20
```

| Layer | Style |
| --- | --- |
| `/grayscale/{z}/{x}/{y}.png` | Positron-like |
| `/dark/{z}/{x}/{y}.png` | Dark Matter-like |
| `/tile/{z}/{x}/{y}.png` | standard OSM colour |
| `/night/{z}/{x}/{y}.png` | warm dark |
| `/blueprint/{z}/{x}/{y}.png` | blueprint |
| `/grayscale_only_labels/…`, `/dark_only_labels/…` | transparent label overlays |

256px tiles, no `@2x`, no `{s}`, north-america-only import. The base styles are
opaque palette PNGs; the two `_only_labels` layers carry a `tRNS` chunk and
render place names over nothing, which is what makes them usable as an overlay.
Only the five base styles are listed on the landing page — the label layers are
served but undocumented there, so this file is their reference.

The built-in default in `basemap.js` is still CARTO; the deployment overrides
it. Two reasons to leave the fallback where it is:

- **North america only.** Anywhere else renders as empty tiles, not an error.
  The landing page's four cities are all inside the import.
- **Cold tiles do not render reliably.** Measured 2026-08-28: an uncached tile
  hangs ~10s and then returns 404, 502 or 503 depending on how the request
  fails, and the same tile can keep failing across retries for minutes before
  it starts serving — NYC at z10–z12 did this on every layer while z4 and
  z19–z20 at the same point served immediately. Leaflet does not re-request a
  404, so a failed tile is a permanent hole in that page's map rather than a
  slow one. This is the thing to fix on the server side; it is more visible to
  a user than anything else on this page.

## The label-only layer

CARTO publishes each basemap three ways: `light_all`, `light_nolabels` and
`light_only_labels`. The default draws `_nolabels` under the theme tint and
`_only_labels` above it, in a Leaflet pane at z-index 350 — above the wash
(250), below the overlay (400) and marker (600) panes.

That split is not decoration. The tint is a `mix-blend-mode: color` wash over
the whole basemap, and type tinted along with everything behind it loses most
of its contrast against the roads. Drawing the labels above the wash is what
keeps place names readable on a tinted map. The cost is a second tile request
per tile, which `labels: false` opts out of.

tiles.neiam.org now serves `grayscale_only_labels` and `dark_only_labels`, so
the deployment gets the same split. The frontend turns the label pane on as
soon as **both** a light and a dark label URL are configured — both are
required, because the theme can flip at any moment and a pane that existed
under one theme and not the other would have labels appearing and disappearing
with it.

### Still open: is the base style label-free?

CARTO's `_nolabels` exists so the base and the overlay do not both draw type.
Our server has no `_nolabels` variant that we could find, which leaves the
question of whether `/grayscale` and `/dark` bake their labels in. If they do,
every place name is drawn twice — once under the wash, once above it. Because
both come from the same style at the same placement they land on top of each
other, so it reads as heavier type rather than as doubled type, but it is not
what the design intends and it costs a second render of every label.

Worth checking against a rendered city tile once the server is serving cold
tiles reliably (see above — this could not be confirmed while writing this, as
`/grayscale` was returning 503 for every zoom that was not already cached).
Two ways out if it turns out labels are baked in:

- publish `grayscale_nolabels` / `dark_nolabels` and point `TILE_URL` at those,
  which is the CARTO shape and needs no code change; or
- drop `TILE_LABELS_URL*` and accept the tint over the labels, which is what
  the single-layer path already does.

## Remaining gaps

- **Extend the import past north america**, or accept that the instance is
  regional.
- **`@2x` tiles**, then add `{r}` to `TILE_URL` — one line of config, and the
  retina path in `basemap.js` already handles it.

Once cold-tile rendering is dependable, flipping the built-in default in
`basemap.js` from CARTO to our server is a small change: `CARTO` in that file
is just the fallback `tileSource()` returns when no `basemap-url` meta tag is
present.
