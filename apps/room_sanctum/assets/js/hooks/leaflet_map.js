/**
 * Leaflet Map Hook for Phoenix LiveView
 * Displays queries with geospatial data and real-time vehicle positions on an interactive map
 * Optimized for handling thousands of markers with Canvas renderer and data compression
 */

const LeafletMap = {
  mounted() {
    this.isInitialized = false;
    this.isInitializing = false;
    this.isUpdating = false;
    this.vehicleMarkers = new Map(); // Track vehicle markers for smooth updates
    
    // Initialize canvas renderer for performance
    this.canvasRenderer = L.canvas({ padding: 0.5 });
    
    // Ensure the container has proper dimensions before initializing
    setTimeout(() => {
      this.initializeMap();
      this.updateMarkers();
    }, 100);
    
    // Add event handlers for streaming data
    this.setupStreamHandlers();
  },

  updated() {
    // Only update if map is already initialized and we're not currently initializing
    if (this.map && this.isInitialized && !this.isUpdating) {
      // Debounce updates to prevent flashing
      if (this.updateTimeout) {
        clearTimeout(this.updateTimeout);
      }
      this.updateTimeout = setTimeout(() => {
        this.isUpdating = true;
        this.map.invalidateSize();
        this.updateMarkers();
        this.isUpdating = false;
      }, 150);
    } else if (!this.map && !this.isInitializing) {
      // Only initialize if we don't already have a map and aren't currently initializing
      this.isInitializing = true;
      setTimeout(() => {
        this.initializeMap();
        this.updateMarkers();
        this.isInitializing = false;
      }, 100);
    }
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  },

  initializeMap() {
    // Only clear if we don't already have a map instance
    if (this.map) {
      console.log('Map already exists, removing...');
      this.map.remove();
      this.map = null;
    }
    
    // Clean up any existing map containers to prevent duplicates
    const existingMapContainers = this.el.querySelectorAll('.leaflet-map-container');
    existingMapContainers.forEach(container => container.remove());
    
    // Create a dedicated map container div  
    const mapContainer = document.createElement('div');
    mapContainer.className = 'leaflet-map-container';
    mapContainer.style.cssText = 'width: 100%; height: 100%; position: absolute; top: 0; left: 0; z-index: 10;';
    
    // Hide the loading state by setting it behind the map
    const loadingDiv = this.el.querySelector('.flex.items-center.justify-center');
    if (loadingDiv) {
      loadingDiv.style.zIndex = '1';
    }
    
    // Add the map container on top
    this.el.appendChild(mapContainer);
    
    // Initialize the Leaflet map in the new container
    this.map = L.map(mapContainer, {
      center: [39.8283, -98.5795], // Center of USA as default
      zoom: 4,
      zoomControl: true,
      scrollWheelZoom: true
    });

    // Add OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 18
    }).addTo(this.map);

    // Initialize separate layer groups for queries, vehicles, free bikes, and stations
    this.queriesLayer = L.layerGroup().addTo(this.map);
    this.vehiclesLayer = L.layerGroup().addTo(this.map);
    this.freeBikesLayer = L.layerGroup().addTo(this.map);
    this.stationsLayer = L.layerGroup().addTo(this.map);
    
    // Mark as initialized
    this.isInitialized = true;
    
    console.log('Map initialized successfully');
  },

  updateMarkers() {
    // Skip if map isn't properly initialized
    if (!this.map || !this.isInitialized || !this.queriesLayer || !this.vehiclesLayer || !this.freeBikesLayer || !this.stationsLayer) {
      console.log('Skipping updateMarkers - map not ready');
      return;
    }

    // Prevent concurrent updates that can cause flashing
    if (this.isUpdating) {
      console.log('Already updating markers, skipping...');
      return;
    }

    this.isUpdating = true;

    // Get data from data attributes with error handling
    let queriesData, vehiclesData, freeBikesData, stationsData, selectedTint, useStreaming;
    try {
      queriesData = JSON.parse(this.el.dataset.queries || '[]');
      vehiclesData = JSON.parse(this.el.dataset.vehicles || '[]');
      freeBikesData = JSON.parse(this.el.dataset.freeBikes || '[]');
      stationsData = JSON.parse(this.el.dataset.stations || '[]');
      selectedTint = this.el.dataset.selectedTint;
      useStreaming = this.el.dataset.useStreaming === "true";
    } catch (e) {
      console.error('Error parsing map data:', e);
      this.isUpdating = false;
      return;
    }

    console.log('updateMarkers called with:', {
      queries: queriesData.length,
      vehicles: vehiclesData.length,
      freeBikes: freeBikesData.length,
      stations: stationsData.length,
      selectedTint,
      useStreaming
    });

    // Only update query markers from data attributes if not using streaming
    // When streaming is enabled, query markers are added via streaming events
    if (!useStreaming && queriesData.length > 0) {
      this.updateQueryMarkers(queriesData, selectedTint);
    } else if (useStreaming) {
      console.log('Query markers will be added via streaming events');
    }
    
    // Always update vehicle markers (these aren't streamed)
    this.updateVehicleMarkers(vehiclesData);
    
    // Always update free bike markers (these aren't streamed)  
    this.updateFreeBikeMarkers(freeBikesData);
    
    // Always update station markers (these aren't streamed)
    this.updateStationMarkers(stationsData);

    this.isUpdating = false;
  },

  updateQueryMarkers(queriesData, selectedTint) {
    // Clear existing query markers first
    if (this.queriesLayer) {
      // Store current map state before clearing
      const currentCenter = this.map.getCenter();
      const currentZoom = this.map.getZoom();
      
      console.log('Clearing', this.queriesLayer.getLayers().length, 'query markers');
      this.queriesLayer.clearLayers();
    }

    if (queriesData.length === 0) {
      console.log('No queries data found');
      return;
    }

    // Filter queries by selected tint if specified
    const filteredQueries = selectedTint ? 
      queriesData.filter(q => q.tint === selectedTint) : 
      queriesData;

    console.log('filteredQueries:', filteredQueries.length);

    // Create bounds for auto-fitting the map
    const group = new L.featureGroup();

    // Add markers for each query
    filteredQueries.forEach(query => {
      if (query.lat && query.lng && query.lat !== 0 && query.lng !== 0) {
        const marker = this.createQueryMarker(query);
        this.queriesLayer.addLayer(marker);
        group.addLayer(marker);
      }
    });

    console.log('Query markers created:', group.getLayers().length);

    // Fit map to show all markers if we have any (and no vehicles to also consider)
    const vehiclesData = JSON.parse(this.el.dataset.vehicles || '[]');
    const hasVehicles = vehiclesData.length > 0;
    
    if (group.getLayers().length > 0 && !hasVehicles) {
      try {
        this.map.fitBounds(group.getBounds(), {
          padding: [20, 20],
          maxZoom: 15
        });
      } catch (e) {
        console.warn('Error fitting map bounds:', e);
      }
    }
  },

  updateVehicleMarkers(vehiclesData) {
    if (vehiclesData.length === 0) {
      // Clear all vehicle markers if no vehicles
      // Store current map state before clearing
      const currentCenter = this.map.getCenter();
      const currentZoom = this.map.getZoom();
      
      console.log('Clearing', this.vehiclesLayer.getLayers().length, 'vehicle markers');
      this.vehiclesLayer.clearLayers();
      this.vehicleMarkers.clear();
      return;
    }

    console.log('Updating vehicle markers:', vehiclesData.length);

    // Keep track of current vehicle IDs
    const currentVehicleIds = new Set(vehiclesData.map(v => v.id));
    
    // Remove markers for vehicles that no longer exist
    for (const [vehicleId, marker] of this.vehicleMarkers.entries()) {
      if (!currentVehicleIds.has(vehicleId)) {
        this.vehiclesLayer.removeLayer(marker);
        this.vehicleMarkers.delete(vehicleId);
      }
    }

    // Create bounds that include both queries and vehicles
    const allMarkers = new L.featureGroup();
    
    // Add existing query markers to bounds
    this.queriesLayer.eachLayer(layer => allMarkers.addLayer(layer));

    // Update or create vehicle markers
    vehiclesData.forEach(vehicle => {
      if (vehicle.lat && vehicle.lng) {
        const existingMarker = this.vehicleMarkers.get(vehicle.id);
        
        if (existingMarker) {
          // Update existing marker position with smooth animation
          this.animateVehicleMarker(existingMarker, vehicle);
        } else {
          // Create new marker
          const newMarker = this.createVehicleMarker(vehicle);
          this.vehiclesLayer.addLayer(newMarker);
          this.vehicleMarkers.set(vehicle.id, newMarker);
        }
        
        // Add to bounds group
        const markerToAdd = this.vehicleMarkers.get(vehicle.id);
        if (markerToAdd) {
          allMarkers.addLayer(markerToAdd);
        }
      }
    });

    // Fit map to show all markers (queries + vehicles) on first load
    if (allMarkers.getLayers().length > 0 && !this.hasSetInitialBounds) {
      this.map.fitBounds(allMarkers.getBounds(), {
        padding: [20, 20],
        maxZoom: 15
      });
      this.hasSetInitialBounds = true;
    }
  },

  updateFreeBikeMarkers(freeBikesData) {
    // Clear existing free bike markers
    if (this.freeBikesLayer) {
      // Store current map state before clearing  
      const currentCenter = this.map.getCenter();
      const currentZoom = this.map.getZoom();
      
      console.log('Clearing', this.freeBikesLayer.getLayers().length, 'free bike markers');
      this.freeBikesLayer.clearLayers();
    }

    if (freeBikesData.length === 0) {
      console.log('No free bikes data found');
      return;
    }

    console.log('Updating free bike markers:', freeBikesData.length);

    // Create bounds that include queries, vehicles, and free bikes
    const allMarkers = new L.featureGroup();
    
    // Add existing query and vehicle markers to bounds
    this.queriesLayer.eachLayer(layer => allMarkers.addLayer(layer));
    this.vehiclesLayer.eachLayer(layer => allMarkers.addLayer(layer));

    // Add markers for each free bike
    freeBikesData.forEach(bike => {
      if (bike.lat && bike.lng && bike.lat !== 0 && bike.lng !== 0) {
        const marker = this.createFreeBikeMarker(bike);
        this.freeBikesLayer.addLayer(marker);
        allMarkers.addLayer(marker);
      }
    });

    console.log('Free bike markers created:', freeBikesData.length);

    // Fit map to show all markers (queries + vehicles + bikes) on first load
    if (allMarkers.getLayers().length > 0 && !this.hasSetInitialBounds) {
      this.map.fitBounds(allMarkers.getBounds(), {
        padding: [20, 20],
        maxZoom: 15
      });
      this.hasSetInitialBounds = true;
    }
  },

  updateStationMarkers(stationsData) {
    // Clear existing station markers
    if (this.stationsLayer) {
      // Store current map state before clearing
      const currentCenter = this.map.getCenter();
      const currentZoom = this.map.getZoom();
      
      console.log('Clearing', this.stationsLayer.getLayers().length, 'station markers');
      this.stationsLayer.clearLayers();
    }

    if (stationsData.length === 0) {
      console.log('No stations data found');
      return;
    }

    console.log('Updating station markers:', stationsData.length);

    // Create bounds that include all markers
    const allMarkers = new L.featureGroup();
    
    // Add existing markers to bounds
    this.queriesLayer.eachLayer(layer => allMarkers.addLayer(layer));
    this.vehiclesLayer.eachLayer(layer => allMarkers.addLayer(layer));
    this.freeBikesLayer.eachLayer(layer => allMarkers.addLayer(layer));

    // Add markers for each station
    stationsData.forEach(station => {
      if (station.lat && station.lng && station.lat !== 0 && station.lng !== 0) {
        const marker = this.createStationMarker(station);
        this.stationsLayer.addLayer(marker);
        allMarkers.addLayer(marker);
      }
    });

    console.log('Station markers created:', stationsData.length);

    // Fit map to show all markers on first load
    if (allMarkers.getLayers().length > 0 && !this.hasSetInitialBounds) {
      this.map.fitBounds(allMarkers.getBounds(), {
        padding: [20, 20],
        maxZoom: 15
      });
      this.hasSetInitialBounds = true;
    }
  },

  animateVehicleMarker(marker, vehicle) {
    // Smooth transition to new position
    const currentPos = marker.getLatLng();
    const newPos = L.latLng(vehicle.lat, vehicle.lng);
    
    // Only animate if position actually changed
    if (currentPos.lat !== newPos.lat || currentPos.lng !== newPos.lng) {
      // Use Leaflet's built-in smooth panning
      marker.setLatLng(newPos);
      
      // Update bearing/rotation if provided
      if (vehicle.bearing !== null && vehicle.bearing !== undefined) {
        this.updateVehicleBearing(marker, vehicle.bearing);
      }
      
      // Update popup content with latest data
      const popupContent = this.createVehiclePopupContent(vehicle);
      marker.getPopup().setContent(popupContent);
    }
  },

  updateVehicleBearing(marker, bearing) {
    // Rotate the vehicle icon to show direction
    const iconElement = marker.getElement();
    if (iconElement) {
      const vehicleIcon = iconElement.querySelector('.vehicle-icon');
      if (vehicleIcon) {
        vehicleIcon.style.transform = `rotate(${bearing}deg)`;
      }
    }
  },

  createQueryMarker(query) {
    // Create custom icon based on source type and tint
    const icon = this.createCustomIcon(query);
    
    // Create marker
    const marker = L.marker([query.lat, query.lng], { icon });

    // Create popup content
    const popupContent = this.createPopupContent(query);
    marker.bindPopup(popupContent);

    // Add event listener for the duplicate query button after popup opens
    marker.on('popupopen', (e) => {
      const popup = e.popup;
      const duplicateQueryBtn = popup.getElement().querySelector('.duplicate-query-btn');
      if (duplicateQueryBtn) {
        duplicateQueryBtn.addEventListener('click', () => {
          this.pushEvent('add-query-from-map', {
            station_id: query.id.toString(),
            name: query.name,
            type: 'query'
          });
        });
      }
    });

    // Add click handler for query navigation
    marker.on('click', () => {
      // You can emit events back to LiveView if needed
      // this.pushEvent('marker_clicked', { query_id: query.id });
    });

    return marker;
  },

  createVehicleMarker(vehicle) {
    // Create custom vehicle icon
    const icon = this.createVehicleIcon(vehicle);
    
    // Create marker
    const marker = L.marker([vehicle.lat, vehicle.lng], { icon });

    // Create popup content
    const popupContent = this.createVehiclePopupContent(vehicle);
    marker.bindPopup(popupContent);

    // Add event listener for vehicle query button after popup opens (if it's a GTFS vehicle)
    marker.on('popupopen', (e) => {
      const popup = e.popup;
      const addVehicleQueryBtn = popup.getElement().querySelector('.add-vehicle-query-btn');
      if (addVehicleQueryBtn) {
        addVehicleQueryBtn.addEventListener('click', () => {
          this.pushEvent('add-query-from-map', {
            station_id: vehicle.vehicle_id,
            name: `Vehicle ${vehicle.vehicle_id} Position Query`,
            type: 'vehicle'
          });
        });
      }
    });

    return marker;
  },

  createFreeBikeMarker(bike) {
    // Create custom free bike icon
    const icon = this.createFreeBikeIcon(bike);
    
    // Create marker
    const marker = L.marker([bike.lat, bike.lng], { icon });

    // Create popup content
    const popupContent = this.createFreeBikePopupContent(bike);
    marker.bindPopup(popupContent);

    // Add event listener for the add query button after popup opens
    marker.on('popupopen', (e) => {
      const popup = e.popup;
      const addQueryBtn = popup.getElement().querySelector('.add-area-query-btn');
      if (addQueryBtn) {
        addQueryBtn.addEventListener('click', () => {
          this.pushEvent('add-query-from-map', {
            station_id: bike.bike_id,
            name: 'Free Bike Area Query',
            type: 'area'
          });
        });
      }
    });

    return marker;
  },
  
  createStationMarker(station) {
    // Create custom station icon
    const icon = this.createStationIcon(station);
    
    // Create marker
    const marker = L.marker([station.lat, station.lng], { icon });

    // Create popup content
    const popupContent = this.createStationPopupContent(station);
    marker.bindPopup(popupContent);

    // Add event listener for the add query button after popup opens
    marker.on('popupopen', (e) => {
      const popup = e.popup;
      const addQueryBtn = popup.getElement().querySelector('.add-query-btn');
      if (addQueryBtn) {
        addQueryBtn.addEventListener('click', () => {
          this.pushEvent('add-query-from-map', {
            station_id: station.station_id,
            name: station.name || 'Station',
            type: 'station'
          });
        });
      }
    });

    return marker;
  },

  createVehicleIcon(vehicle) {
    // Use orange/red colors for vehicles to distinguish from query markers
    const vehicleColor = '#FF6B35'; // Orange-red for vehicles
    const bearing = vehicle.bearing || 0;
    
    // Create HTML for the vehicle icon with rotation
    const iconHtml = `
      <div class="vehicle-marker" style="
        background-color: ${vehicleColor};
        width: 32px;
        height: 32px;
        border-radius: 8px;
        border: 2px solid white;
        box-shadow: 0 2px 6px rgba(0,0,0,0.4);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 14px;
        position: relative;
        transform: rotate(${bearing}deg);
        transition: transform 0.3s ease;
      ">
        <i class="fas ${vehicle.icon} vehicle-icon" style="transform: rotate(${-bearing}deg);"></i>
        <div style="
          position: absolute;
          top: -2px;
          right: -2px;
          width: 8px;
          height: 8px;
          background: #22c55e;
          border-radius: 50%;
          border: 1px solid white;
        "></div>
      </div>
    `;

    return L.divIcon({
      html: iconHtml,
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -16],
      className: 'custom-vehicle-icon'
    });
  },

  createVehiclePopupContent(vehicle) {
    const timestamp = vehicle.timestamp ? 
      new Date(vehicle.timestamp * 1000).toLocaleTimeString() : 'Unknown';

    return `
      <div class="p-2 min-w-48">
        <div class="flex items-center gap-2 mb-2">
          <i class="fas ${vehicle.icon} text-orange-600"></i>
          <h3 class="font-semibold text-sm">Vehicle ${vehicle.vehicle_id}</h3>
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
            <div class="w-2 h-2 bg-green-400 rounded-full mr-1"></div>
            Live
          </span>
        </div>
        
        ${vehicle.trip_id ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Trip:</strong> ${vehicle.trip_id}
          </div>
        ` : ''}
        
        ${vehicle.route_id ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Route:</strong> ${vehicle.route_id}
          </div>
        ` : ''}
        
        <div class="text-xs text-gray-600 mb-1">
          <strong>Last Update:</strong> ${timestamp}
        </div>
        
        ${vehicle.bearing !== null && vehicle.bearing !== undefined ? `
          <div class="text-xs text-gray-600 mb-2">
            <strong>Heading:</strong> ${Math.round(vehicle.bearing)}°
          </div>
        ` : ''}
        
        <div class="text-xs text-gray-500 mb-2">
          <i class="fa-solid fa-location-dot mr-1"></i>
          ${vehicle.lat.toFixed(4)}, ${vehicle.lng.toFixed(4)}
        </div>
        
        <div class="flex justify-center mt-2">
          <button 
            class="add-vehicle-query-btn btn btn-sm btn-primary text-xs px-3 py-1 rounded-md bg-orange-600 hover:bg-orange-700 text-white transition-colors"
            data-vehicle-id="${vehicle.vehicle_id}"
            data-query-type="vehicle"
            title="Create a vehicle position query for this vehicle"
          >
            <i class="fa-solid fa-plus mr-1"></i>
            Add Vehicle Query
          </button>
        </div>
      </div>
    `;
  },

  createCustomIcon(query) {
    // Get color based on tint or default
    const tintColor = query.tint ? this.getTintColor(query.tint) : '#6B7280';
    
    // Create HTML for the icon
    const iconHtml = `
      <div class="custom-marker" style="
        background-color: ${tintColor};
        width: 30px;
        height: 30px;
        border-radius: 50%;
        border: 3px solid white;
        box-shadow: 0 2px 4px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 12px;
      ">
        <i class="fas ${query.icon}"></i>
      </div>
    `;

    return L.divIcon({
      html: iconHtml,
      iconSize: [30, 30],
      iconAnchor: [15, 15],
      popupAnchor: [0, -15],
      className: 'custom-div-icon'
    });
  },

  createFreeBikeIcon(bike) {
    // Use green colors for available bikes, yellow for reserved, gray for disabled
    let bikeColor = '#22C55E'; // Green for available
    if (bike.is_disabled) {
      bikeColor = '#6B7280'; // Gray for disabled
    } else if (bike.is_reserved) {
      bikeColor = '#F59E0B'; // Yellow for reserved
    }
    
    // Create battery indicator if battery info is available
    const batteryIndicator = bike.battery_icon && bike.battery_color ? `
      <div style="
        position: absolute;
        top: -4px;
        right: -4px;
        width: 12px;
        height: 12px;
        background: white;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 1px 2px rgba(0,0,0,0.2);
      ">
        <i class="fas ${bike.battery_icon}" style="
          font-size: 6px;
          color: ${bike.battery_color};
        "></i>
      </div>
    ` : '';

    // Create status indicator for disabled/reserved
    const statusIndicator = (bike.is_disabled || bike.is_reserved) ? `
      <div style="
        position: absolute;
        bottom: -2px;
        right: -2px;
        width: 8px;
        height: 8px;
        background: ${bike.is_disabled ? '#EF4444' : '#F59E0B'};
        border-radius: 50%;
        border: 1px solid white;
        box-shadow: 0 1px 2px rgba(0,0,0,0.2);
      "></div>
    ` : '';
    
    // Create HTML for the bike icon
    const iconHtml = `
      <div class="bike-marker" style="
        background-color: ${bikeColor};
        width: 20px;
        height: 20px;
        border-radius: 50%;
        border: 2px solid white;
        box-shadow: 0 2px 4px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 8px;
        position: relative;
      ">
        <i class="fas ${bike.icon}"></i>
        ${batteryIndicator}
        ${statusIndicator}
      </div>
    `;

    return L.divIcon({
      html: iconHtml,
      iconSize: [20, 20],
      iconAnchor: [10, 10],
      popupAnchor: [0, -10],
      className: 'custom-bike-icon'
    });
  },

  createFreeBikePopupContent(bike) {
    const statusBadge = bike.is_disabled ? 
      '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">Disabled</span>' :
      bike.is_reserved ? 
      '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">Reserved</span>' :
      '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">Available</span>';

    // Create battery display if available
    const batteryDisplay = bike.battery_level !== null && bike.battery_level !== undefined ? `
      <div class="text-xs text-gray-600 mb-1">
        <i class="fas ${bike.battery_icon}" style="color: ${bike.battery_color};"></i>
        <strong>Battery:</strong> ${bike.battery_level.toFixed(1)}%
      </div>
    ` : '';

    return `
      <div class="p-2 min-w-48">
        <div class="flex items-center gap-2 mb-2">
          <i class="fas ${bike.icon} text-green-600"></i>
          <h3 class="font-semibold text-sm">Bike ${bike.bike_id}</h3>
          ${statusBadge}
        </div>
        
        ${bike.vehicle_type_id ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Type:</strong> ${bike.vehicle_type_id}
          </div>
        ` : ''}
        
        ${batteryDisplay}
        
        ${bike.current_range_meters ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Range:</strong> ${bike.current_range_meters}m
          </div>
        ` : ''}
        
        <div class="text-xs text-gray-500 mb-2">
          <i class="fa-solid fa-location-dot mr-1"></i>
          ${bike.lat.toFixed(4)}, ${bike.lng.toFixed(4)}
        </div>
        
        <div class="flex justify-center mt-2">
          <button 
            class="add-area-query-btn btn btn-sm btn-secondary text-xs px-3 py-1 rounded-md bg-green-600 hover:bg-green-700 text-white transition-colors"
            data-bike-id="${bike.bike_id}"
            data-query-type="area"
            title="Create an area query around this bike location"
          >
            <i class="fa-solid fa-plus mr-1"></i>
            Add Area Query
          </button>
        </div>
      </div>
    `;
  },

  createStationIcon(station) {
    // Get the tint color for the station
    const tintColor = station.tint ? this.getTintColor(station.tint) : '#4338ca';
    
    const iconHtml = `
      <div style="
        width: 26px;
        height: 26px;
        border-radius: 50%;
        background-color: ${tintColor};
        border: 2px solid #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.2);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 12px;
        position: relative;
      ">
        <i class="fas fa-bicycle"></i>
      </div>
    `;

    return L.divIcon({
      html: iconHtml,
      iconSize: [26, 26],
      iconAnchor: [13, 13],
      popupAnchor: [0, -13],
      className: 'custom-station-icon'
    });
  },

  createStationPopupContent(station) {
    return `
      <div class="p-2 min-w-48">
        <div class="flex items-center gap-2 mb-2">
          <i class="fas fa-bicycle text-indigo-600"></i>
          <h3 class="font-semibold text-sm">${station.name || 'Station'}</h3>
        </div>
        
        ${station.short_name ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>ID:</strong> ${station.short_name}
          </div>
        ` : ''}
        
        ${station.address ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Address:</strong> ${station.address}
          </div>
        ` : ''}
        
        ${station.capacity !== null && station.capacity !== undefined ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Capacity:</strong> ${station.capacity} bikes
          </div>
        ` : ''}
        
        ${station.num_bikes_available !== null && station.num_bikes_available !== undefined ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Regular Bikes Available:</strong> ${station.num_bikes_available}
          </div>
        ` : ''}
        
        ${station.num_ebikes_available !== null && station.num_ebikes_available !== undefined ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>E-bikes Available:</strong> ${station.num_ebikes_available}
          </div>
        ` : ''}
        
        ${station.num_docks_available !== null && station.num_docks_available !== undefined ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Docks Available:</strong> ${station.num_docks_available}
          </div>
        ` : ''}
        
        ${station.is_installed !== null && station.is_installed !== undefined ? `
          <div class="text-xs text-gray-600 mb-1">
            <strong>Status:</strong> ${station.is_installed ? 'Installed' : 'Not Installed'}
            ${station.is_renting !== null ? (station.is_renting ? ' • Renting' : ' • Not Renting') : ''}
            ${station.is_returning !== null ? (station.is_returning ? ' • Returning' : ' • Not Returning') : ''}
          </div>
        ` : ''}
        
        <div class="text-xs text-gray-500 mb-2">
          <i class="fa-solid fa-location-dot mr-1"></i>
          ${station.lat.toFixed(4)}, ${station.lng.toFixed(4)}
        </div>
        
        <div class="flex justify-center mt-2">
          <button 
            class="add-query-btn btn btn-sm btn-primary text-xs px-3 py-1 rounded-md bg-blue-600 hover:bg-blue-700 text-white transition-colors"
            data-station-id="${station.station_id}"
            data-station-name="${(station.name || 'Station').replace(/"/g, '&quot;')}"
            data-query-type="station"
          >
            <i class="fa-solid fa-plus mr-1"></i>
            Add Query
          </button>
        </div>
      </div>
    `;
  },

  createPopupContent(query) {
    const tintBadge = query.tint ? 
      `<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium" style="background-color: ${this.getTintColor(query.tint)}20; color: ${this.getTintColor(query.tint)};">
        <i class="fa-solid fa-circle mr-1" style="color: ${this.getTintColor(query.tint)};"></i>
        ${query.tint}
      </span>` : '';

    return `
      <div class="p-2 min-w-48">
        <div class="flex items-center gap-2 mb-2">
          <i class="fas ${query.icon} text-gray-600"></i>
          <h3 class="font-semibold text-sm">${query.name}</h3>
        </div>
        
        <div class="text-xs text-gray-600 mb-2">
          <strong>Source:</strong> ${query.source_name}
        </div>
        
        ${query.notes ? `
          <div class="text-xs text-gray-600 mb-2">
            <strong>Notes:</strong> ${query.notes}
          </div>
        ` : ''}
        
        ${tintBadge ? `
          <div class="mb-2">
            ${tintBadge}
          </div>
        ` : ''}
        
        <div class="text-xs text-gray-500 mb-2">
          <i class="fa-solid fa-location-dot mr-1"></i>
          ${query.lat.toFixed(4)}, ${query.lng.toFixed(4)}
        </div>
        
        <div class="flex justify-center mt-2">
          <button 
            class="duplicate-query-btn btn btn-sm btn-primary text-xs px-3 py-1 rounded-md bg-blue-600 hover:bg-blue-700 text-white transition-colors"
            data-query-id="${query.id}"
            data-query-name="${query.name.replace(/"/g, '&quot;')}"
            data-query-type="query"
          >
            <i class="fa-solid fa-plus mr-1"></i>
            Duplicate Query
          </button>
        </div>
      </div>
    `;
  },

  getTintColor(tint) {
    // Map tint names to colors - adjust based on your Tailwind color scheme
    const colorMap = {
      'amber': '#F59E0B',
      'lime': '#84CC16',
      'emerald': '#10B981',
      'sky': '#0EA5E9',
      'violet': '#8B5CF6',
      'fuchsia': '#D946EF',
      'rose': '#F43F5E',
      'stone': '#78716C',
      'slate': '#64748B',
      'red': '#EF4444',
      'orange': '#F97316',
      'yellow': '#EAB308',
      'green': '#22C55E',
      'teal': '#14B8A6',
      'cyan': '#06B6D4',
      'blue': '#3B82F6',
      'indigo': '#6366F1',
      'purple': '#A855F7',
      'pink': '#EC4899',
      'gray': '#6B7280'
    };
    
    return colorMap[tint] || '#6B7280';
  },

  // High-performance streaming data handlers
  setupStreamHandlers() {
    // Handle streaming marker data from server
    this.handleEvent("add_markers_batch", (data) => {
      this.addMarkersBatch(this.decompressData(data.compressed_data));
    });

    this.handleEvent("add_project", (project) => {
      this.addProjectMarker(project);
    });

    this.handleEvent("clear_markers", () => {
      this.clearAllMarkers();
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
  },

  // Optimized batch marker addition using canvas renderer
  addMarkersBatch(projects) {
    if (!this.map || !projects || projects.length === 0) {
      return;
    }

    console.log(`Adding ${projects.length} markers in batch`);
    
    // Use requestAnimationFrame to prevent UI blocking
    const addBatch = (startIndex) => {
      const batchSize = 100; // Process 100 markers at a time
      const endIndex = Math.min(startIndex + batchSize, projects.length);
      
      for (let i = startIndex; i < endIndex; i++) {
        const project = projects[i];
        if (project.lat && project.lng && project.lat !== 0 && project.lng !== 0) {
          this.addOptimizedMarker(project);
        }
      }
      
      // Continue with next batch if there are more markers
      if (endIndex < projects.length) {
        requestAnimationFrame(() => addBatch(endIndex));
      } else {
        console.log(`Finished adding ${projects.length} markers`);
      }
    };
    
    // Start the batch processing
    requestAnimationFrame(() => addBatch(0));
  },

  // Create high-performance marker using Canvas renderer
  addOptimizedMarker(project) {
    const marker = L.circleMarker(
      [project.lat, project.lng],
      {
        renderer: this.canvasRenderer,
        radius: 2,
        weight: 0,
        color: this.getTintColor(project.tint) || '#ef4444',
        fillColor: this.getTintColor(project.tint) || '#ef4444',
        fillOpacity: 0.8,
        fill: true,
      }
    ).addTo(this.queriesLayer);
    
    // Add popup if needed (but keep it lightweight)
    if (project.name) {
      marker.bindPopup(`
        <div class="p-2">
          <h4 class="font-semibold">${project.name}</h4>
          <p class="text-sm text-gray-600">${project.lat.toFixed(4)}, ${project.lng.toFixed(4)}</p>
        </div>
      `);
    }
    
    return marker;
  },

  // Add single project marker (for real-time streaming)
  addProjectMarker(project) {
    if (!this.map || !project.lat || !project.lng) {
      return;
    }
    
    this.addOptimizedMarker(project);
  },

  // Clear all markers for performance
  clearAllMarkers() {
    if (this.queriesLayer) {
      this.queriesLayer.clearLayers();
    }
    if (this.vehiclesLayer) {
      this.vehiclesLayer.clearLayers();
    }
    if (this.freeBikesLayer) {
      this.freeBikesLayer.clearLayers();
    }
    if (this.stationsLayer) {
      this.stationsLayer.clearLayers();
    }
    
    // Clear vehicle markers map
    this.vehicleMarkers.clear();
  },

  // Utility method to convert array data to object (for compressed data)
  objectifyProject(projectArray) {
    // Convert [name, source, type, lat, lng] to object
    // Adjust indices based on your data structure
    return {
      name: projectArray[0],
      source_name: projectArray[1], 
      type: projectArray[2],
      lat: projectArray[3],
      lng: projectArray[4]
    };
  }
};

export default LeafletMap;
