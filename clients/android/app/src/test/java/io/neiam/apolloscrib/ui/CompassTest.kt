package io.neiam.apolloscrib.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The compass names a bearing the same way the publisher does.
 *
 * A card says a stop is "NE" and the dial says which way the phone is facing.
 * If the two disagree about where NE begins, the pair is worse than either
 * alone -- so this is the same sixteen-point table, checked at the edges.
 */
class CompassTest {

    @Test
    fun `the cardinals sit where they should`() {
        assertEquals("N", compassPoint(0f))
        assertEquals("E", compassPoint(90f))
        assertEquals("S", compassPoint(180f))
        assertEquals("W", compassPoint(270f))
    }

    @Test
    fun `the diagonals sit where they should`() {
        assertEquals("NE", compassPoint(45f))
        assertEquals("SE", compassPoint(135f))
        assertEquals("SW", compassPoint(225f))
        assertEquals("NW", compassPoint(315f))
    }

    @Test
    fun `a bearing rounds to its nearest point`() {
        // Each point owns 22.5 degrees, so the boundary between N and NNE is
        // at 11.25.
        assertEquals("N", compassPoint(11f))
        assertEquals("NNE", compassPoint(12f))
    }

    @Test
    fun `north wraps rather than falling off the end`() {
        // 349 is past the last point (NNW) and back into north's half.
        assertEquals("N", compassPoint(349f))
        assertEquals("N", compassPoint(360f))
        assertEquals("NNW", compassPoint(340f))
    }

    @Test
    fun `a reading outside one turn is still a bearing`() {
        // Smoothing works in degrees and can drift past the range; naming a
        // bearing should not care.
        assertEquals("E", compassPoint(450f))
        assertEquals("W", compassPoint(-90f))
    }
}
