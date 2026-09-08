package io.neiam.apolloscrib.ui

import io.neiam.apolloscrib.types.TidalCondensed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Reading a tide table the way somebody standing at the water does.
 *
 * The publisher sends four slots, not an order, and the useful questions --
 * what is next, and is it coming in -- are neither of them a field.
 */
class TidesTest {

    // A real-looking day: low, high, low, high.
    private val day = TidalCondensed(
        first_h = "08:12:00", first_hv = "3.1m",
        second_h = "20:40:00", second_hv = "3.4m",
        first_l = "02:05:00", first_lv = "0.4m",
        second_l = "14:28:00", second_lv = "0.6m"
    )

    @Test
    fun `the four slots come back in clock order, not field order`() {
        // Listing the fields as they arrive puts both highs before both lows,
        // which is not a day.
        assertEquals(
            listOf("02:05:00", "08:12:00", "14:28:00", "20:40:00"),
            Tides.order(day).map { it.at }
        )
    }

    @Test
    fun `the next tide is the next one, not the first field`() {
        val extremes = Tides.order(day)

        // Ten in the morning: the high at 08:12 has gone.
        assertEquals("14:28:00", Tides.next(extremes, 10 * 60)?.at)
        // Just before midnight: nothing left today.
        assertEquals("02:05:00", Tides.next(extremes, 23 * 60 + 30)?.at)
    }

    @Test
    fun `a table that has run out wraps to tomorrow rather than going blank`() {
        // Which is exactly when somebody checks it: late.
        val extremes = Tides.order(day)

        assertEquals("02:05:00", Tides.next(extremes, 22 * 60)?.at)
    }

    @Test
    fun `the next tide says which kind it is`() {
        val extremes = Tides.order(day)

        // Which is the thing the card names, rather than leaving it to be
        // deduced from the three tides underneath it.
        assertEquals(true, Tides.next(extremes, 5 * 60)?.high)
        assertEquals(false, Tides.next(extremes, 10 * 60)?.high)
    }

    @Test
    fun `how long until reads as a person would say it`() {
        assertEquals("in 2h 40m", Tides.until(nowMinutes = 11 * 60 + 48, thenMinutes = 14 * 60 + 28))
        assertEquals("in 40m", Tides.until(nowMinutes = 13 * 60 + 48, thenMinutes = 14 * 60 + 28))
        assertEquals("in 2h", Tides.until(nowMinutes = 12 * 60, thenMinutes = 14 * 60))
        assertEquals("now", Tides.until(nowMinutes = 14 * 60, thenMinutes = 14 * 60))
    }

    @Test
    fun `a tide after midnight is soon, not a day away`() {
        // 23:00 to 00:40 is an hour and forty, not minus twenty-two hours.
        assertEquals("in 1h 40m", Tides.until(nowMinutes = 23 * 60, thenMinutes = 40))
    }

    @Test
    fun `a half-published table still reads`() {
        val partial = TidalCondensed(first_h = "08:12:00", first_hv = "3.1m")

        assertEquals(1, Tides.order(partial).size)
        assertEquals("08:12:00", Tides.next(Tides.order(partial), 0)?.at)
    }

    @Test
    fun `nothing published is nothing rather than a crash`() {
        assertEquals(emptyList<Tides.Extreme>(), Tides.order(TidalCondensed()))
        assertNull(Tides.next(emptyList(), 600))
    }

    @Test
    fun `a time it cannot read is left out rather than guessed at`() {
        assertNull(Tides.minutesOf("not a time"))
        assertNull(Tides.minutesOf("25:00"))
        assertEquals(14 * 60 + 28, Tides.minutesOf("14:28"))
        assertEquals(14 * 60 + 28, Tides.minutesOf("14:28:00"))
    }
}
