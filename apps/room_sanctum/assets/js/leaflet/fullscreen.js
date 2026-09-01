import L from 'leaflet'

// A fullscreen toggle for any Leaflet map on the page.
//
// The maps are built five different ways -- three hooks in app.js, the
// dashboard hook, and the <leaflet-map> web component -- so this takes a map
// and the element that should fill the screen, and knows nothing else about
// its caller.
//
// Two mechanisms, in order of preference:
//
//   The Fullscreen API, which gives a real fullscreen window with the browser
//   chrome gone. It can be refused -- iOS Safari has never implemented it for
//   elements, and an iframe without allowfullscreen is denied -- and the
//   refusal arrives as a rejected promise rather than a missing method, so it
//   cannot be feature-detected up front.
//
//   Failing that, a fixed-position "maximised" class covering the viewport.
//   Not as good (the browser chrome stays) but it works everywhere, and it is
//   the same button either way.
const STYLE_MARK = 'data-leaflet-fullscreen-style'

// The maximised fallback sits above the page but below nothing else in
// particular; 9999 clears the sticky navbar, which is the only thing on these
// pages that competes.
const CSS = `
.leaflet-fullscreen-maximised {
  position: fixed !important;
  inset: 0 !important;
  width: 100% !important;
  height: 100% !important;
  max-width: none !important;
  max-height: none !important;
  margin: 0 !important;
  border-radius: 0 !important;
  z-index: 9999 !important;
}
/* The UA sizes the fullscreen element itself, but these maps carry a height
   from a utility class (h-96) or an inline style, and browsers do not agree on
   whether the UA rule outranks those. Saying it here settles it: without this
   the map keeps its 400px and the rest of the screen is black. */
.leaflet-fullscreen-target:fullscreen {
  width: 100% !important;
  height: 100% !important;
}
:fullscreen .leaflet-container,
:fullscreen.leaflet-container {
  width: 100% !important;
  height: 100% !important;
}
.leaflet-fullscreen button {
  display: block;
  width: 30px;
  height: 30px;
  padding: 0;
  line-height: 0;
  color: #334155;
  background: #fff;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}
.leaflet-fullscreen button:hover {
  background: #f1f5f9;
}
.leaflet-fullscreen svg {
  display: inline-block;
  vertical-align: middle;
}
`

// Styles go into whichever root the map lives in -- the document for the hook
// maps, the shadow root for the web component, which document stylesheets
// cannot reach -- and, for a shadow root, into the document as well: the
// button is inside the shadow tree but the element that takes the maximised
// class is the host, which sits in the document and is styled by it.
function injectStyleInto(host) {
    if (!host || host.querySelector(`style[${STYLE_MARK}]`)) return
    const style = document.createElement('style')
    style.setAttribute(STYLE_MARK, '')
    style.textContent = CSS
    host.appendChild(style)
}

function injectStyle(root) {
    injectStyleInto(root === document ? document.head : root)
    if (root !== document) injectStyleInto(document.head)
}

const ENTER_ICON = `
  <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" fill="none"
       stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M3 9V3h6M21 9V3h-6M3 15v6h6M21 15v6h-6" />
  </svg>`

const EXIT_ICON = `
  <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" fill="none"
       stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M9 3v6H3M15 3v6h6M9 21v-6H3M15 21v-6h6" />
  </svg>`

// Safari still needs the prefixed names.
function fullscreenElement(doc) {
    return doc.fullscreenElement || doc.webkitFullscreenElement || null
}

function requestFullscreen(el) {
    const request = el.requestFullscreen || el.webkitRequestFullscreen
    if (!request) return Promise.reject(new Error('unsupported'))
    // Chrome's prefixed version returns undefined rather than a promise.
    return Promise.resolve(request.call(el, { navigationUI: 'hide' }))
}

function exitFullscreen(doc) {
    const exit = doc.exitFullscreen || doc.webkitExitFullscreen
    return exit ? Promise.resolve(exit.call(doc)) : Promise.resolve()
}

