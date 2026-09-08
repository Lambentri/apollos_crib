package io.neiam.apolloscrib.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Which page of cards a rotation shows.
 *
 * The composable owns the timer; this is the arithmetic under it, which is
 * where the awkward cases live: a last page with room to spare, and a list
 * that already fits.
 */
class WindowTest {

    // The same expression `rememberRotation` uses, once a turn is chosen --
    // whether that turn came from the timer or from a flick.
    private fun page(total: Int, size: Int, page: Int): List<Int> {
        if (total <= 0 || size <= 0) return emptyList()
        if (total <= size) return (0 until total).toList()

        return (page until page + size).map { it % total }
    }

    @Test
    fun `a list that fits does not rotate`() {
        assertEquals(listOf(0, 1), page(total = 2, size = 3, page = 0))
        assertEquals(listOf(0, 1, 2), page(total = 3, size = 3, page = 0))
    }

    @Test
    fun `each turn slides on by one, keeping what was already read`() {
        // The two cards you were reading stay; one arrives and one leaves.
        assertEquals(listOf(0, 1, 2), page(total = 6, size = 3, page = 0))
        assertEquals(listOf(1, 2, 3), page(total = 6, size = 3, page = 1))
        assertEquals(listOf(2, 3, 4), page(total = 6, size = 3, page = 2))
    }

    @Test
    fun `a window running off the end comes back round`() {
        // Still three cards, as the mode promises, not one and a gap.
        assertEquals(listOf(3, 0, 1), page(total = 4, size = 3, page = 3))
    }

    @Test
    fun `a full turn returns to the start`() {
        assertEquals(page(total = 5, size = 2, page = 0), page(total = 5, size = 2, page = 5))
    }

    @Test
    fun `one card at a time walks the list`() {
        assertEquals(listOf(0), page(total = 3, size = 1, page = 0))
        assertEquals(listOf(1), page(total = 3, size = 1, page = 1))
        assertEquals(listOf(2), page(total = 3, size = 1, page = 2))
    }

    @Test
    fun `nothing to show is nothing rather than a crash`() {
        assertEquals(emptyList<Int>(), page(total = 0, size = 3, page = 0))
        assertEquals(emptyList<Int>(), page(total = 5, size = 0, page = 0))
    }
}
