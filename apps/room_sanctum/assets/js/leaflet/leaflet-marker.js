class LeafletMarker extends HTMLElement {
    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        
        // Keep marker element lightweight
        this.shadowRoot.innerHTML = `
            <style>
                :host {
                    display: none; /* Hidden since we only use it for data */
                }
            </style>
            <slot></slot>
        `;
    }

    static get observedAttributes() { 
        return ['lat', 'lng', 'name', 'type', 'tint', 'vehicle-id', 'route-id', 'selected']; 
    }

    attributeChangedCallback(name, oldValue, newValue) {
        // Notify parent map component that this marker has changed
        if (oldValue !== newValue) {
            this.dispatchEvent(new CustomEvent('marker-updated', {
                bubbles: true,
                detail: {
                    attribute: name,
                    oldValue: oldValue,
                    newValue: newValue
                }
            }));
        }
    }

    // Get all marker data as an object
    getMarkerData() {
        return {
            id: this.getAttribute('id'),
            lat: parseFloat(this.getAttribute('lat')),
            lng: parseFloat(this.getAttribute('lng')),
            name: this.getAttribute('name') || 'Marker',
            type: this.getAttribute('type') || 'query',
            tint: this.getAttribute('tint'),
            vehicleId: this.getAttribute('vehicle-id'),
            routeId: this.getAttribute('route-id'),
            selected: this.getAttribute('selected') === 'true'
        };
    }
}

window.customElements.define('leaflet-marker', LeafletMarker);
export default LeafletMarker;
