import L from 'leaflet'
// Loaded as text (see --loader:.css=text) so it can be injected into the shadow
// root. The map renders inside a shadow DOM, which stylesheets in the main
// document cannot reach -- without this Leaflet's tiles have no positioning
// rules and lay themselves out as a grid of loose images.
import leafletCss from 'leaflet/dist/leaflet.css'

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
    </style>
    <div class="map-container">
        <slot></slot>
    </div>
`

class LeafletMap extends HTMLElement {
    constructor() {
        super();

        this.attachShadow({ mode: 'open' });
        this.shadowRoot.appendChild(template.content.cloneNode(true));
        this.mapElement = this.shadowRoot.querySelector('.map-container');
        
        // High-performance markers tracking
        this.markers = new Map(); // Track all markers by ID
        this.markerElements = new Map(); // Track marker DOM elements
        this.canvasRenderer = null;
        
        // Initialize after DOM is ready
        setTimeout(() => this.initializeMap(), 100);
    }

    static get observedAttributes() { 
        return ['lat', 'lng', 'zoom', 'use-streaming']; 
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (!this.map) return;
        
        if (name === 'lat' || name === 'lng' || name === 'zoom') {
            const lat = parseFloat(this.getAttribute('lat')) || 39.8283;
            const lng = parseFloat(this.getAttribute('lng')) || -98.5795;
            const zoom = parseInt(this.getAttribute('zoom')) || 4;
            this.map.setView([lat, lng], zoom);
        }
    }

    initializeMap() {
        if (this.map) return; // Already initialized

        const lat = parseFloat(this.getAttribute('lat')) || 39.8283;
        const lng = parseFloat(this.getAttribute('lng')) || -98.5795;
        const zoom = parseInt(this.getAttribute('zoom')) || 4;
        
        // Initialize canvas renderer for high performance
        this.canvasRenderer = L.canvas({ padding: 0.5 });

        this.map = L.map(this.mapElement).setView([lat, lng], zoom);
        
        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(this.map);

        // Initialize layer groups for different marker types
        this.queriesLayer = L.layerGroup().addTo(this.map);
        this.vehiclesLayer = L.layerGroup().addTo(this.map);
        this.freeBikesLayer = L.layerGroup().addTo(this.map);
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

        // One more pass after layout settles, for the first paint.
        requestAnimationFrame(() => this.map && this.map.invalidateSize({ animate: false }));

        console.log('Leaflet map initialized with Web Components');
    }

    connectedCallback() {
        // Observer for marker elements being added/removed
        this.observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach(node => {
                    if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'LEAFLET-MARKER') {
                        this.addMarkerElement(node);
                    }
                });
                
                mutation.removedNodes.forEach(node => {
                    if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'LEAFLET-MARKER') {
                        this.removeMarkerElement(node);
                    }
                });
            });
        });

        this.observer.observe(this, { childList: true, subtree: true });

        // Process existing markers
        setTimeout(() => {
            this.querySelectorAll('leaflet-marker').forEach(markerEl => {
                this.addMarkerElement(markerEl);
            });
        }, 200);
    }

    disconnectedCallback() {
        if (this.observer) {
            this.observer.disconnect();
        }
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
        if (this.map) {
            this.map.remove();
        }
    }

    addMarkerElement(markerEl) {
        if (!this.map) {
            // Map not ready yet, try again later
            setTimeout(() => this.addMarkerElement(markerEl), 100);
            return;
        }

        const lat = parseFloat(markerEl.getAttribute('lat'));
        const lng = parseFloat(markerEl.getAttribute('lng'));
        const markerId = markerEl.getAttribute('id') || `${lat}-${lng}`;
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
        const markerId = markerEl.getAttribute('id') || `${markerEl.getAttribute('lat')}-${markerEl.getAttribute('lng')}`;
        this.removeMarkerById(markerId);
    }

    removeMarkerById(markerId) {
        const existingMarker = this.markers.get(markerId);
        if (existingMarker) {
            this.map.removeLayer(existingMarker);
            this.markers.delete(markerId);
            this.markerElements.delete(markerId);
        }
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
        // Custom icon for vehicles
        const iconEl = markerEl.querySelector('leaflet-icon');
        const iconUrl = iconEl?.getAttribute('icon-url') || '/images/vehicle-icon.png';
        const iconSize = [
            parseInt(iconEl?.getAttribute('width')) || 32,
            parseInt(iconEl?.getAttribute('height')) || 32
        ];

        const icon = L.icon({
            iconUrl: iconUrl,
            iconSize: iconSize,
            iconAnchor: [iconSize[0]/2, iconSize[1]/2],
            popupAnchor: [0, -iconSize[1]/2]
        });

        return L.marker([lat, lng], { icon }).bindPopup(() => this.createPopupContent(markerEl));
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

        return L.circleMarker([lat, lng], {
            renderer: this.canvasRenderer,
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

        const newIcon = L.icon({
            iconUrl: iconUrl,
            iconSize: iconSize,
            iconAnchor: iconSize
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

        // Add type-specific content
        if (type === 'vehicle') {
            const vehicleId = markerEl.getAttribute('vehicle-id');
            const routeId = markerEl.getAttribute('route-id');
            content += `
                <div class="text-xs text-gray-600 mb-1">
                    <strong>Vehicle:</strong> ${vehicleId}
                </div>
                ${routeId ? `<div class="text-xs text-gray-600 mb-1"><strong>Route:</strong> ${routeId}</div>` : ''}
            `;
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
        
        // Clear the layer groups
        if (this.queriesLayer) this.queriesLayer.clearLayers();
        if (this.vehiclesLayer) this.vehiclesLayer.clearLayers();
        if (this.freeBikesLayer) this.freeBikesLayer.clearLayers();
        if (this.stationsLayer) this.stationsLayer.clearLayers();
    }
}

window.customElements.define('leaflet-map', LeafletMap);
export default LeafletMap;
