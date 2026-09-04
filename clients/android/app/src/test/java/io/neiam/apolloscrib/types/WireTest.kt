package io.neiam.apolloscrib.types

import io.neiam.apolloscrib.targets.Targets
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The wire samples here are the ones the apollos-types crate tests against,
 * which are themselves taken verbatim from what a Pythiae publishes. If these
 * two ever disagree, the crate is right.
 */
class WireTest {

    @Test
    fun `wrapped payload keeps the query name`() {
        val payload = """
            {"gtfs-12": {
              "data": [
                {"text_color": "#000000", "route_long": "Roslindale Square - Heath Street",
                 "route_name": "14", "route": "14", "color": "#FFC72C", "dest": "Heath St",
                 "times": ["08:00:00"], "dir": "Inbound", "mode": "Bus"}
              ],
              "query": {"name": "Forest Hills", "meta": {}}
            }}
        """.trimIndent()

        val entries = Wire.parse(payload)
        assertEquals(1, entries.size)
        val entry = entries.single()
        assertEquals(SourceType.Gtfs, entry.type)
        assertEquals("12", entry.queryId)
        assertEquals("Forest Hills", entry.label())

        val routes = entry.decode<List<GtfsCondensed>>()!!
        assertEquals("14", routes.single().displayName())
        assertEquals("#FFC72C", routes.single().color)
        assertNull(routes.single().times_live)
    }

    @Test
    fun `bare list is read as the legacy unwrapped shape`() {
        // What a publisher sends when it could not resolve the query.
        val payload = """
            {"gtfs-12": [{"route":"14","dest":"Heath St","dir":"Inbound","mode":"Bus","times":["08:00:00"]}]}
        """.trimIndent()

        val entry = Wire.parse(payload).single()
        assertEquals("Transit 12", entry.label())
        assertEquals(1, entry.decode<List<GtfsCondensed>>()!!.size)
    }

    @Test
    fun `a realtime estimate wins, and a missing one falls back to schedule`() {
        val route = GtfsCondensed(
            route = "14", dest = "Heath St", dir = "Inbound", mode = "Bus",
            times = listOf("08:00:00", "08:20:00", "08:40:00"),
            times_live = listOf("08:02:00", null, "08:41:00")
        )
        assertEquals(listOf("08:02:00", "08:20:00", "08:41:00"), route.departures())
    }

    @Test
    fun `an id with dashes in it survives the split`() {
        // A Plani that breaks its sources out keys an entry by source and
        // stop, and a GBFS station id is a UUID -- so the key has dashes well
        // past the one that separates the type.
        val payload = """
            {"gbfs-38:6cec3afa-554c-466f-8323-5c619fe0ddc6": {
              "query": {"name": "Packard Ave", "meta": {}},
              "data": [{"name":"Packard Ave","id":"1","avail":4,"docks_avail":9,
                        "capacity":13,"ebikes_info":[]}]
            }}
        """.trimIndent()

        val entry = Wire.parse(payload).single()

        assertEquals(SourceType.Gbfs, entry.type)
        assertEquals("38:6cec3afa-554c-466f-8323-5c619fe0ddc6", entry.queryId)
        assertEquals("Packard Ave", entry.label())
    }

    @Test
    fun `a stop broken out of a Plani reads as its own board`() {
        val payload = """
            {"gtfs-40:2378": {
              "query": {"name": "Boston Ave @ College Ave", "meta": {}},
              "data": [{"route":"96","dest":"Harvard","dir":"In","mode":"Bus",
                        "times":["08:00:00"]}]
            }}
        """.trimIndent()

        val entry = Wire.parse(payload).single()

        assertEquals(SourceType.Gtfs, entry.type)
        assertEquals("Boston Ave @ College Ave", entry.label())
    }

    @Test
    fun `a stop's bearing is separate from the route's direction`() {
        val payload = """
            {"gtfs-40:2378": {
              "query": {"name": "Boston Ave @ College Ave", "meta": {}},
              "data": [{"route":"96","dest":"Harvard","dir":"In","mode":"Bus",
                        "times":["08:00:00"],"bearing":"NE"}]
            }}
        """.trimIndent()

        val route = Wire.parse(payload).single().decode<List<GtfsCondensed>>()!!.single()

        // `dir` stays the feed's own inbound/outbound; the compass bearing is
        // its own field, because they are different things.
        assertEquals("In", route.dir)
        assertEquals("NE", route.bearing)
    }

