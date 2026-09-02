package io.neiam.apolloscrib.types

import io.neiam.apolloscrib.targets.Targets
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A board captured off the wire from the live instance, kept as a fixture.
 *
 * Not a hand-written sample: this is the whole payload, every query in a real
 * vision, including the source types this build has no renderer for. It exists
 * because the shapes that break a parser are the ones nobody would think to
 * write out by hand.
 */
class ProdBoardTest {

    private val payload: String =
        javaClass.getResourceAsStream("/prod_board.json")!!.bufferedReader().readText()

    @Test
    fun `every query this build can draw comes back`() {
        val entries = Wire.parse(payload)
        assertEquals(listOf("gbfs-5", "gbfs-4"), entries.map { it.key })
    }

    @Test
    fun `the rest are named rather than silently dropped`() {
        assertEquals(listOf("aqi", "ephem", "tidal"), Wire.unsupported(payload))
    }

    @Test
    fun `every entry renders something`() {
        Wire.parse(payload).forEach { entry ->
            val previews = Targets.preview(entry)
            assertTrue("no preview for ${entry.key}", previews.isNotEmpty())
            previews.forEach { assertTrue("blank title in ${entry.key}", it.title.isNotBlank()) }
        }
    }
}
