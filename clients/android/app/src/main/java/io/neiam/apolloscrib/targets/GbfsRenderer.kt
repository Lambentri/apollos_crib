package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.GbfsCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Docks, or loose bikes.
 *
 * The same query answers with either, depending on whether it names a station
 * or an area, and the condenser tells them apart by what came back rather than
 * by the query. This does the same.
 */
object GbfsRenderer : SourceRenderer {

    override val type = SourceType.Gbfs
    override val iconRes = R.drawable.fa_bicycle
    override val label = "Apollo's Crib: Bikeshare"
    override val description = "Bikes and docks at a station in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val stations = entry.decode<List<GbfsCondensed>>().orEmpty()

        // Most bikes first: for a dock that is the one worth walking to, and
        // for loose bikes the feed implies no order to preserve.
        val ordered = stations.sortedByDescending { it.avail ?: 0 }

        val title = entry.label()
        // A station query names the station and the query the same thing, so
        // the row would repeat the card's own heading back at it -- and, being
        // long, push the counts off the edge doing it.
        val named = ordered.size > 1 || ordered.firstOrNull()?.name != title

        return listOf(
            Preview(
                id = entry.key,
                title = title,
                subtitle = summary(ordered),
                iconRes = iconRes,
                rows = ordered.map { row(it, named = named) },
                empty = "No bikes nearby"
            )
        )
    }

    /**
     * A dock counts what is in it and what is free to return to; a loose bike
     * has only its charge. The web board stamps the same three things --
     * bikes, a bolt for the electric ones, and parking for the docks.
     */
    private fun row(station: GbfsCondensed, named: Boolean): Row = when {
        station.isFreeBike() -> Row(
            iconRes = R.drawable.fa_bicycle,
            text = if (named) station.name else "",
            stamps = station.fuel_pct?.let {
                listOf(Stamp(R.drawable.fa_battery_half, "${(it * 100).toInt()}%"))
            }.orEmpty()
        )

        else -> Row(
            iconRes = R.drawable.fa_bicycle,
            text = if (named) station.name else "",
            stamps = buildList {
                val bikes = station.avail ?: 0
                add(Stamp(R.drawable.fa_bicycle, "$bikes", flat = "${bikes}b"))
                val electric = station.avail_elec ?: 0
                if (electric > 0) {
                    add(Stamp(R.drawable.fa_bolt_lightning, "$electric", flat = "${electric}e"))
                }
                val docks = station.docks_avail ?: 0
                add(Stamp(R.drawable.fa_square_parking, "$docks", flat = "${docks}d"))
            }
        )
    }

    private fun summary(stations: List<GbfsCondensed>): String? {
        if (stations.isEmpty()) return null
        if (stations.all { it.isFreeBike() }) return "${stations.size} bikes nearby"
        val bikes = stations.sumOf { it.avail ?: 0 }
        val electric = stations.sumOf { it.avail_elec ?: 0 }
        return if (electric > 0) "$bikes bikes · $electric electric" else "$bikes bikes"
    }
}