// The interactions a static map turns off. Fullscreen is the one place they
// are worth having back: a map filling the screen that cannot be panned is
// just a bigger picture.
const HANDLERS = ['dragging', 'touchZoom', 'scrollWheelZoom', 'doubleClickZoom', 'boxZoom', 'keyboard']

/**
 * Add a fullscreen toggle to `map`.
 *
 * Options:
 *   target      element to fill the screen; defaults to the map's container.
 *               Pass the outer element where the map sits in a wrapper -- the
 *               shadow host, or the hook's own element.
 *   position    Leaflet control position (default 'topleft', under the zoom
 *               control)
 *   interactive true to enable panning and zooming while fullscreen on a map
 *               whose interactions are otherwise off, restoring them on exit
 *   title       button tooltip (default 'Fullscreen')
 */
export function addFullscreenControl(map, opts = {}) {
    const container = map.getContainer()
    const target = opts.target || container
    const doc = container.ownerDocument
    const root = container.getRootNode ? container.getRootNode() : document

    injectStyle(root)
    target.classList.add('leaflet-fullscreen-target')

    let maximised = false
    let restoreHandlers = null
    let button = null

    const isOn = () => maximised || fullscreenElement(doc) === target

    const paint = () => {
        if (!button) return
        const on = isOn()
        button.innerHTML = on ? EXIT_ICON : ENTER_ICON
        button.title = on ? 'Exit fullscreen' : opts.title || 'Fullscreen'
        button.setAttribute('aria-label', button.title)
        button.setAttribute('aria-pressed', on ? 'true' : 'false')
    }

    // Leaflet measured the container at its old size; nothing lays out
    // correctly until it measures again. rAF so the browser has applied the
    // new box first.
    const resize = () => {
        requestAnimationFrame(() => map.invalidateSize({ animate: false }))
    }

    const setInteraction = (on) => {
        if (!opts.interactive) return
        if (on) {
            restoreHandlers = HANDLERS.filter((name) => map[name] && !map[name].enabled())
            restoreHandlers.forEach((name) => map[name].enable())
        } else if (restoreHandlers) {
            restoreHandlers.forEach((name) => map[name] && map[name].disable())
            restoreHandlers = null
        }
    }

    const settle = () => {
        setInteraction(isOn())
        paint()
        resize()
    }

    // Only for the fallback; a real fullscreen exit is the browser's own.
    const onKeydown = (e) => {
        if (e.key === 'Escape' && maximised) {
            e.preventDefault()
            maximise(false)
        }
    }

    function maximise(on) {
        maximised = on
        target.classList.toggle('leaflet-fullscreen-maximised', on)
        if (on) doc.addEventListener('keydown', onKeydown)
        else doc.removeEventListener('keydown', onKeydown)
        settle()
    }

    const toggle = () => {
        if (maximised) return maximise(false)

        if (fullscreenElement(doc) === target) {
            exitFullscreen(doc).catch(() => {})
            return
        }

        requestFullscreen(target).catch(() => maximise(true))
    }

    // Both spellings: Safari fires only the prefixed one.
    doc.addEventListener('fullscreenchange', settle)
    doc.addEventListener('webkitfullscreenchange', settle)

    const control = L.control({ position: opts.position || 'topleft' })

    control.onAdd = () => {
        const wrap = L.DomUtil.create('div', 'leaflet-bar leaflet-fullscreen')
        button = L.DomUtil.create('button', '', wrap)
        button.type = 'button'
        paint()

        // Without this a click on the button also reaches the map underneath,
        // which reads it as a double click and zooms in behind the change.
        L.DomEvent.disableClickPropagation(wrap)
        L.DomEvent.on(button, 'click', toggle)

        return wrap
    }

    control.addTo(map)

    return {
        control,
        isFullscreen: isOn,
        toggle,
        remove() {
            if (maximised) maximise(false)
            target.classList.remove('leaflet-fullscreen-target')
            doc.removeEventListener('fullscreenchange', settle)
            doc.removeEventListener('webkitfullscreenchange', settle)
            doc.removeEventListener('keydown', onKeydown)
            control.remove()
            button = null
        }
    }
}
