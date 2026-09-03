package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.Wire
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the renderers say, given what a Pythiae publishes.
 *
 * These are the strings on both the Smartspace card and the app's own board --
 * one description, drawn twice -- so they are worth pinning down.
 */
class RendererTest {

    private fun entry(payload: String) = Wire.parse(payload).single()

    @Test
    fun `a stop leads with what leaves first`() {
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": {"query": {"name": "Teele Sq", "meta": {}}, "data": [
                  {"route":"89","dest":"Sullivan","dir":"Inbound","mode":"Bus",
                   "times":["08:20:00","08:50:00"]},
                  {"route":"87","dest":"Lechmere","dir":"Inbound","mode":"Bus",
                   "times":["08:05:00","08:35:00"]}
                ]}}
                """.trimIndent()
            )
        )

        val board = previews.single()
        assertEquals("Teele Sq", board.title)
        // 87 leaves first, so it leads -- publisher order says nothing.
        assertEquals("87 at 08:05", board.subtitle)
        assertEquals(listOf("87 Lechmere 08:05 08:35", "89 Sullivan 08:20 08:50"), board.items)
        // A bus looks like a bus, and a scheduled time like a timetable.
        assertEquals(R.drawable.fa_bus, board.rows.first().iconRes)
        assertTrue(board.rows.first().stamps.all { it.iconRes == R.drawable.fa_clock })
    }

    @Test
    fun `a realtime estimate is said to be one`() {
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": [{"route":"87","dest":"Lechmere","dir":"In","mode":"Bus",
                 "times":["08:05:00"],"times_live":["08:07:00"]}]}
                """.trimIndent()
            )
        )
        val preview = previews.single()
        assertEquals("87 at 08:07 · live", preview.subtitle)
        // The tower is the claim that this came from the feed, not the timetable.
        assertEquals(
            listOf(R.drawable.fa_tower_broadcast),
            preview.rows.single().stamps.map { it.iconRes }
        )
    }

    @Test
    fun `a severe alert leads, ahead of departures that are not happening`() {
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": {"query": {"name": "Davis", "meta": {}}, "data": [
                  {"route":"RL","dest":"Alewife","dir":"NB","mode":"Subway","times":["08:05:00"],
                   "alerts":[{"effect":"NO_SERVICE","cause":"MAINTENANCE",
                              "header":"Red Line suspended","severity":"SEVERE"}]}
                ]}}
                """.trimIndent()
            )
        )

        assertEquals(2, previews.size)
        assertEquals("Red Line suspended", previews.first().title)
        assertEquals(Preview.Style.Basic, previews.first().style)
        assertEquals(R.drawable.fa_triangle_exclamation, previews.first().iconRes)
        // The board behind it is a subway, and says so.
        assertEquals(R.drawable.fa_train_subway, previews.last().iconRes)
    }

    @Test
    fun `a merely informational alert does not take the lead`() {
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": [{"route":"RL","dest":"Alewife","dir":"NB","mode":"Subway",
                 "times":["08:05:00"],
                 "alerts":[{"effect":"DETOUR","cause":"CONSTRUCTION","severity":"INFO"}]}]}
                """.trimIndent()
            )
        )
        assertEquals(1, previews.size)
    }

    @Test
    fun `an alert naming this stop leads even when the line is fine`() {
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": [{"route":"RL","dest":"Alewife","dir":"NB","mode":"Subway",
                 "times":["08:05:00"],
                 "alerts":[{"effect":"ESCALATOR_CLOSURE","cause":"MAINTENANCE",
                            "severity":"INFO","stop_specific":true}]}]}
                """.trimIndent()
            )
        )
        assertEquals(2, previews.size)
        assertEquals("Escalator closure", previews.first().title)
        // A pin rather than a warning triangle: this one is about the stop.
        assertEquals(R.drawable.fa_location_dot, previews.first().iconRes)
    }

    @Test
    fun `a stop with nothing due is not drawn at all`() {
        // A dock with no bikes still answers the question; an empty departure
        // board only says the window is quiet, and crowds out the stops that
        // have something.
        val previews = GtfsRenderer.preview(
            entry("""{"gtfs-1": {"query": {"name": "Curtis St", "meta": {}}, "data": []}}""")
        )
        assertTrue(previews.isEmpty())
    }

    @Test
    fun `an alert still shows when there is nothing due`() {
        // "Suspended" is why there is nothing due, and worth the space alone.
        val previews = GtfsRenderer.preview(
            entry(
                """
                {"gtfs-1": [{"route":"RL","dest":"Alewife","dir":"NB","mode":"Subway",
                 "times":[],
                 "alerts":[{"effect":"NO_SERVICE","cause":"MAINTENANCE",
                            "header":"Red Line suspended","severity":"SEVERE"}]}]}
                """.trimIndent()
            )
        )
        assertEquals("Red Line suspended", previews.single().title)
    }

    @Test
    fun `a dock counts bikes and docks, electric called out`() {
        val previews = GbfsRenderer.preview(
            entry(
                """
                {"gbfs-4": {"query": {"name": "Teele Square", "meta": {}}, "data": [
                  {"name":"Teele Square","id":"1","avail":8,"avail_elec":1,"avail_std":7,
                   "docks_avail":7,"docks_disabled":0,"capacity":15,"ebikes_info":[]}
                ]}}
                """.trimIndent()
            )
        )
        val card = previews.single()
        assertEquals("8 bikes · 1 electric", card.subtitle)
        // Bikes, e-bikes, docks -- each behind its own glyph, and still
        // readable where the glyphs cannot go.
        assertEquals(
            listOf(R.drawable.fa_bicycle, R.drawable.fa_bolt_lightning, R.drawable.fa_square_parking),
            card.rows.single().stamps.map { it.iconRes }
        )
        assertEquals(listOf("8b", "1e", "7d"), card.rows.single().stamps.map { it.flat })
        // The station and the query are called the same thing here, so the row
        // does not say it again under a heading that already does.
        assertEquals("", card.rows.single().text)
        assertEquals(listOf("8b 1e 7d"), card.items)
    }

    @Test
    fun `loose bikes are counted, not docked`() {
        val previews = GbfsRenderer.preview(
            entry(
                """
                {"gbfs-9": [
                  {"kind":"free_bike","name":"E-bike 4821","id":"b1","fuel_pct":0.62},
                  {"kind":"free_bike","name":"E-bike 1102","id":"b2","fuel_pct":0.31}
                ]}
                """.trimIndent()
            )
        )
        val card = previews.single()
        assertEquals("2 bikes nearby", card.subtitle)
        // More than one, so each is named.
        assertEquals(listOf("E-bike 4821 62%", "E-bike 1102 31%"), card.items)
        // A loose bike has a charge, not a dock to be returned to.
        assertEquals(
            listOf(R.drawable.fa_battery_half),
            card.rows.first().stamps.map { it.iconRes }
        )
    }

    @Test
    fun `weather is a headline, not a list`() {
        val previews = WeatherRenderer.preview(
            entry(
                """
                {"weather-3": {"query": {"name": "Home", "meta": {}}, "data": [
                  {"name":"Somerville","weather":"Clear","temp":21.4,"feel":20.9,
                   "hum":44,"pressure":1016,"wind":{"speed":3.1,"deg":250},"units":"metric"}
                ]}}
                """.trimIndent()
            )
        )
        val card = previews.single()
        assertEquals("21°C · Clear", card.title)
        assertEquals("Somerville", card.subtitle)
        assertEquals(Preview.Style.Basic, card.style)
    }
}
