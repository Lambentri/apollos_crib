import L from 'leaflet'

// CARTO's greyscale basemaps, the default when no server is configured.
// Keyless, and monochrome by design rather than desaturated after the fact --
// a CSS grayscale() filter over standard OSM tiles flattens the colour-coded
// road hierarchy into near-identical greys, whereas these are drawn for it, so
// labels and roads keep their separation once a tint is laid over them.
// CARTO publishes each basemap split into a label-free layer and a label-only
// layer as well as the combined `_all`. Drawing the labels as a separate layer
// above the wash is what keeps type readable: tinted along with everything
// else, place names lose most of their contrast against the roads behind them.
// The cost is a second tile request per tile, which `labels: false` opts out
// of by falling back to the combined layer.
const CARTO_URL = 'https://{s}.basemaps.cartocdn.com/'
const cartoUrl = (style) => CARTO_URL + style + '/{z}/{x}/{y}{r}.png'

const CARTO = {
    light: {
        all: cartoUrl('light_all'),
        base: cartoUrl('light_nolabels'),
        labels: cartoUrl('light_only_labels')
    },
    dark: {
        all: cartoUrl('dark_all'),
        base: cartoUrl('dark_nolabels'),
        labels: cartoUrl('dark_only_labels')
    },
    subdomains: 'abcd',
    maxZoom: null,
    retina: true,
    attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors ' +
        '&copy; <a href="https://carto.com/attributions">CARTO</a>'
}

// The server the page was served with, written into <head> as
// <meta name="basemap-*"> by RoomSanctum.Basemap. Meta tags rather than an
// attribute on each map: the maps are created from half a dozen places,
// including a web component inside a shadow root, and all of them draw from
// the same server.
function meta(name) {
    const el = document.querySelector('meta[name="basemap-' + name + '"]')
    const value = el && el.content.trim()
    return value || null
}

// Resolved once per page. Only `basemap-url` is required to switch servers:
// a server with a single style is drawn under both themes, and one with no
// separate label layer simply takes the wash over its labels.
let source = null

