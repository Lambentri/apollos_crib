/**
 * Bridge hook to connect Phoenix LiveView events to Web Components
 * This allows us to maintain the streaming functionality while using Web Components
 */

const LeafletMapBridge = {
  mounted() {
    this.mapElement = this.el.querySelector('leaflet-map');
    if (!this.mapElement) {
      console.warn('LeafletMapBridge: No leaflet-map element found');
      return;
    }

    console.log('LeafletMapBridge mounted, found map element:', this.mapElement);
    
    // Set up event handlers for streaming data
    this.setupStreamHandlers();
  },

  updated() {
    // Re-establish connection if map element changed
    const newMapElement = this.el.querySelector('leaflet-map');
    if (newMapElement !== this.mapElement) {
      this.mapElement = newMapElement;
      this.setupStreamHandlers();
    }
  },

  setupStreamHandlers() {
    if (!this.mapElement) return;

    // Handle streaming marker data from server
    this.handleEvent("add_markers_batch", (data) => {
      console.log('Bridge received add_markers_batch:', data);
      
      // Decompress data if needed
      let markers = data.compressed_data;
      if (typeof markers === 'string') {
        markers = this.decompressData(markers);
      }

      // Dispatch custom event to the Web Component
      const event = new CustomEvent('add-markers-batch', {
        detail: markers,
        bubbles: false
      });
      this.mapElement.dispatchEvent(event);
    });

    this.handleEvent("map_streaming_complete", () => {
      console.log('Bridge received streaming complete');
      const event = new CustomEvent('streaming-complete', {
        bubbles: false
      });
      this.mapElement.dispatchEvent(event);
    });

    this.handleEvent("clear_markers", () => {
      console.log('Bridge received clear markers');
      const event = new CustomEvent('clear-markers', {
        bubbles: false  
      });
      this.mapElement.dispatchEvent(event);
    });
  },

  // Decompress zlib compressed + base64 encoded data from server
  decompressData(compressedData) {
    try {
      if (typeof compressedData === 'string') {
        // Import compression libraries dynamically
        const pako = window.pako;
        const Base64 = window.Base64;
        
        if (pako && Base64) {
          // Full decompression with pako library
          const base64Decoded = Base64.atob(compressedData);
          const charCodes = [];
          for (let i = 0; i < base64Decoded.length; i++) {
            charCodes.push(base64Decoded.charCodeAt(i));
          }
          const inflatedData = pako.inflate(charCodes, { to: 'string' });
          return JSON.parse(inflatedData);
        } else {
          // Fallback: assume it's plain JSON
          return JSON.parse(compressedData);
        }
      }
      
      return compressedData;
    } catch (error) {
      console.error('Error decompressing data:', error);
      return [];
    }
  }
};

export default LeafletMapBridge;
