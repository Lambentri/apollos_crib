package io.neiam.apolloscrib.ui

import io.neiam.apolloscrib.types.TidalCondensed

/**
 * Reading a tide table the way somebody standing at the water does.
 *
 * The publisher sends four fields — first and second high, first and second
 * low — and they are four *slots*, not an order. Listing them as they arrive
 * puts both highs before both lows, which is a table of what happens today
 * rather than an answer to "is it coming in or going out".
 *
 * So they are sorted by the clock, the next one leads, and the one thing that
 * cannot be read off the numbers is stated outright: whether the water is
 * rising or falling right now. That is a fact about the *present*, and it is
 * the only thing here derived rather than reported.
 */
object Tides {

    data class Extreme(val minutes: Int, val high: Boolean, val at: String, val height: String?)

    /**
     * The four tides in clock order, dropping any the feed did not send.
     */
    fun order(tide: TidalCondensed): List<Extreme> =
        listOfNotNull(
            extreme(tide.first_h, tide.first_hv, high = true),
            extreme(tide.second_h, tide.second_hv, high = true),
            extreme(tide.first_l, tide.first_lv, high = false),
            extreme(tide.second_l, tide.second_lv, high = false)
        ).sortedBy { it.minutes }

    /**
     * The next tide after `nowMinutes`, or the earliest when they have all
     * passed.
     *
     * Wrapping rather than answering "none": a table that ends at 22:40 has
     * not stopped being a tide table at 23:00, and the next high is tomorrow
     * morning's. Saying nothing there would be the card going blank exactly
     * when somebody checks it late.
     */
    fun next(extremes: List<Extreme>, nowMinutes: Int): Extreme? =
        extremes.firstOrNull { it.minutes > nowMinutes } ?: extremes.firstOrNull()

    /**
     * Whether the water is rising or falling, from what comes next.
     *
     * Strictly it is implied by the tide being named beside it -- on its way
     * to a high means filling. Kept anyway, and first, because it is the part
     * you can read without knowing that: "coming in" needs no arithmetic and
     * no tide tables, and it is the answer to the question actually being
     * asked at the water's edge.
     */
    fun state(next: Extreme?): String? = when (next?.high) {
        true -> "Coming in"
        false -> "Going out"
        null -> null
    }

    /**
     * How long until then, as a person would say it.
     *
     * Wraps past midnight, so a tide at 00:40 read at 23:00 is "in 1h 40m"
     * rather than a negative number or a day away.
     */
    fun until(nowMinutes: Int, thenMinutes: Int): String {
        val delta = ((thenMinutes - nowMinutes) + MINUTES_IN_DAY) % MINUTES_IN_DAY
        val hours = delta / 60
        val minutes = delta % 60

        return when {
            delta == 0 -> "now"
            hours == 0 -> "in ${minutes}m"
            minutes == 0 -> "in ${hours}h"
            else -> "in ${hours}h ${minutes}m"
        }
    }

    /** "14:32:00" and "14:32" both read as minutes since midnight. */
    fun minutesOf(clock: String): Int? {
        val parts = clock.trim().split(":")
        if (parts.size < 2) return null

        val hours = parts[0].toIntOrNull() ?: return null
        val minutes = parts[1].toIntOrNull() ?: return null

        if (hours !in 0..23 || minutes !in 0..59) return null

        return hours * 60 + minutes
    }

    private fun extreme(at: String?, height: String?, high: Boolean): Extreme? {
        if (at.isNullOrBlank()) return null
        val minutes = minutesOf(at) ?: return null

        return Extreme(minutes, high, at, height?.takeIf { it.isNotBlank() })
    }

    private const val MINUTES_IN_DAY = 24 * 60
}