function tileSource() {
    if (source) return source

    const url = meta('url')
    if (!url) {
        source = CARTO
        return source
    }

    const dark = meta('dark-url') || url
    const labels = meta('labels-url')
    const darkLabels = meta('dark-labels-url') || labels
    const maxZoom = parseInt(meta('max-zoom'), 10)

    source = {
        light: { all: url, base: url, labels: labels },
        dark: { all: dark, base: dark, labels: darkLabels },
        subdomains: meta('subdomains') || '',
        maxZoom: Number.isFinite(maxZoom) ? maxZoom : null,
        // Leaflet's detectRetina has two modes, and only one of them is safe
        // to assume. With `{r}` in the template it asks the server for the @2x
        // tile; without it, it requests the *next zoom down* at half size --
        // four times the tiles, and nothing at all at the server's deepest
        // zoom. A plain renderd-style server has neither @2x nor the headroom,
        // so retina rendering is opt-in via `{r}` in TILE_URL.
        retina: url.includes('{r}'),
        attribution: meta('attribution') ||
            '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }
    return source
}

// Which daisyUI variable the tint is taken from, and how far the wash is
// pushed.
//
// 'color' takes hue and saturation from the wash and keeps the tiles'
// luminance, so the basemap is recoloured rather than veiled: contrast is
// identical to the untinted tiles, and an achromatic theme (lofi, black)
// correctly leaves the map monochrome. Blends that redistribute luminance --
// screen, lighten -- wash a dark basemap out to pale grey instead.
//
// 0.5 keeps the theme legible on the basemap while leaving the amber "already
// queried" marker clearly separate from a warm basemap under the orange theme,
// which the two start to merge into as the wash approaches 1.0.
const DEFAULT_TINT_VAR = '--p'
const DEFAULT_STRENGTH = 0.5
const DEFAULT_BLEND = 'color'

const PANE = 'themeTint'
// Above the wash so labels keep CARTO's own contrast, and below the overlay
// (400) and marker (600) panes so query and vehicle markers still draw on top.
const LABEL_PANE = 'themeLabels'
const LABEL_Z = '350'
// Viewports of slack on each side of the wash. Leaflet animates a zoom by
// scaling the whole map pane, so zooming out momentarily renders this pane at
// half size; at 1 viewport of padding it is 3x the viewport and still covers
// after that 0.5x. The extra area is close to free -- a solid-colour layer is
// only rasterised and blended where it intersects the screen.
const PANE_PADDING = 1

// Every live tint on the page, so a theme switch can repaint all of them
// without each map having to watch the document itself.
const registry = new Set()
let watching = false

function cssVar(name, el) {
    return getComputedStyle(el || document.documentElement).getPropertyValue(name).trim()
}

// daisyUI stores its palette as bare HSL components ("242 29% 59%") so callers
// can apply their own alpha. Anything else -- a literal colour handed in via
// the `tint` attribute -- is passed through untouched.
function asColor(value) {
    if (!value) return null
    return /^[\d.]+\s+[\d.]+%\s+[\d.]+%$/.test(value) ? `hsl(${value})` : value
}

/**
 * A colour that may be named as a theme variable.
 *
 * `--a` reads the current theme's accent, `#38bdf8` is passed through, and
 * anything falsy comes back null so the caller can pick its own default. The
 * rule the basemap's `tint` option already used, pulled out so a line can be
 * coloured by the same names -- otherwise every new caller reinvents which of
 * these two forms it accepts, and they drift.
 *
 * `el` is the element to resolve against, which matters inside a shadow root
 * whose host may sit under a different data-theme than <html>.
 */
export function themeColor(value, el) {
    if (!value) return null
    return asColor(value.startsWith('--') ? cssVar(value, el) : value)
}

// Themes here range from near-black to a deep navy, and the basemap has to
// match the surrounding chrome or the map reads as a hole punched in the page.
// base-100's lightness is the same signal daisyUI itself uses.
export function isDarkTheme(el) {
    const match = cssVar('--b1', el).match(/^[\d.]+\s+[\d.]+%\s+([\d.]+)%$/)
    return match ? parseFloat(match[1]) < 50 : true
}

function watchTheme() {
    if (watching) return
    watching = true

    const repaint = () => registry.forEach((refresh) => refresh())

    new MutationObserver(repaint).observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['data-theme']
    })

    // The picker writes the attribute and fires this; the observer above
    // catches the write, but system-theme changes only surface as the event.
    window.addEventListener('phx:set-theme', () => setTimeout(repaint, 0))
}

/**
 * Run `fn` whenever the theme changes, and return an unsubscribe.
 *
 * The tint keeps a registry of repaint callbacks and watches the document for
 * both the attribute write and the picker's own event; anything else that has
 * to restyle on a theme flip -- markers shaded by a value, whose ramp is
 * anchored to the surface they sit on -- wants exactly the same signal rather
 * than a second observer beside it.
 */
export function onThemeChange(fn) {
    registry.add(fn)
    watchTheme()
    return () => registry.delete(fn)
}

/**
 * Add a basemap to `map` and wash it in the current theme colour.
 *
 * Returns a handle with `refresh()` (re-read the theme now) and `remove()`.
 *
 * Options:
 *   variant   'auto' (default) | 'light' | 'dark'
 *   tint      CSS colour, a daisyUI var name like '--s', or 'none'
 *   strength  0..1, how much of the tint is applied (default 0.5)
 *   blend     mix-blend-mode for the wash (default 'color')
 *   labels    false to use the combined basemap and let the wash cover the
 *             labels too -- one tile request per tile instead of two, at the
 *             cost of much less readable type (default true; ignored when the
 *             configured server publishes no label-only layer)
 *   styleFrom element to resolve custom properties against; defaults to the
 *             map container, which matters inside a shadow root where the
 *             host may sit under a different data-theme than <html>
 *   maxZoom   passed to the tile layer (default 20), unless the configured
 *             server declares a lower limit of its own
 */
