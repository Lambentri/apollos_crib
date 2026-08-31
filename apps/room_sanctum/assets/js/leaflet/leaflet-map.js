import L from 'leaflet'
// Loaded as text (see --loader:.css=text) so it can be injected into the shadow
// root. The map renders inside a shadow DOM, which stylesheets in the main
// document cannot reach -- without this Leaflet's tiles have no positioning
// rules and lay themselves out as a grid of loose images.
import leafletCss from 'leaflet/dist/leaflet.css'
import { addBasemap } from './basemap'

const template = document.createElement('template');
template.innerHTML = `
    <style>
      ${leafletCss}
      :host {
        display: block;
        width: 100%;
        height: 100%;
      }
      .map-container {
        width: 100%;
        height: 100%;
        min-height: 400px;
      }
      /* Only shown once the user has moved the map themselves; until then the
         map follows the data and there is nothing to reset to. */
      .leaflet-reset-view button {
        display: flex;
        align-items: center;
        gap: 4px;
        padding: 3px 7px;
        font: 600 11px/1.4 system-ui, sans-serif;
        color: #334155;
        background: #fff;
        border: none;
        border-radius: 4px;
        cursor: pointer;
      }
      .leaflet-reset-view button:hover {
        background: #f1f5f9;
      }
    </style>
    <div class="map-container">
        <slot></slot>
    </div>
`


// Leaflet draws circles on canvas and nothing else, but a map holding several
// offerings needs a third axis after fill (what kind of thing) and outline
// (which tint) -- so: shape says whose.
//
// This reaches into the Canvas renderer's internals (_drawing, _ctx,
// _fillStroke) because that is the only way to add a path type; they have been
// stable across Leaflet 1.x, and a break shows up as markers that do not draw
// rather than as a crash.
const SHAPE_POINTS = {
    square:   (x, y, r) => [[x - r, y - r], [x + r, y - r], [x + r, y + r], [x - r, y + r]],
    diamond:  (x, y, r) => [[x, y - r], [x + r, y], [x, y + r], [x - r, y]],
    triangle: (x, y, r) => [[x, y - r], [x + r, y + r * 0.8], [x - r, y + r * 0.8]],
    hexagon:  (x, y, r) => {
        const pts = [];
        for (let i = 0; i < 6; i++) {
            const a = Math.PI / 6 + (i * Math.PI) / 3;
            pts.push([x + r * Math.cos(a), y + r * Math.sin(a)]);
        }
        return pts;
    }
};

L.Canvas.include({
    _updateShapeMarker(layer) {
        if (!this._drawing || layer._empty()) return;

        const points = SHAPE_POINTS[layer.options.shape];
        if (!points) return this._updateCircle(layer);

        const p = layer._point;
        const r = Math.max(Math.round(layer._radius), 1);
        const ctx = this._ctx;
        const pts = points(p.x, p.y, r);

        ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
        ctx.closePath();
        this._fillStroke(ctx, layer);
    }
});

// Same geometry and hit-testing as a circleMarker -- only the drawing differs --
// so everything else about a marker keeps working.
const ShapeMarker = L.CircleMarker.extend({
    options: { shape: 'circle' },

    _updatePath() {
        if (!this.options.shape || this.options.shape === 'circle' || !SHAPE_POINTS[this.options.shape]) {
            return this._renderer._updateCircle(this);
        }
        this._renderer._updateShapeMarker(this);
    }
});

class LeafletMap extends HTMLElement {
    constructor() {
        super();

        this.attachShadow({ mode: 'open' });
        this.shadowRoot.appendChild(template.content.cloneNode(true));
        this.mapElement = this.shadowRoot.querySelector('.map-container');
        
        // High-performance markers tracking
        this.markers = new Map(); // Track all markers by ID
        this.markerElements = new Map(); // Track marker DOM elements
        // Which layer group each marker went into. Removing a marker from the
        // map alone leaves the group still holding it, so the group grows for
        // the life of the page and a re-added group brings ghosts back.
        this.markerLayers = new Map();
        this.lines = new Map();
        this.canvasRenderer = null;

        // The map follows the computed view until the user moves it, then
        // stays put and offers to start following again.
        this.followView = true;
        this.programmaticView = false;
        
        // Initialize after DOM is ready
        setTimeout(() => this.initializeMap(), 100);
    }

    static get observedAttributes() { 
        return ['lat', 'lng', 'zoom', 'use-streaming']; 
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (!this.map) return;

        if (name === 'lat' || name === 'lng' || name === 'zoom') {
            this.applyView();
        }
    }

