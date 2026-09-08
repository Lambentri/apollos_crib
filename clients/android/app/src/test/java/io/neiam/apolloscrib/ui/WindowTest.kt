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

    // The same expression `rotatingWindow` uses, once a page is chosen.
    private fun page(total: Int, size: Int, page: Int): List<Int> {
        if (total <= 0 || size <= 0) return emptyList()
        if (total <= size) return (0 until total).toList()

        val start = page * size
        return (start until start + size).map { it % total }
    }

    @Test
    fun `a list that fits does not rotate`() {
        assertEquals(listOf(0, 1), page(total = 2, size = 3, page = 0))
        assertEquals(listOf(0, 1, 2), page(total = 3, size = 3, page = 0))
    }

    @Test
    fun `each turn moves on by a whole page`() {
        assertEquals(listOf(0, 1, 2), page(total = 6, size = 3, page = 0))
        assertEquals(listOf(3, 4, 5), page(total = 6, size = 3, page = 1))
    }

    @Test
    fun `a short last page is filled from the front rather than coming up short`() {
        // Four routes, three at a time: the second page is 3, 0, 1 -- three
        // cards, as the mode promises, not one.
        assertEquals(listOf(0, 1, 2), page(total = 4, size = 3, page = 0))
        assertEquals(listOf(3, 0, 1), page(total = 4, size = 3, page = 1))
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
