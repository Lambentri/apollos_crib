package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.AlertCondensed
import io.neiam.apolloscrib.types.GtfsPlusCondensed
import io.neiam.apolloscrib.types.PlusArrival
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * A stop from the Plus board, as a compact card.
 *
 * The same shape as [GtfsRenderer]'s — one card per stop, three rows of
 * routes — because a widget and a Smartspace target have the same room
 * whichever board the data came from. What Plus adds is what each row can
 * *say*: a delay, a platform, a cancellation, where Basic could only give a
 * time.
 *
 * Without this, a Plus board drew nothing at all outside the detailed view:
 * `gtfs_plus` is its own type, and a type with no renderer is dropped. That is
 * the right behaviour for a type this build does not know, and the wrong one
 * for the board it is meant to be reading.
 */
object GtfsPlusRenderer : SourceRenderer {

    override val type = SourceType.GtfsPlus
    override val iconRes = R.drawable.fa_bus_simple
    override val label = "Apollo's Crib: Transit (detailed)"
    override val description = "Next departures, with what the feed says about each"

    override fun preview(entry: VisionEntry): List<Preview> {
        val routes = entry.decode<List<GtfsPlusCondensed>>().orEmpty()

        // As in the Basic renderer: a stop with nothing due is not news, and
        // it crowds out the stops that have something. An alert still shows.
        if (routes.all { it.arrivals.isEmpty() }) {
            return listOfNotNull(alert(entry, routes))
        }

        val soonest = routes.sortedBy { route ->
            route.arrivals.firstNotNullOfOrNull { it.best() } ?: "99:99:99"
        }

        val board = Preview(
            id = entry.key,
            title = entry.label(),
            subtitle = summary(soonest),
            iconRes = soonest.firstOrNull()?.let { modeIcon(it.mode) } ?: iconRes,
            rows = soonest.map { row(it) },
            empty = "Nothing due"
        )

        return listOfNotNull(alert(entry, routes)) + board
    }

    /**
     * `[bus] 87 Arlington [tower] 15:33 · 3 late`
     *
     * Two departures, as Basic shows — but each stamped with what the feed
     * said about it rather than only when it is due.
     */
    private fun row(route: GtfsPlusCondensed): Row = Row(
        iconRes = modeIcon(route.mode),
        text = "${route.displayName()} ${route.dest.orEmpty()}".trim(),
        stamps = route.arrivals.take(2).map { arrival ->
            val time = arrival.best()?.asClockTime() ?: "--:--"
            val note = noteOf(arrival)

            Stamp(
                iconRes = if (arrival.live()) R.drawable.fa_tower_broadcast else R.drawable.fa_clock,
                text = if (note == null) time else "$time · $note",
                // Smartspace list rows are plain text, so the glyph cannot
                // carry the meaning and the word has to.
                flat = if (note == null) time else "$time $note"
            )
        }
    )

    /**
     * The one thing worth adding to a time, when there is one.
     *
     * Cancellation first: a rider who reads only the time and walks to the
     * stop has been failed by the card. Then lateness, then how full — in the
     * order that changes what somebody does.
     */
    private fun noteOf(arrival: PlusArrival): String? = when {
        arrival.trip_status == "CANCELED" -> "cancelled"
        arrival.stop_status == "SKIPPED" -> "not stopping"
        else -> arrival.delayMinutes()?.let { minutes ->
            when {
                minutes >= 1 -> "$minutes late"
                minutes <= -1 -> "${-minutes} early"
                else -> null
            }
        } ?: crowding(arrival)
    }

    private fun crowding(arrival: PlusArrival): String? = when (arrival.occupancy) {
        "CRUSHED_STANDING_ROOM_ONLY", "FULL" -> "full"
        "STANDING_ROOM_ONLY" -> "standing"
        "NOT_ACCEPTING_PASSENGERS" -> "not boarding"
        else -> null
    }

    private fun summary(routes: List<GtfsPlusCondensed>): String? {
        val first = routes.firstOrNull() ?: return null
        val arrival = first.arrivals.firstOrNull() ?: return null
        val time = arrival.best()?.asClockTime() ?: return null

        val note = noteOf(arrival)
        val live = if (arrival.live()) " · live" else ""

        return if (note == null) {
            "${first.displayName()} at $time$live"
        } else {
            "${first.displayName()} at $time · $note"
        }
    }

    /** As Basic does it: severe, or naming this stop. */
    private fun alert(entry: VisionEntry, routes: List<GtfsPlusCondensed>): Preview? {
        val alerts = routes.flatMap { it.alerts.orEmpty() }.distinctBy { it.header ?: it.effect }
        val lead = alerts.firstOrNull { it.severity == "SEVERE" || it.stop_specific == true }
            ?: return null

        return Preview(
            id = "${entry.key}-alert",
            title = lead.header ?: lead.effect.humanise(),
            subtitle = entry.label(),
            iconRes = alertIcon(lead),
            style = Preview.Style.Basic
        )
    }

    private fun alertIcon(alert: AlertCondensed): Int =
        if (alert.stop_specific == true) R.drawable.fa_location_dot
        else R.drawable.fa_triangle_exclamation

    // The same mapping live_preview.ex uses, so a route looks like itself.
    private fun modeIcon(mode: String?): Int = when (mode) {
        "Bus" -> R.drawable.fa_bus
        "Trolleybus" -> R.drawable.fa_bus_simple
        "Subway" -> R.drawable.fa_train_subway
        "Rail" -> R.drawable.fa_train
        "LightRail" -> R.drawable.fa_train_tram
        "Ferry" -> R.drawable.fa_ferry
        "CableCar", "Gondola" -> R.drawable.fa_cable_car
        "Funicular" -> R.drawable.fa_mountain
        else -> R.drawable.fa_train_tram
    }

    private fun String.humanise(): String =
        lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }
}
