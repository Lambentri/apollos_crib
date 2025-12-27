class LeafletIcon extends HTMLElement {
    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        
        // Keep icon element lightweight
        this.shadowRoot.innerHTML = `
            <style>
                :host {
                    display: none; /* Hidden since we only use it for data */
                }
            </style>
        `;
    }

    static get observedAttributes() { 
        return ['icon-url', 'width', 'height']; 
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'icon-url' && oldValue !== newValue) {
            // Dispatch event to notify parent marker about icon URL change
            const event = new CustomEvent('url-updated', { 
                detail: newValue,
                bubbles: true
            });
            this.dispatchEvent(event);
        }
    }

    // Get icon data as an object
    getIconData() {
        return {
            iconUrl: this.getAttribute('icon-url'),
            width: parseInt(this.getAttribute('width')) || 32,
            height: parseInt(this.getAttribute('height')) || 32
        };
    }
}

window.customElements.define('leaflet-icon', LeafletIcon);
export default LeafletIcon;
