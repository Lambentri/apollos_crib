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

import './leaflet/leaflet-map'
import './leaflet/leaflet-marker'
import './leaflet/leaflet-icon'

import L from 'leaflet'
import 'leaflet-centermarker'

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {};
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
        latlng = document.getElementById('map').getAttribute('data-latlng')
        if (latlng != null) {
            coords = JSON.parse(latlng)
        } else {
            coords = [42.3736, -71.1097]
        }
        coords = [18.33967, -67.23713]
        var map = L.map('map', {keyboard: true}).setView(coords, 13);

        const view = this;
        var marker = L.centerMarker(map).on("newposition", function() {
            var latlng = marker.getLatLng()
            console.log("New position: " + latlng.lat + ", " + latlng.lng);
            view.pushEventTo("#foci-form", "map-update", { latlng: latlng });

        });;
        marker.addTo(map);

        L.tileLayer('https:{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https:openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }).addTo(map);

        this.handleEvent("add_marker", ({lat, lon}) => {
            const marker = L.marker(L.latLng(lat, lomn))
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

let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#b57979"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

