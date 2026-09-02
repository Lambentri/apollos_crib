package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.DroughtCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * How dry it is.
 *
 * The headline is the worst category with any coverage, not a sum: the USDM
 * publishes cumulatively, so adding the categories up would count the same
 * acre several times.
 */
object DroughtRenderer : SourceRenderer {

    override val type = SourceType.Drought
    override val iconRes = R.drawable.fa_sun_plant_wilt
    override val label = "Apollo's Crib: Drought"
    override val description = "Drought Monitor coverage for an area in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val areas = entry.decode<List<DroughtCondensed>>().orEmpty()
            .filter { it.mapDate != null }
        val latest = areas.maxByOrNull { it.mapDate.orEmpty() } ?: return emptyList()

        val worst = latest.worst()

        return listOf(
            Preview(
                id = entry.key,
                title = latest.where() ?: entry.label(),
                subtitle = worst
                    ?.let { (category, pct) -> "$category over ${pct.asPercent()} of the area" }
                    ?: "No drought",
                iconRes = iconRes,
                rows = listOf(
                    "D0" to latest.d0, "D1" to latest.d1, "D2" to latest.d2,
                    "D3" to latest.d3, "D4" to latest.d4
                ).mapNotNull { (category, pct) ->
                    pct?.takeIf { it > 0.0 }?.let {
                        Row(
                            iconRes = iconRes,
                            text = category,
                            stamps = listOf(Stamp(R.drawable.fa_gauge_high, it.asPercent()))
                        )
                    }
                },
                empty = "No drought"
            )
        )
    }

    private fun Double.asPercent(): String = "${Math.round(this)}%"
}
