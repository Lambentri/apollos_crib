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
    override val iconRes = R.drawable.ic_bike
    override val label = "Apollo's Crib: Bikeshare"
    override val description = "Bikes and docks at a station in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val stations = entry.decode<List<GbfsCondensed>>().orEmpty()

        // Most bikes first: for a dock that is the one worth walking to, and
        // for loose bikes the feed implies no order to preserve.
        val ordered = stations.sortedByDescending { it.avail ?: 0 }

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = summary(ordered),
                iconRes = iconRes,
                items = ordered.map { line(it) },
                empty = "No bikes nearby"
            )
        )
    }

    private fun line(station: GbfsCondensed): String = when {
        station.isFreeBike() -> {
            val charge = station.fuel_pct?.let { " ${(it * 100).toInt()}%" }.orEmpty()
            "${station.name}$charge"
        }
        else -> {
            val bikes = station.avail ?: 0
            val docks = station.docks_avail ?: 0
            "${station.name} ${bikes}b ${docks}d"
        }
    }

    private fun summary(stations: List<GbfsCondensed>): String? {
        if (stations.isEmpty()) return null
        if (stations.all { it.isFreeBike() }) return "${stations.size} bikes nearby"
        val bikes = stations.sumOf { it.avail ?: 0 }
        val electric = stations.sumOf { it.avail_elec ?: 0 }
        return if (electric > 0) "$bikes bikes · $electric electric" else "$bikes bikes"
    }
}
