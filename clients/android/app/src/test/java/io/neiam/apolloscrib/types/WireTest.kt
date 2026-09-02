package io.neiam.apolloscrib.types

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