export function addBasemap(map, opts = {}) {
    const container = map.getContainer()
    const styleFrom = opts.styleFrom || container
    const variant = opts.variant && opts.variant !== 'auto' ? opts.variant : null
    const tintOpt = opts.tint || DEFAULT_TINT_VAR
    const strength = opts.strength == null ? DEFAULT_STRENGTH : Number(opts.strength)

    const src = tileSource()
    // A server that publishes no label-only layer has nothing to draw above
    // the wash, so `labels` can only ever turn the second request off.
    const withLabels = opts.labels !== false && !!(src.light.labels && src.dark.labels)
    const styleFor = () => src[variant] || (isDarkTheme(styleFrom) ? src.dark : src.light)
    const baseUrl = () => (withLabels ? styleFor().base : styleFor().all)

    const tileOpts = {
        subdomains: src.subdomains,
        // A configured server's own limit wins over the caller's: callers pass
        // the zoom the view wants, which a server without tiles that deep can
        // only answer with 404s.
        maxZoom: src.maxZoom || opts.maxZoom || 20,
        detectRetina: src.retina
    }

    const tiles = L.tileLayer(baseUrl(), Object.assign({ attribution: src.attribution }, tileOpts))
        .addTo(map)

    // The wash has to be a Leaflet pane, not a child of the container.
    // `.leaflet-map-pane` is itself a pane at z-index 400 and so forms a
    // stacking context -- the tile pane's 200 and the marker pane's 600 are
    // numbers *inside* it. A sibling of the map pane therefore cannot be
    // slipped between them at any z-index; it paints under the whole map.
    // As a pane the tint is a true sibling of the tile pane, and the map
    // pane's stacking context also confines the blend for free.
    const tint = map.createPane(PANE)
    tint.classList.add('leaflet-theme-tint')
    tint.style.zIndex = '250'
    tint.style.pointerEvents = 'none'
    tint.style.mixBlendMode = opts.blend || DEFAULT_BLEND

    // Panes translate with the map, so the wash is sized to the viewport and
    // re-anchored as the map moves. The padding is insurance for zoom
    // animations, where the pane is being scaled by CSS and the layer-point
    // maths below is momentarily stale.
    const reposition = () => {
        const size = map.getSize()
        const padX = size.x * PANE_PADDING
        const padY = size.y * PANE_PADDING
        tint.style.width = size.x + padX * 2 + 'px'
        tint.style.height = size.y + padY * 2 + 'px'
        L.DomUtil.setPosition(tint, map.containerPointToLayerPoint([-padX, -padY]))
    }

    map.on('move zoom viewreset resize zoomend moveend', reposition)
    reposition()

    let labelTiles = null
    if (withLabels) {
        const labelPane = map.createPane(LABEL_PANE)
        labelPane.style.zIndex = LABEL_Z
        labelPane.style.pointerEvents = 'none'
        labelTiles = L.tileLayer(styleFor().labels,
            Object.assign({ pane: LABEL_PANE }, tileOpts)).addTo(map)
    }

    const refresh = () => {
        // setUrl no-ops when the template is unchanged, so this only refetches
        // tiles when the theme actually crossed the light/dark line.
        tiles.setUrl(baseUrl())
        if (labelTiles) labelTiles.setUrl(styleFor().labels)

        const color = tintOpt === 'none' ? null : themeColor(tintOpt, styleFrom)

        tint.style.background = color || 'transparent'
        tint.style.opacity = color ? String(strength) : '0'
    }

    refresh()
    registry.add(refresh)
    watchTheme()

    return {
        tileLayer: tiles,
        labelLayer: labelTiles,
        element: tint,
        refresh,
        remove() {
            registry.delete(refresh)
            map.off('move zoom viewreset resize zoomend moveend', reposition)
            tint.remove()
            map.removeLayer(tiles)
            if (labelTiles) {
                map.removeLayer(labelTiles)
                const labelPane = map.getPane(LABEL_PANE)
                if (labelPane) labelPane.remove()
            }
            if (map._panes) {
                delete map._panes[PANE]
                delete map._panes[LABEL_PANE]
            }
        }
    }
}
