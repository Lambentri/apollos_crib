package io.neiam.apolloscrib.types

import io.neiam.apolloscrib.targets.Targets
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A board captured off the wire from the live instance, kept as a fixture.
 *
 * Not a hand-written sample: this is the whole payload, every query in a real
 * vision. It exists because the shapes that break a parser are the ones nobody
 * would think to write out by hand -- tide heights published as strings, an
 * ephemeris whose fields depend on what the query asked for.
 */
class ProdBoardTest {

    private val payload: String =
        javaClass.getResourceAsStream("/prod_board.json")!!.bufferedReader().readText()

    private fun entry(key: String) = Wire.parse(payload).first { it.key == key }

    @Test
    fun `every query on the board is read`() {
        assertEquals(
            listOf("tidal-36", "gtfs-3", "gtfs-2", "gtfs-1", "gbfs-5", "gbfs-4", "ephem-35", "aqi-34"),
            Wire.parse(payload).map { it.key }
        )
        // Nothing left over: every type this vision publishes now has a shape.
        assertEquals(emptyList<String>(), Wire.unsupported(payload))
    }

    @Test
    fun `every entry renders something`() {
        Wire.parse(payload).forEach { entry ->
            val previews = Targets.preview(entry)
            assertTrue("no preview for ${entry.key}", previews.isNotEmpty())
            previews.forEach { preview ->
                assertTrue("blank title in ${entry.key}", preview.title.isNotBlank())
            }
        }
    }

    @Test
    fun `tides are ordered by the clock, not by the publisher`() {
        val card = Targets.preview(entry("tidal-36")).single()
        // The publisher sends first_h, first_l, second_h, second_l; the day
        // does not happen in that order.
        assertEquals(
            listOf("03:16", "09:20", "15:32", "21:58"),
            card.rows.map { it.stamps.first().text }
        )
        assertEquals(listOf("High", "Low", "High", "Low"), card.rows.map { it.text })
    }

    @Test
    fun `an ephemeris reads in the order a day does`() {
        val card = Targets.preview(entry("ephem-35")).single()
        assertEquals(listOf("Sunrise", "Sunset", "Moonrise", "Moonset"), card.rows.map { it.text })
        // Seconds, and fractions of one, are not what a sunrise is read to.
        assertEquals("06:10", card.rows.first().stamps.single().text)
        assertEquals("🌖 Waning gibbous", card.subtitle)
    }

    @Test
    fun `air quality reports what the monitor actually measured`() {
        val card = Targets.preview(entry("aqi-34")).single()
        assertEquals("Boston Metro", card.title)
        // pm25 and no2 here; the `combined` field is a restatement, not a reading.
        assertEquals(listOf("PM2.5", "NO2"), card.rows.map { it.text })
        assertEquals(listOf("17", "5"), card.rows.map { it.stamps.single().text })
    }

    @Test
    fun `a live departure is stamped as one`() {
        val card = Targets.preview(entry("gtfs-3")).single()
        assertTrue(card.rows.isNotEmpty())
        assertEquals(
            "every time on this board came from the feed",
            card.rows.first().stamps.map { it.iconRes }.distinct().size,
            1
        )
    }
}
