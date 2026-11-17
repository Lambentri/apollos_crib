package io.neiam.apolloscrib.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HoldsTest {

    private val all = setOf("a", "b", "c")

    @Test
    fun aLongPressHoldsAtTheTopAndASecondReleases() {
        val held = Holds().toggle("a").toggle("b")
        assertEquals(listOf("b", "a"), held.shown)

        val released = held.toggle("b")
        assertEquals(listOf("a"), released.shown)
        assertFalse(released.isHeld("b"))
    }

    @Test
    fun aFreshHeldCardNeverDrops() {
        var h = Holds().toggle("a")
        repeat(10) { h = h.turned(all, emptySet()) }
        assertEquals(listOf("a"), h.shown)
    }

    @Test
    fun aStaleHeldCardDropsAfterAFewTurns() {
        var h = Holds().toggle("a")
        repeat(Holds.DROP_AFTER - 1) { h = h.turned(all, setOf("a")) }
        assertEquals("still shown, dimmed", listOf("a"), h.shown)

        h = h.turned(all, setOf("a"))
        assertTrue(h.shown.isEmpty())
        assertTrue("dropped, but still held", h.isHeld("a"))
    }

    @Test
    fun anUpdateInBetweenStartsTheCountAgain() {
        var h = Holds().toggle("a")
        repeat(Holds.DROP_AFTER - 1) { h = h.turned(all, setOf("a")) }
        h = h.turned(all, emptySet())
        repeat(Holds.DROP_AFTER - 1) { h = h.turned(all, setOf("a")) }
        assertEquals(listOf("a"), h.shown)
    }

    @Test
    fun aDroppedCardComesBackAtTheTopWhenItUpdates() {
        var h = Holds().toggle("a").toggle("b") // b on top
        repeat(Holds.DROP_AFTER) { h = h.turned(all, setOf("a")) }
        assertEquals(listOf("b"), h.shown)

        // Still quiet: stays gone.
        h = h.settle(all, setOf("a"))
        assertEquals(listOf("b"), h.shown)

        // Updated: back, above b.
        h = h.settle(all, emptySet())
        assertEquals(listOf("a", "b"), h.shown)
    }

    @Test
    fun aCardThatLeavesTheBoardWaitsForItsReturn() {
        var h = Holds().toggle("a").toggle("b")
        h = h.settle(setOf("b"), emptySet())
        assertEquals(listOf("b"), h.shown)

        h = h.settle(all, emptySet())
        assertEquals(listOf("a", "b"), h.shown)
    }

    @Test
    fun releasingADroppedCardForgetsIt() {
        var h = Holds().toggle("a")
        repeat(Holds.DROP_AFTER) { h = h.turned(all, setOf("a")) }
        h = h.toggle("a")
        assertFalse(h.isHeld("a"))
        assertTrue(h.dormant.isEmpty())
    }

    @Test
    fun pinnedCardsLeadNewestFirst() {
        val pins = togglePin(togglePin(emptyList(), "c"), "b")
        assertEquals(listOf("b", "c"), pins)
        assertEquals(listOf("b", "c", "a", "d"), pinnedFirst(listOf("a", "b", "c", "d"), pins) { it })
        assertEquals(listOf("c"), togglePin(pins, "b"))
    }

    @Test
    fun aPinForACardNotOnTheBoardIsKeptButNotDrawn() {
        assertEquals(listOf("a", "b"), pinnedFirst(listOf("a", "b"), listOf("gone")) { it })
    }
}

class FreshnessTest {

    @Test
    fun aCardIsFreshWhenItsContentMoves() {
        val first = Freshness.observe(emptyMap(), mapOf("a" to 1, "b" to 2), at = 0)
        val later = Freshness.observe(first, mapOf("a" to 1, "b" to 3), at = 1_000)
        assertEquals(0L, later.getValue("a").changedAt)
        assertEquals(1_000L, later.getValue("b").changedAt)
    }

    @Test
    fun goesStaleAfterTheThreshold() {
        val seen = Seen(1, changedAt = 0)
        assertFalse(Freshness.isStale(seen, Freshness.STALE_AFTER_MS))
        assertTrue(Freshness.isStale(seen, Freshness.STALE_AFTER_MS + 1))
        assertFalse("never seen is not stale", Freshness.isStale(null, Long.MAX_VALUE))
    }

    @Test
    fun aCardThatLeavesAndReturnsIsNew() {
        val first = Freshness.observe(emptyMap(), mapOf("a" to 1), at = 0)
        val gone = Freshness.observe(first, emptyMap(), at = 10)
        val back = Freshness.observe(gone, mapOf("a" to 1), at = 20)
        assertEquals(20L, back.getValue("a").changedAt)
    }

    @Test
    fun roundTripsThroughText() {
        val seen = mapOf("gtfs_plus-12-87-Arlington" to Seen(-42, 1_700_000_000_000), "w" to Seen(7, 5))
        assertEquals(seen, Freshness.decode(Freshness.encode(seen)))
        assertEquals(emptyMap<String, Seen>(), Freshness.decode(""))
    }
}
