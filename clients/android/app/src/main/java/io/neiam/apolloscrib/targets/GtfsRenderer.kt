package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.AlertCondensed
import io.neiam.apolloscrib.types.GtfsCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * A stop, as a departure board.
 *
 * One card for the stop rather than one per route: a Smartspace shows a single
 * card at a time and cycles, so a stop split across five targets is a stop the
 * user sees a fifth of. The routes leaving soonest win the three lines the
 * template gives.
 *
 * A severe alert gets a card of its own, ahead of the times -- "the line is
 * suspended" is not a footnote on a list of departures that are not happening.
 */
object GtfsRenderer : SourceRenderer {

    override val type = SourceType.Gtfs
    override val iconRes = R.drawable.fa_bus_simple
    override val label = "Apollo's Crib: Transit"
    override val description = "Next departures from a stop in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val routes = entry.decode<List<GtfsCondensed>>().orEmpty()

        // Soonest first. The publisher orders departures within a route but
        // says nothing about the order of the routes themselves.
        val soonest = routes.sortedBy { it.departures().firstOrNull() ?: "99:99" }

        val board = Preview(
            id = entry.key,
            title = entry.label(),
            subtitle = summary(soonest),
            // The stop's own glyph is whatever mostly calls there -- a bus
            // stop and a subway platform should not look alike.
            iconRes = modeIcon(soonest.firstOrNull()?.mode),
            rows = soonest.map { row(it) },
            empty = "Nothing due"
        )

        return listOfNotNull(alert(entry, routes)) + board
    }

    /**
     * `[bus] 87 Arlington Center [tower] 15:33 [clock] 15:56` -- each time
     * stamped with where it came from, as the web board stamps them. Two
     * departures: a third rarely fits the width, and the row after it is
     * another route the rider might take instead.
     */
    private fun row(route: GtfsCondensed): Row = Row(
        iconRes = modeIcon(route.mode),
        text = "${route.displayName()} ${route.dest}",
        stamps = route.times.indices.take(2).map { index ->
            val live = route.times_live?.getOrNull(index)
            Stamp(
                iconRes = if (live != null) R.drawable.fa_tower_broadcast else R.drawable.fa_clock,
                text = (live ?: route.times[index]).asClockTime()
            )
        }
    )

    /** The one thing worth putting on the second line: what leaves first. */
    private fun summary(routes: List<GtfsCondensed>): String? {
        val first = routes.firstOrNull() ?: return null
        val time = first.departures().firstOrNull()?.asClockTime() ?: return null
        val live = first.times_live?.firstOrNull() != null
        return if (live) "${first.displayName()} at $time · live" else "${first.displayName()} at $time"
    }

    /**
     * Alerts, when one is bad enough to lead with. Everything the feed marked
     * severe, plus anything naming this stop specifically -- a lift out of
     * service is stop news even when the line is running fine.
     */
    private fun alert(entry: VisionEntry, routes: List<GtfsCondensed>): Preview? {
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

    /** A pin when the alert is about this stop, as the web board does it. */
    private fun alertIcon(alert: AlertCondensed): Int =
        if (alert.stop_specific == true) R.drawable.fa_location_dot
        else R.drawable.fa_triangle_exclamation

    /** The same mapping live_preview.ex uses, so a route looks like itself. */
    private fun modeIcon(mode: String?): Int = when (mode) {
        "Bus" -> R.drawable.fa_bus
        "Trolleybus" -> R.drawable.fa_bus_simple
        "Subway" -> R.drawable.fa_train_subway
        "Rail" -> R.drawable.fa_train
        "LightRail" -> R.drawable.fa_train_tram
        "Ferry" -> R.drawable.fa_ferry
        "CableCar", "Gondola" -> R.drawable.fa_cable_car
        "Funicular" -> R.drawable.fa_mountain
        // Monorail has no glyph of its own in the free set, and a tram reads
        // closer than the web's stand-in does.
        else -> R.drawable.fa_train_tram
    }

    /** GTFS-RT spells its enums `NO_SERVICE`. */
    private fun String.humanise(): String =
        lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }
}
