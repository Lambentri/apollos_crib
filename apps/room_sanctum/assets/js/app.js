// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import "@fortawesome/fontawesome-free/js/all"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// import './leaflet/leaflet-map'
// import './leaflet/leaflet-marker'
// import './leaflet/leaflet-icon'

import L from 'leaflet'
import 'leaflet-centermarker'
import LeafletMap from './hooks/leaflet_map.js'

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {};

// Add our new LeafletMap hook
Hooks.LeafletMap = LeafletMap;
Hooks.MapPush = {
    mounted() {
        window.addEventListener("focus", e => {

            this.pushEvent("load-more", {})

        })
    },
}
Hooks.mkMap = {
    mounted() {
        const markers = {}
        let searchMarker = null;

        let latlng = document.getElementById('map').getAttribute('data-latlng')
        if (latlng != null) {
            let coords = JSON.parse(latlng)
        } else {
            let coords = [42.3736, -71.1097]
        }

        var map = L.map('map', {keyboard: true}).setView(coords, 13);

        const view = this;
        var centerMarker = L.centerMarker(map).on("newposition", function() {
            var latlng = centerMarker.getLatLng()
            console.log("New position: " + latlng.lat + ", " + latlng.lng);
            view.pushEventTo("#foci-form", "map-update", { latlng: latlng });
        });
        centerMarker.addTo(map);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }).addTo(map);

        // Search functionality
        const searchInput = document.getElementById('location-search');
        const searchResults = document.getElementById('search-results');
        let searchTimeout;

        const performSearch = async (query) => {
            if (query.length < 3) {
                searchResults.classList.add('hidden');
                return;
            }

            try {
                const response = await fetch(
                    `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&addressdetails=1`
                );
                const results = await response.json();

                displaySearchResults(results);
            } catch (error) {
                console.error('Search error:', error);
                searchResults.classList.add('hidden');
            }
        };

        const displaySearchResults = (results) => {
            searchResults.innerHTML = '';

            if (results.length === 0) {
                searchResults.innerHTML = '<div class="p-3 text-gray-500">No results found</div>';
                searchResults.classList.remove('hidden');
                return;
            }

            results.forEach(result => {
                const resultDiv = document.createElement('div');
                resultDiv.className = 'p-3 hover:bg-gray-100 cursor-pointer border-b border-gray-200 last:border-b-0';
                resultDiv.innerHTML = `
                    <div class="font-medium">${result.display_name}</div>
                    <div class="text-sm text-gray-600">${result.type} • ${result.class}</div>
                `;

                resultDiv.addEventListener('click', () => {
                    selectSearchResult(result);
                });

                searchResults.appendChild(resultDiv);
            });

            searchResults.classList.remove('hidden');
        };

        const selectSearchResult = (result) => {
            const lat = parseFloat(result.lat);
            const lon = parseFloat(result.lon);

            // Update search input
            searchInput.value = result.display_name;
            searchResults.classList.add('hidden');

            // Remove previous search marker
            if (searchMarker) {
                map.removeLayer(searchMarker);
            }

            // Add new search marker
            searchMarker = L.marker([lat, lon], {
                icon: L.icon({
                    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-red.png',
                    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
                    iconSize: [25, 41],
                    iconAnchor: [12, 41],
                    popupAnchor: [1, -34],
                    shadowSize: [41, 41]
                })
            }).addTo(map);

            // Add popup with result info
            searchMarker.bindPopup(`
                <div>
                    <strong>${result.display_name}</strong><br>
                    <small>${result.type} • ${result.class}</small><br>
                    <button onclick="window.selectThisLocation(${lat}, ${lon})" class="btn btn-sm btn-primary mt-2">
                        Select This Location
                    </button>
                </div>
            `).openPopup();

            // Pan to the result
            map.setView([lat, lon], 16);
        };

        // Global function to select a location from popup
        window.selectThisLocation = (lat, lon) => {
            // Move center marker to selected location
            centerMarker.setLatLng([lat, lon]);
            map.setView([lat, lon], 16);

            // Trigger the position update
            view.pushEventTo("#foci-form", "map-update", {latlng: {lat: lat, lng: lon}});

            // Close popup
            if (searchMarker) {
                searchMarker.closePopup();
            }
        };

        // Search input event listeners
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                clearTimeout(searchTimeout);
                const query = e.target.value.trim();

                if (query.length === 0) {
                    searchResults.classList.add('hidden');
                    return;
                }

                searchTimeout = setTimeout(() => {
                    performSearch(query);
                }, 300);
            });

            // Hide search results when clicking outside
            document.addEventListener('click', (e) => {
                if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
                    searchResults.classList.add('hidden');
                }
            });

            // Show search results when focusing on input
            searchInput.addEventListener('focus', () => {
                if (searchInput.value.trim().length >= 3) {
                    performSearch(searchInput.value.trim());
                }
            });
        }

        this.handleEvent("add_marker", ({lat, lon}) => {
            const marker = L.marker(L.latLng(lat, lon))
            marker.addTo(map)
        })
    }
}

Hooks.mkTesterMap = {
    latlng() { return this.el.dataset.latlng },
    mounted() {
        var latlng = this.latlng()
        console.log("MOUNTEd")
        console.log(latlng)
        if (latlng == null) {
            let map = L.map('map', {keyboard: true}).setView([42.3736, -71.1097], 13);
        } else {
            let map = L.map("map", { keyboard: true }).setView(JSON.parse(this.latlng()), 13);
        }
        const markers = {}

        const view = this;
        // var marker = L.centerMarker(map).on("newposition", function() {
        //     var latlng = marker.getLatLng()
        //     console.log("New position: " + latlng.lat + ", " + latlng.lng);
        //     view.pushEventTo("#foci-form", "map-update", {latlng: latlng})
        //
        // });
        // marker.addTo(map);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https//:openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }).addTo(map);

        this.handleEvent("add_marker", ({lat, lon}) => {
            const marker = L.marker(L.latLng(lat, lon))
            marker.addTo(map)
        })
    }
}

Hooks.mkShowMap = {
    latlng() { return this.el.dataset.latlng },
    mounted() {
        var latlng = this.latlng()
        console.log("Show Map Mounted")
        console.log(latlng)

        let coords;
        if (latlng == null) {
            coords = [42.3736, -71.1097];
        } else {
            coords = JSON.parse(latlng);
        }

        // Create static map for show view with unique ID
        let map = L.map(this.el.id, {
            keyboard: false,
            dragging: false,
            touchZoom: false,
            scrollWheelZoom: false,
            doubleClickZoom: false,
            boxZoom: false,
            tap: false
        }).setView(coords, 15);

        // Add a marker at the location if coordinates exist
        if (latlng != null) {
            L.marker(coords).addTo(map);
        }

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }).addTo(map);
    }
}

let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#b57979"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Handle file downloads
window.addEventListener("phx:download", (event) => {
  const { data, filename, mime_type } = event.detail;
  const blob = new Blob([data], { type: mime_type });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  window.URL.revokeObjectURL(url);
  document.body.removeChild(a);
});

// Handle file uploads
window.addEventListener("phx:upload_file", (event) => {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".json";
  input.addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const fileData = e.target.result;
        liveSocket.pushEvent("process-import", { file_data: fileData });
      };
      reader.readAsText(file);
    }
  });
  input.click();
});

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

