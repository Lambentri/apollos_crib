// A polyline expressed as a DOM child of <leaflet-map>, so route geometry
// arrives and leaves the same way markers do -- LiveView adds and removes the
// elements, the map's MutationObserver notices.
class LeafletLine extends HTMLElement {
    constructor() {
        super();
        this.attachShadow({ mode: 'open' });

        // Data only; the drawing happens on the Leaflet canvas.
        this.shadowRoot.innerHTML = `
            <style>
                :host { display: none; }
            </style>
            <slot></slot>
        `;
    }

    static get observedAttributes() {
        return ['points', 'color', 'weight', 'opacity'];
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (oldValue !== newValue) {
            this.dispatchEvent(new CustomEvent('line-updated', {
                bubbles: true,
                detail: { attribute: name, oldValue, newValue }
            }));
        }
    }

    // [[lat, lng], ...]; anything unparseable is treated as no line at all
    // rather than throwing inside the map's observer callback.
    getPoints() {
        const raw = this.getAttribute('points');
        if (!raw) return [];

        try {
            const parsed = JSON.parse(raw);
            if (!Array.isArray(parsed)) return [];
            return parsed.filter(
                (p) => Array.isArray(p) && p.length === 2 && isFinite(p[0]) && isFinite(p[1])
            );
        } catch (e) {
            console.warn('leaflet-line: could not parse points', e);
            return [];
        }
    }

    getStyle() {
        return {
            color: this.getAttribute('color') || '#94a3b8',
            weight: parseFloat(this.getAttribute('weight')) || 2,
            opacity: this.hasAttribute('opacity') ? parseFloat(this.getAttribute('opacity')) : 0.35
        };
    }
}

window.customElements.define('leaflet-line', LeafletLine);

export default LeafletLine;