    // The view attributes are recomputed from the data on every render, so
    // honouring them unconditionally yanked the map back to the centroid of a
    // moving fleet several times a minute -- which is what a redraw looked
    // like even when no marker was touched.
    applyView(force = false) {
        if (!this.map || (!force && !this.followView)) return;

        const lat = parseFloat(this.getAttribute('lat'));
        const lng = parseFloat(this.getAttribute('lng'));
        const zoom = parseInt(this.getAttribute('zoom'));

        if (isNaN(lat) || isNaN(lng)) return;

        const target = L.latLng(lat, lng);
        const nextZoom = isNaN(zoom) ? this.map.getZoom() : zoom;

        if (!force && this.map.getZoom() === nextZoom && !this.viewDriftedFrom(target)) return;

        this.programmaticView = true;
        try {
            this.map.setView(target, nextZoom, { animate: true });
        } finally {
            this.programmaticView = false;
        }
    }

    // A centroid never sits still while vehicles move, so following it exactly
    // would leave the map permanently drifting. Only move once the target has
    // left the middle half of the viewport.
    viewDriftedFrom(target) {
        const bounds = this.map.getBounds();
        const centre = this.map.getCenter();
        const latSlack = (bounds.getNorth() - bounds.getSouth()) / 4;
        const lngSlack = (bounds.getEast() - bounds.getWest()) / 4;

        return Math.abs(target.lat - centre.lat) > latSlack ||
               Math.abs(target.lng - centre.lng) > lngSlack;
    }

    // Both fire synchronously from inside setView, so the flag set around it is
    // enough to tell our own moves from the user's. movestart rather than
    // dragstart because keyboard panning never drags.
    watchForUserView() {
        const stopFollowing = () => {
            if (this.programmaticView || !this.followView) return;
            this.followView = false;
            this.updateResetControl();
        };

        this.map.on('movestart', stopFollowing);
        this.map.on('zoomstart', stopFollowing);
    }

    addResetViewControl() {
        const control = L.control({ position: 'bottomleft' });

        control.onAdd = () => {
            const wrap = L.DomUtil.create('div', 'leaflet-bar leaflet-reset-view');
            wrap.innerHTML = `
                <button type="button" title="Recentre, and follow the data again">
                  <svg viewBox="0 0 24 24" width="11" height="11" aria-hidden="true">
                    <circle cx="12" cy="12" r="6.5" fill="none" stroke="currentColor" stroke-width="2.2" />
                    <path d="M12 1.5v3.5M12 19v3.5M1.5 12h3.5M19 12h3.5"
                          stroke="currentColor" stroke-width="2.2" stroke-linecap="round" />
                  </svg>
                  <span>Reset view</span>
                </button>
            `;

            L.DomEvent.disableClickPropagation(wrap);
            wrap.querySelector('button').addEventListener('click', () => {
                this.followView = true;
                this.applyView(true);
                this.updateResetControl();
            });

            return wrap;
        };

        control.addTo(this.map);
        this.resetViewControl = control;
        this.updateResetControl();
    }

    updateResetControl() {
        const el = this.resetViewControl && this.resetViewControl.getContainer();
        if (el) el.style.display = this.followView ? 'none' : '';
    }

    initializeMap() {
        if (this.map) return; // Already initialized

        const lat = parseFloat(this.getAttribute('lat')) || 39.8283;
        const lng = parseFloat(this.getAttribute('lng')) || -98.5795;
        const zoom = parseInt(this.getAttribute('zoom')) || 4;
        
        // Initialize canvas renderer for high performance
        this.canvasRenderer = L.canvas({ padding: 0.5 });

        this.map = L.map(this.mapElement).setView([lat, lng], zoom);
        
        // Resolve theme variables against the host rather than <html>: custom
        // properties inherit through the shadow boundary, so this picks up any
        // data-theme set closer to the element.
        this.basemap = addBasemap(this.map, {
            styleFrom: this,
            variant: this.getAttribute('basemap') || 'auto',
            tint: this.getAttribute('tint') || undefined,
            strength: this.getAttribute('tint-strength') || undefined,
            // labels="false" trades readable type for one tile request per
            // tile instead of two.
            labels: this.getAttribute('labels') !== 'false'
        });

        // Route lines sit above the theme wash but below the basemap labels and
        // every marker pane, so they read as part of the map rather than as
        // something drawn over it.
        const linePane = this.map.createPane('routeLines');
        linePane.style.zIndex = '260';
        linePane.style.pointerEvents = 'none';
        this.lineRenderer = L.canvas({ pane: 'routeLines', padding: 0.5 });
        this.linesLayer = L.layerGroup().addTo(this.map);

        // Initialize layer groups for different marker types
        this.queriesLayer = L.layerGroup().addTo(this.map);
        this.vehiclesLayer = L.layerGroup().addTo(this.map);
        this.freeBikesLayer = L.layerGroup().addTo(this.map);
        this.aircraftLayer = L.layerGroup().addTo(this.map);
        this.stationsLayer = L.layerGroup().addTo(this.map);

        // Set up streaming event handlers if enabled
        if (this.getAttribute('use-streaming') === 'true') {
            this.setupStreamingHandlers();
        }

        // Leaflet measures its container once, at init. Inside a flex column
        // that width is not final yet, so without this the panes keep the
        // stale size and spill outside the element's box.
        this.resizeObserver = new ResizeObserver(() => {
            if (this.map) this.map.invalidateSize({ animate: false });
        });
        this.resizeObserver.observe(this.mapElement);

        // After the initial setView, so it is not mistaken for a user move.
        this.watchForUserView();
        this.addResetViewControl();

        // One more pass after layout settles, for the first paint.
        requestAnimationFrame(() => this.map && this.map.invalidateSize({ animate: false }));

        console.log('Leaflet map initialized with Web Components');
    }

