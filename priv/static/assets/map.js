let Map = {
    mounted(){
        const markers = {}
        var map = L.map('map', {keyboard: true}).setView([42.3736, -71.1097], 13);

        const view = this;
        var marker = L.centerMarker(map).on("newposition", function() {
            var latlng = marker.getLatLng()
            console.log("New position: " + latlng.lat + ", " + latlng.lng);
            view.pushEvent("foofofo")
            document.getElementById("foci-form").dispatchEvent(
                new Event("map-update", {latlng: latlng})
            )

        });;
        marker.addTo(map);

        L.tileLayer('https:{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https:openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }).addTo(map);

        this.handleEvent("add_marker", ({lat, lon}) => {
            const marker = L.marker(L.latLng(lat, lon))
            marker.addTo(map)
        })
    }
}

export {Map}