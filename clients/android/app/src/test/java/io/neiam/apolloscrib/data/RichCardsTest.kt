package io.neiam.apolloscrib.data

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * How the compass gesture moves through the modes.
 *
 * One more card each press, and off the end back to the compact board -- so
 * the gesture always has somewhere to go and never needs a second one to undo
 * it.
 */
class RichCardsTest {

    private fun next(from: Int) = (from + 1) % (Settings.MAX_RICH_CARDS + 1)

    @Test
    fun `each press adds a card until three, then resets`() {
        assertEquals(1, next(0))
        assertEquals(2, next(1))
        assertEquals(3, next(2))
        assertEquals(0, next(3))
    }

    @Test
    fun `four presses return to where they started`() {
        var mode = 0
        repeat(4) { mode = next(mode) }

        assertEquals(0, mode)
    }
}
