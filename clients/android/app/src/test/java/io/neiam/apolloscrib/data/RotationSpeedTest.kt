package io.neiam.apolloscrib.data

import org.junit.Assert.assertEquals
import org.junit.Test

/** Tapping the compass walks the offered turns and comes back round. */
class RotationSpeedTest {

    private fun next(from: Int): Int {
        val choices = Settings.ROTATION_CHOICES
        return choices[(choices.indexOf(from) + 1) % choices.size]
    }

    @Test
    fun `the offered turns are the ones asked for`() {
        assertEquals(listOf(2_000, 3_000, 5_000, 8_000, 12_000), Settings.ROTATION_CHOICES)
    }

    @Test
    fun `each tap moves to the next, and the last wraps`() {
        assertEquals(3_000, next(2_000))
        assertEquals(5_000, next(3_000))
        assertEquals(8_000, next(5_000))
        assertEquals(12_000, next(8_000))
        assertEquals(2_000, next(12_000))
    }

    @Test
    fun `a value this build does not offer still moves somewhere`() {
        // indexOf returns -1, so the next is the first. Not a crash, and not
        // stuck on a number that is no longer on the list.
        assertEquals(2_000, next(9_999))
    }
}