    connectedCallback() {
        // Observer for marker elements being added/removed
        // Reordering a child is one removal and one insertion of the *same*
        // node, and the two records arrive in whichever order the patch made
        // them -- so acting on each record in turn either rebuilt the marker
        // for nothing or, when the addition came first, deleted it outright.
        // Collect the nodes the batch touched and ask the DOM what became of
        // each one instead.
        this.observer = new MutationObserver((mutations) => {
            const touched = new Set();

            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach(node => this.collectTouched(node, touched));
                mutation.removedNodes.forEach(node => this.collectTouched(node, touched));
            });

            touched.forEach(node => this.reconcileNode(node));
        });

        this.observer.observe(this, { childList: true, subtree: true });

        // leaflet-marker has always announced attribute changes, but nothing
        // listened, and the MutationObserver above only watches childList. A
        // marker that moved therefore kept the position it was created at for
        // the life of the element -- which is every GTFS vehicle and every
        // free bike, since LiveView patches their lat/lng in place and their
        // ids are stable.
        this.pendingMarkerUpdates = new Map();
        this.addEventListener('marker-updated', (event) => {
            const markerEl = event.target;
            if (!markerEl || markerEl.tagName !== 'LEAFLET-MARKER') return;

            const changed = this.pendingMarkerUpdates.get(markerEl) || new Set();
            changed.add(event.detail && event.detail.attribute);
            this.pendingMarkerUpdates.set(markerEl, changed);

            // lat and lng arrive as two separate events; coalesce so a move is
            // one update rather than two. A microtask rather than a frame:
            // LiveView patches every attribute in a single task, so this still
            // batches the whole update, and unlike requestAnimationFrame it is
            // not suspended while the tab is in the background.
            if (this.markerUpdateQueued) return;
            this.markerUpdateQueued = true;
            queueMicrotask(() => {
                this.markerUpdateQueued = false;
                const batch = this.pendingMarkerUpdates;
                this.pendingMarkerUpdates = new Map();
                batch.forEach((attrs, el) => this.applyMarkerUpdate(el, attrs));
            });
        });

        this.addEventListener('line-updated', (event) => {
            const lineEl = event.target;
            if (lineEl && lineEl.tagName === 'LEAFLET-LINE') this.addLineElement(lineEl);
        });

        // Process existing markers and lines
        setTimeout(() => {
            this.querySelectorAll('leaflet-marker').forEach(markerEl => {
                this.addMarkerElement(markerEl);
            });
            this.querySelectorAll('leaflet-line').forEach(lineEl => {
                this.addLineElement(lineEl);
            });
        }, 200);
    }

    collectTouched(node, touched) {
        if (node.nodeType !== Node.ELEMENT_NODE) return;
        if (node.tagName === 'LEAFLET-MARKER' || node.tagName === 'LEAFLET-LINE') touched.add(node);
    }

    reconcileNode(node) {
        const isMarker = node.tagName === 'LEAFLET-MARKER';

        if (!this.contains(node)) {
            isMarker ? this.removeMarkerElement(node) : this.removeLineElement(node);
            return;
        }

        // Still ours: only a node we are not already drawing needs building. A
        // node that merely moved is identical to the one we hold, and an id
        // reused by a different element does need rebuilding.
        if (isMarker) {
            if (this.markerElements.get(this.markerIdFor(node)) !== node) this.addMarkerElement(node);
        } else if (this.lines.get(node.getAttribute('id')) === undefined) {
            this.addLineElement(node);
        }
    }

    disconnectedCallback() {
        if (this.observer) {
            this.observer.disconnect();
        }
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
        // Before map.remove(), and unconditionally: the tint registers a
        // theme-change callback module-side, which would otherwise outlive
        // every map torn down by a LiveView navigation.
        if (this.basemap) {
            this.basemap.remove();
            this.basemap = null;
        }
        if (this.map) {
            this.map.remove();
        }
    }

    addLineElement(lineEl) {
        if (!this.map) {
            setTimeout(() => this.addLineElement(lineEl), 100);
            return;
        }

        const lineId = lineEl.getAttribute('id');
        const points = lineEl.getPoints ? lineEl.getPoints() : [];

        this.removeLineById(lineId);
        if (points.length < 2) return;

        const style = lineEl.getStyle();
        const polyline = L.polyline(points, {
            renderer: this.lineRenderer,
            pane: 'routeLines',
            interactive: false,
            ...style
        });

        this.linesLayer.addLayer(polyline);
        this.lines.set(lineId, polyline);
    }

    removeLineElement(lineEl) {
        this.removeLineById(lineEl.getAttribute('id'));
    }

    removeLineById(lineId) {
        const existing = this.lines.get(lineId);
        if (!existing) return;
        this.linesLayer.removeLayer(existing);
        this.lines.delete(lineId);
    }

    // What the marker is drawn from. Everything else -- the name, the route,
    // the vehicle id -- is only ever read back out of the element when a popup
    // opens, so changing it needs no new layer.
    static get ICON_ATTRIBUTES() {
        return new Set(['type', 'tint', 'shape', 'route-type', 'aircraft-class']);
    }

    markerIdFor(markerEl) {
        return markerEl.getAttribute('id') ||
            `${parseFloat(markerEl.getAttribute('lat'))}-${parseFloat(markerEl.getAttribute('lng'))}`;
    }

    // Sliding the existing layer is far cheaper than rebuilding it and leaves
    // an open popup open -- worth having when a whole fleet shifts every
    // refresh. This used to require that *only* lat and lng changed, which no
    // moving marker satisfies: vehicles and aircraft report a new bearing with
    // every position, so each one was torn down and rebuilt on every tick.
    applyMarkerUpdate(markerEl, changedAttributes) {
        if (!this.map || !markerEl.isConnected) return;

        const existing = this.markers.get(this.markerIdFor(markerEl));
        if (!existing || !existing.setLatLng) return this.addMarkerElement(markerEl);

        for (const name of changedAttributes) {
            if (LeafletMap.ICON_ATTRIBUTES.has(name)) return this.addMarkerElement(markerEl);
        }

        if (changedAttributes.has('lat') || changedAttributes.has('lng')) {
            const lat = parseFloat(markerEl.getAttribute('lat'));
            const lng = parseFloat(markerEl.getAttribute('lng'));
            if (isNaN(lat) || isNaN(lng)) return this.addMarkerElement(markerEl);
            existing.setLatLng([lat, lng]);
        }

        if (changedAttributes.has('bearing') && !this.rotateMarker(existing, markerEl)) {
            return this.addMarkerElement(markerEl);
        }

        // The popup builds its content lazily, so a stale one only exists while
        // it is on screen.
        if (existing.isPopupOpen && existing.isPopupOpen()) {
            existing.setPopupContent(this.createPopupContent(markerEl));
        }
    }

    // Turning the part of the icon that points somewhere, rather than building
    // a whole new icon for a heading change. False means this marker cannot be
    // turned in place -- an image icon, or a heading appearing or disappearing,
    // which swaps the symbol itself -- and the caller rebuilds it.
    rotateMarker(marker, markerEl) {
        const element = marker.getElement && marker.getElement();
        const rotating = element && element.querySelector('[data-rotates]');
        if (!rotating) return false;

        const bearing = parseFloat(markerEl.getAttribute('bearing'));
        if (isNaN(bearing)) return false;

        rotating.setAttribute('transform', `rotate(${bearing} 12 12)`);
        return true;
    }

    addMarkerElement(markerEl) {
        if (!this.map) {
            // Map not ready yet, try again later
            setTimeout(() => this.addMarkerElement(markerEl), 100);
            return;
        }

        const lat = parseFloat(markerEl.getAttribute('lat'));
        const lng = parseFloat(markerEl.getAttribute('lng'));
        const markerId = this.markerIdFor(markerEl);
        const markerType = markerEl.getAttribute('type') || 'query';

        if (isNaN(lat) || isNaN(lng)) {
            console.warn('Invalid lat/lng for marker:', markerEl);
            return;
        }

        // Remove existing marker if it exists
        this.removeMarkerById(markerId);

        // Determine which layer to use and create appropriate marker
        let leafletMarker;
        let layer = this.queriesLayer; // default

        switch (markerType) {
            case 'vehicle':
                leafletMarker = this.createVehicleMarker(lat, lng, markerEl);
                layer = this.vehiclesLayer;
                break;
            case 'free-bike':
            case 'free_bike':
                leafletMarker = this.createFreeBikeMarker(lat, lng, markerEl);
                layer = this.freeBikesLayer;
                break;
            case 'aircraft':
                leafletMarker = this.createAircraftMarker(lat, lng, markerEl);
                layer = this.aircraftLayer;
                break;

            case 'station':
                leafletMarker = this.createStationMarker(lat, lng, markerEl);
                layer = this.stationsLayer;
                break;
            case 'query':
            default:
                // Use high-performance canvas markers for queries (can be many)
                leafletMarker = this.createOptimizedQueryMarker(lat, lng, markerEl);
                layer = this.queriesLayer;
                break;
        }

        if (leafletMarker) {
            layer.addLayer(leafletMarker);
            this.markers.set(markerId, leafletMarker);
            this.markerElements.set(markerId, markerEl);
            this.markerLayers.set(markerId, layer);

            // Set up click forwarding from Leaflet marker to DOM element
            leafletMarker.on('click', () => {
                markerEl.click();
            });

            // The popup's DOM only exists once opened, so bind the action then.
            leafletMarker.on('popupopen', (e) => {
                const btn = e.popup.getElement()?.querySelector('[data-add-query-btn]');
                if (!btn || btn.dataset.bound) return;
                btn.dataset.bound = '1';
                btn.addEventListener('click', (ev) => {
                    ev.stopPropagation();
                    // Target the hidden child, not the marker itself -- the map
                    // forwards marker clicks, which would fire this on any click.
                    const target = markerEl.querySelector('[data-add-query-target]');
                    if (target) target.click();
                    leafletMarker.closePopup();
                });
            });

            // Watch for icon updates
            const iconEl = markerEl.querySelector('leaflet-icon');
            if (iconEl) {
                iconEl.addEventListener('url-updated', (e) => {
                    this.updateMarkerIcon(leafletMarker, iconEl, markerEl);
                });
            }
        }
    }

    removeMarkerElement(markerEl) {
        this.removeMarkerById(this.markerIdFor(markerEl));
    }

    removeMarkerById(markerId) {
        const existingMarker = this.markers.get(markerId);
        if (!existingMarker) return;

        // Through the group that holds it: taking it off the map alone leaves
        // the group's own reference behind, so the group grows without bound
        // and clearing it later resurrects markers that are long gone.
        const layer = this.markerLayers.get(markerId);
        layer ? layer.removeLayer(existingMarker) : this.map.removeLayer(existingMarker);

        this.markers.delete(markerId);
        this.markerElements.delete(markerId);
        this.markerLayers.delete(markerId);
    }

    createOptimizedQueryMarker(lat, lng, markerEl) {
        // A star, not a circle: unmistakable against the docks and bikes, and
        // there are few enough queries that a DOM icon costs nothing.
        return L.marker([lat, lng], {
            icon: this.createStarIcon(this.getMarkerColor(markerEl), this.getStrokeColor(markerEl), 22),
            keyboard: false,
        }).bindPopup(() => this.createPopupContent(markerEl));
    }

    createVehicleMarker(lat, lng, markerEl) {
        // An explicit <leaflet-icon icon-url> still wins, but the default is
        // drawn rather than fetched. It used to fall back to
        // /images/vehicle-icon.png, which is not in priv/static -- so every
        // transit vehicle rendered a broken image, and since Leaflet's marker
        // alt defaults to "Marker" what you actually saw was clipped alt text
        // where the vehicle should be.
        const iconEl = markerEl.querySelector('leaflet-icon');
        const iconUrl = iconEl?.getAttribute('icon-url');

        if (iconUrl) {
            const iconSize = [
                parseInt(iconEl.getAttribute('width')) || 32,
                parseInt(iconEl.getAttribute('height')) || 32
            ];

            const icon = L.icon({
                iconUrl: iconUrl,
                iconSize: iconSize,
                iconAnchor: [iconSize[0] / 2, iconSize[1] / 2],
                popupAnchor: [0, -iconSize[1] / 2],
                // Empty rather than Leaflet's "Marker" default: if this URL is
                // also missing, show nothing instead of a word on the map.
                alt: ''
            });

            return L.marker([lat, lng], { icon }).bindPopup(() => this.createPopupContent(markerEl));
        }

        const bearing = parseFloat(markerEl.getAttribute('bearing'));

        return L.marker([lat, lng], {
            icon: this.createVehicleIcon(
                this.getMarkerColor(markerEl),
                this.getStrokeColor(markerEl),
                isNaN(bearing) ? null : bearing,
                LeafletMap.VEHICLE_KIND_BY_ROUTE_TYPE[markerEl.getAttribute('route-type')],
                26
            ),
            keyboard: false,
        }).bindPopup(() => this.createPopupContent(markerEl));
    }

    // Glyphs are drawn rather than pulled from Font Awesome: the map lives in
    // a shadow root, and the document's .fa-* rules do not cross that
    // boundary, so an <i class="fa-bus"> renders as nothing in here.
    //
    // GTFS route_type is finer-grained than a 10px glyph can express, so the
    // types are grouped down to shapes that stay legible at marker size.
    static get VEHICLE_GLYPHS() {
        return {
            // rounded body, windscreen band, two wheels
            bus: '<path d="M8 8.5h8v5.2H8z" fill="#fff"/><path d="M8.6 9.4h6.8v1.8H8.6z" fill="currentColor"/>' +
                 '<circle cx="9.6" cy="14.4" r="0.9" fill="#fff"/><circle cx="14.4" cy="14.4" r="0.9" fill="#fff"/>',
            // body with a pantograph stroke on the roof
            tram: '<path d="M8.4 8.6h7.2v5.4H8.4z" fill="#fff"/><path d="M9.1 9.4h5.8v1.7H9.1z" fill="currentColor"/>' +
                  '<path d="M12 6.6v2" stroke="#fff" stroke-width="1" stroke-linecap="round"/>',
            // blunt-nosed carriage
            train: '<path d="M8.4 8.4h7.2v4.4a2.4 2.4 0 0 1-2.4 2.4h-2.4a2.4 2.4 0 0 1-2.4-2.4z" fill="#fff"/>' +
                   '<path d="M9.2 9.2h5.6v2H9.2z" fill="currentColor"/>',
            // hull plus a short mast
            ferry: '<path d="M7.6 12.6h8.8l-1.4 2.6H9z" fill="#fff"/><path d="M11.4 8.2h1.2v4h-1.2z" fill="#fff"/>',
            // cabin hanging from a cable
            gondola: '<path d="M6.6 8h10.8" stroke="#fff" stroke-width="1" stroke-linecap="round"/>' +
                     '<path d="M12 8v1.8" stroke="#fff" stroke-width="1"/>' +
                     '<path d="M9.6 9.8h4.8v4.4H9.6z" fill="#fff"/>'
        };
    }

    static get VEHICLE_KIND_BY_ROUTE_TYPE() {
        return {
            '0': 'tram',    // tram, streetcar, light rail
            '1': 'train',   // subway, metro
            '2': 'train',   // rail
            '3': 'bus',
            '4': 'ferry',
            '5': 'tram',    // cable tram
            '6': 'gondola', // aerial lift
            '7': 'gondola', // funicular
            '11': 'bus',    // trolleybus
            '12': 'train'   // monorail
        };
    }

    // A disc carrying the vehicle kind, with a pointer along the direction of
    // travel. The pointer rotates; the glyph deliberately does not, so it
    // stays readable whichever way the vehicle is heading.
    createVehicleIcon(fill, stroke, bearing, kind, size) {
        const pointer =
            bearing === null
                ? ''
                : `<polygon data-rotates points="12,0.8 15.2,6.4 8.8,6.4" fill="${fill}" stroke="${stroke}"
                            stroke-width="1.4" stroke-linejoin="round"
                            transform="rotate(${bearing} 12 12)" />`;

        const glyph = LeafletMap.VEHICLE_GLYPHS[kind] || '';

        return L.divIcon({
            className: 'leaflet-vehicle-icon',
            html: `<svg width="${size}" height="${size}" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"
                        style="color:${fill}">
                     ${pointer}
                     <circle cx="12" cy="12" r="7.4" fill="${fill}" stroke="${stroke}" stroke-width="1.4" />
                     ${glyph}
                   </svg>`,
            iconSize: [size, size],
            iconAnchor: [size / 2, size / 2],
            popupAnchor: [0, -size / 2],
        });
    }

    createAircraftMarker(lat, lng, markerEl) {
        const track = parseFloat(markerEl.getAttribute('bearing'));

        return L.marker([lat, lng], {
            icon: this.createAircraftIcon(
                this.aircraftColor(markerEl.getAttribute('aircraft-class')),
                this.getStrokeColor(markerEl),
                isNaN(track) ? null : track,
                22
            ),
            keyboard: false,
        }).bindPopup(() => this.createPopupContent(markerEl));
    }

    // Unlike a bus, the whole aircraft turns: a plane symbol that did not point
    // along its track would be misleading, so the silhouette rotates rather
    // than a separate pointer.
    createAircraftIcon(fill, stroke, track, size) {
        const plane =
            '12,1 13.6,8 22,12.5 22,14.5 13.6,12.3 13.2,18.5 16,20.5 16,22 ' +
            '12,20.8 8,22 8,20.5 10.8,18.5 10.4,12.3 2,14.5 2,12.5 10.4,8';

        // No track at all: a disc, so the marker never claims a heading it
        // does not have.
        const body =
            track === null
                ? `<circle cx="12" cy="12" r="5.5" fill="${fill}" stroke="${stroke}" stroke-width="1.4" />`
                : `<polygon data-rotates points="${plane}" fill="${fill}" stroke="${stroke}" stroke-width="1.2"
                            stroke-linejoin="round" transform="rotate(${track} 12 12)" />`;

        return L.divIcon({
            className: 'leaflet-aircraft-icon',
            html: `<svg width="${size}" height="${size}" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">${body}</svg>`,
            iconSize: [size, size],
            iconAnchor: [size / 2, size / 2],
            popupAnchor: [0, -size / 2],
        });
    }

    aircraftColor(klass) {
        const byClass = {
            military: '#dc2626',   // red
            cargo: '#f97316',      // orange
            commercial: '#38bdf8', // light blue
            general: '#a3a3a3'     // grey
        };

        return byClass[klass] || byClass.general;
    }

    createFreeBikeMarker(lat, lng, markerEl) {
        // Smaller markers for bikes
        const color = this.getMarkerColor(markerEl);
        
        return L.circleMarker([lat, lng], {
            renderer: this.canvasRenderer,
            radius: 4,
            weight: this.hasTint(markerEl) ? 2 : 1,
            color: this.getStrokeColor(markerEl),
            fillColor: color,
            fillOpacity: 0.9,
            fill: true,
        }).bindPopup(() => this.createPopupContent(markerEl));
    }

    createStationMarker(lat, lng, markerEl) {
        const color = this.getMarkerColor(markerEl);

        // Already queried -> star, so it matches the query markers it is one of.
        if (this.markerHasQuery(markerEl)) {
            return L.marker([lat, lng], {
                icon: this.createStarIcon(color, this.getStrokeColor(markerEl), 20),
                keyboard: false,
            }).bindPopup(() => this.createPopupContent(markerEl));
        }

        return new ShapeMarker([lat, lng], {
            renderer: this.canvasRenderer,
            shape: markerEl.getAttribute('shape') || 'circle',
            radius: 7,
            weight: this.hasTint(markerEl) ? 3 : 2,
            color: this.getStrokeColor(markerEl),
            fillColor: color,
            fillOpacity: 0.85,
            fill: true,
        }).bindPopup(() => this.createPopupContent(markerEl));
    }

    updateMarkerIcon(leafletMarker, iconEl, markerEl) {
        const iconUrl = iconEl.getAttribute('icon-url');
        const iconSize = [
            parseInt(iconEl.getAttribute('width')) || 32,
            parseInt(iconEl.getAttribute('height')) || 32
        ];

        // No icon-url means there is no image to switch to; leave whatever the
        // marker already draws rather than replacing it with a broken image.
        if (!iconUrl) return;

        const newIcon = L.icon({
            iconUrl: iconUrl,
            iconSize: iconSize,
            iconAnchor: iconSize,
            // Leaflet defaults this to "Marker", which is what shows when the
            // image fails to load.
            alt: ''
        });

        leafletMarker.setIcon(newIcon);
    }

    // Fill says *what* the marker is; the outline says which tint it belongs to.
    // Previously tint won outright, so a source with a tint painted its queries
    // and its stations the same colour and the type was invisible.
    getMarkerColor(markerEl) {
        // A dock that already has a query reads as a query, not a dock.
        if (this.markerHasQuery(markerEl)) return '#f59e0b'; // amber

        // Indigo vs sky was indistinguishable; these are far apart.
        const byType = {
            'query': '#f59e0b',      // amber
            'station': '#2563eb',    // blue
            'free_bike': '#16a34a',  // green
            'free-bike': '#16a34a',
            'vehicle': '#dc2626',    // red
        };

        return byType[markerEl.getAttribute('type') || 'query'] || '#6b7280';
    }

    // Outline: the tint if one is set, otherwise white so the marker still
    // reads against the map.
    getStrokeColor(markerEl) {
        return this.tintColor(markerEl.getAttribute('tint')) || '#ffffff';
    }

    markerHasQuery(markerEl) {
        return markerEl.hasAttribute('data-has-query');
    }

    // Inline SVG rather than a Font Awesome glyph: the map lives in a shadow
    // root, which stylesheets in the main document cannot reach.
    createStarIcon(fill, stroke, size) {
        const points = '12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26';

        return L.divIcon({
            className: 'leaflet-star-icon',
            html: `<svg width="${size}" height="${size}" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                     <polygon points="${points}" fill="${fill}" stroke="${stroke}" stroke-width="1.5"
                              stroke-linejoin="round" />
                   </svg>`,
            iconSize: [size, size],
            iconAnchor: [size / 2, size / 2],
            popupAnchor: [0, -size / 2],
        });
    }

    hasTint(markerEl) {
        return this.tintColor(markerEl.getAttribute('tint')) !== null;
    }

    tintColor(tint) {
        const colorMap = {
            'red': '#ef4444',
            'orange': '#f97316',
            'amber': '#f59e0b',
            'yellow': '#eab308',
            'lime': '#84cc16',
            'green': '#22c55e',
            'emerald': '#10b981',
            'teal': '#14b8a6',
            'cyan': '#06b6d4',
            'sky': '#0ea5e9',
            'blue': '#3b82f6',
            'indigo': '#6366f1',
            'violet': '#8b5cf6',
            'purple': '#a855f7',
            'fuchsia': '#d946ef',
            'pink': '#ec4899',
            'rose': '#f43f5e',
            'stone': '#78716c',
            'slate': '#64748b',
        };

        return colorMap[tint] || null;
    }

    createPopupContent(markerEl) {
        // Extract data from marker element attributes
        const name = markerEl.getAttribute('name') || 'Marker';
        const lat = markerEl.getAttribute('lat');
        const lng = markerEl.getAttribute('lng');
        const type = markerEl.getAttribute('type') || 'query';
        
        // Get additional attributes based on type
        let content = `
            <div class="p-2 min-w-48">
                <h3 class="font-semibold text-sm mb-2">${name}</h3>
                <div class="text-xs text-gray-500 mb-2">
                    <i class="fa-solid fa-location-dot mr-1"></i>
                    ${parseFloat(lat).toFixed(4)}, ${parseFloat(lng).toFixed(4)}
                </div>
        `;

        // Only rows we actually have. This used to print the vehicle-id and
        // route-id attributes, which nothing set, so every transit popup read
        // "Vehicle: null".
        const row = (label, value) =>
            value
                ? `<div class="text-xs text-gray-600 mb-1"><strong>${label}:</strong> ${value}</div>`
                : '';

        if (type === 'vehicle') {
            content +=
                row('Route', markerEl.getAttribute('route')) +
                row('To', markerEl.getAttribute('dest')) +
                row('Direction', markerEl.getAttribute('direction')) +
                row('Mode', markerEl.getAttribute('mode')) +
                row('Vehicle', markerEl.getAttribute('vehicle-id'));
        }

        if (type === 'aircraft') {
            content +=
                row('Class', markerEl.getAttribute('aircraft-class')) +
                row('Heading', markerEl.getAttribute('bearing'));
        }

        content += `</div>`;
        // Opt-in: the marker element carries phx-click, so routing the button
        // through markerEl.click() reuses the forwarding that already exists
        // rather than reaching into LiveView from here.
        if (markerEl.hasAttribute('data-add-query')) {
            content += `
                <button type="button" data-add-query-btn
                        class="mt-2 w-full text-xs font-semibold rounded px-2 py-1 bg-indigo-600 text-white hover:bg-indigo-700">
                    + query
                </button>
            `;
        }

        return content;
    }

    // High-performance streaming handlers (adapted from original implementation)
    setupStreamingHandlers() {
        // Listen for custom events from parent LiveView
        this.addEventListener('add-markers-batch', (e) => {
            this.addMarkersBatch(e.detail);
        });

        this.addEventListener('clear-markers', () => {
            this.clearAllMarkers();
        });
    }

    addMarkersBatch(markers) {
        if (!markers || markers.length === 0) return;

        console.log(`Adding ${markers.length} markers in batch via Web Components`);
        
        // Use requestAnimationFrame for non-blocking batch processing
        const addBatch = (startIndex) => {
            const batchSize = 100;
            const endIndex = Math.min(startIndex + batchSize, markers.length);
            
            for (let i = startIndex; i < endIndex; i++) {
                const markerData = markers[i];
                this.createStreamedMarker(markerData);
            }
            
            if (endIndex < markers.length) {
                requestAnimationFrame(() => addBatch(endIndex));
            } else {
                console.log(`Finished adding ${markers.length} streaming markers`);
            }
        };
        
        requestAnimationFrame(() => addBatch(0));
    }

    createStreamedMarker(markerData) {
        // Create and append a marker element for streamed data
        const markerEl = document.createElement('leaflet-marker');
        markerEl.setAttribute('lat', markerData.lat);
        markerEl.setAttribute('lng', markerData.lng);
        markerEl.setAttribute('name', markerData.name || 'Streamed Marker');
        markerEl.setAttribute('type', markerData.type || 'query');
        markerEl.setAttribute('tint', markerData.tint || 'blue');
        markerEl.setAttribute('id', markerData.id || `streamed-${markerData.lat}-${markerData.lng}`);
        
        // Add to DOM - this will trigger the mutation observer
        this.appendChild(markerEl);
    }

    clearAllMarkers() {
        // Remove all marker DOM elements - this will trigger cleanup
        this.querySelectorAll('leaflet-marker').forEach(el => el.remove());
        
        // Clear the maps as well
        this.markers.clear();
        this.markerElements.clear();
        this.markerLayers.clear();
        
        // Clear the layer groups
        if (this.queriesLayer) this.queriesLayer.clearLayers();
        if (this.vehiclesLayer) this.vehiclesLayer.clearLayers();
        if (this.freeBikesLayer) this.freeBikesLayer.clearLayers();
        if (this.stationsLayer) this.stationsLayer.clearLayers();
    }
}

window.customElements.define('leaflet-map', LeafletMap);
export default LeafletMap;
