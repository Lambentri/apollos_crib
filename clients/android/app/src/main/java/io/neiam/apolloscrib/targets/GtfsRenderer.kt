package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
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
    override val iconRes = R.drawable.ic_transit
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
            iconRes = iconRes,
            items = soonest.map { line(it) },
            empty = "Nothing due"
        )

        return listOfNotNull(alert(entry, routes)) + board
    }

    /** `14 → Heath St 08:00` -- the template truncates around 25 characters. */
    private fun line(route: GtfsCondensed): String {
        val next = route.departures().take(2).joinToString(" ") { it.asClockTime() }
        return "${route.displayName()} ${route.dest} $next"
    }

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
            iconRes = R.drawable.ic_alert,
            style = Preview.Style.Basic
        )
    }

    /** GTFS-RT spells its enums `NO_SERVICE`. */
    private fun String.humanise(): String =
        lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }
}