    @Test
    fun `a source with no shape is dropped rather than failing the board`() {
        // `bourse` is published by apollos-crib but has no type in the
        // apollos-types crate, so this client does not claim to read it.
        val payload = """
            {"gtfs-12": [], "bourse-3": [{"anything": true}], "gbfs-7": []}
        """.trimIndent()

        val types = Wire.parse(payload).map { it.type }
        assertEquals(listOf(SourceType.Gtfs, SourceType.Gbfs), types)
        assertEquals(listOf("bourse"), Wire.unsupported(payload))
    }

    @Test
    fun `a dock and a loose bike are told apart by what came back`() {
        val payload = """
            {"gbfs-7": [
              {"name":"Main St","id":"1","avail":4,"avail_elec":1,"avail_std":3,
               "docks_avail":9,"docks_disabled":0,"capacity":13,"ebikes_info":[]},
              {"kind":"free_bike","name":"E-bike 4821","id":"b1","lat":42.3,"lon":-71.1,
               "fuel_pct":0.62,"reserved":false,"disabled":false}
            ]}
        """.trimIndent()

        val bikes = Wire.parse(payload).single().decode<List<GbfsCondensed>>()!!
        assertTrue(!bikes[0].isFreeBike())
        assertTrue(bikes[1].isFreeBike())
    }

    @Test
    fun `a car share is cars, not bikes`() {
        // Getaround Barcelona publishes 293 cars over GBFS. Nothing about the
        // format says bicycle.
        val payload = """
            {"gbfs-9": [
              {"kind":"free_bike","name":"Car","id":"YGA:Vehicle:59615e46d7db",
               "lat":41.379253,"lon":2.145276,"form_factor":"car"},
              {"kind":"free_bike","name":"Car","id":"YGA:Vehicle:4a0c7e18f6e1",
               "lat":41.38,"lon":2.14,"form_factor":"car"}
            ]}
        """.trimIndent()

        val entry = Wire.parse(payload).single()
        val rows = entry.decode<List<GbfsCondensed>>()!!

        assertEquals("car", rows[0].form_factor)

        // And what the card actually says, which is the point of carrying it.
        val preview = Targets.preview(entry).single()
        assertEquals("2 cars nearby", preview.subtitle)
    }

    @Test
    fun `a fleet of mixed kinds is described neutrally`() {
        val payload = """
            {"gbfs-9": [
              {"kind":"free_bike","name":"Car","id":"c1","form_factor":"car"},
              {"kind":"free_bike","name":"Bike","id":"b1","form_factor":"bicycle"}
            ]}
        """.trimIndent()

        // Being vague is recoverable; being confidently wrong is not.
        val preview = Targets.preview(Wire.parse(payload).single()).single()
        assertEquals("2 vehicles nearby", preview.subtitle)
    }

    @Test
    fun `a feed with no vehicle types still reads as bikes`() {
        // The overwhelming majority of GBFS feeds, and every one published
        // before this field existed. Saying "vehicles" here would make them
        // all read worse in exchange for nothing.
        val payload = """{"gbfs-9": [{"kind":"free_bike","name":"E-bike","id":"b1"}]}"""

        val preview = Targets.preview(Wire.parse(payload).single()).single()
        assertEquals("1 bike nearby", preview.subtitle)
    }

    @Test
    fun `a Plani stamps which way to walk, and a vision does not`() {
        val payload = """
            {"gbfs-7": [
              {"name":"Main St","id":"1","avail":4,"docks_avail":9,"capacity":13,
               "ebikes_info":[],"dir":"ENE"},
              {"kind":"free_bike","name":"E-bike 4821","id":"b1","lat":42.3,"lon":-71.1,
               "fuel_pct":0.62,"dir":"SW"},
              {"name":"No Direction","id":"2","avail":1,"docks_avail":2,"capacity":3,
               "ebikes_info":[]}
            ]}
        """.trimIndent()

        val rows = Wire.parse(payload).single().decode<List<GbfsCondensed>>()!!

        assertEquals("ENE", rows[0].dir)
        assertEquals("SW", rows[1].dir)
        // A vision leaves the key out entirely; so does a Plani for anything
        // close enough that "which way" has no answer.
        assertNull(rows[2].dir)
    }

    @Test
    fun `an unknown field from a newer publisher is ignored`() {
        val payload = """
            {"weather-4": {"data": [{"name":"Somerville","weather":"Clear","temp":21.5,
             "feel":20.9,"hum":44,"pressure":1016,"wind":{"speed":3.1,"deg":250},
             "units":"metric","something_new":42}], "query": {"name":"Home","meta":{}}}}
        """.trimIndent()

        val current = Wire.parse(payload).single().decode<List<WeatherCondensed>>()!!.single()
        assertEquals("Clear", current.weather)
        assertEquals("°C", current.degrees())
    }
}
