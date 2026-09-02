package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.TidalCondensed
import io.neiam.apolloscrib.types.VisionEntry

/**
 * High and low water.
 *
 * Ordered by time rather than by kind, because what a reader wants is the next
 * one -- the web lists first low, first high, second low, second high, which
 * is the publisher's order and not the day's.
 */
object TidalRenderer : SourceRenderer {

    override val type = SourceType.Tidal
    override val iconRes = R.drawable.fa_water
    override val label = "Apollo's Crib: Tides"
    override val description = "High and low water at a station in one of your visions"

    private data class Extreme(val time: String, val high: Boolean, val height: String?)

    override fun preview(entry: VisionEntry): List<Preview> {
        val tide = entry.decode<List<TidalCondensed>>()?.firstOrNull()
            ?: return emptyList()

        val extremes = listOfNotNull(
            tide.first_l?.let { Extreme(it, high = false, height = tide.first_lv) },
            tide.first_h?.let { Extreme(it, high = true, height = tide.first_hv) },
            tide.second_l?.let { Extreme(it, high = false, height = tide.second_lv) },
            tide.second_h?.let { Extreme(it, high = true, height = tide.second_hv) }
        ).sortedBy { it.time }

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = extremes.firstOrNull()?.let {
                    "${if (it.high) "High" else "Low"} at ${it.time.asClockTime()}"
                },
                iconRes = iconRes,
                rows = extremes.map { row(it) },
                empty = "No tides published"
            )
        )
    }

    private fun row(extreme: Extreme): Row = Row(
        iconRes = if (extreme.high) R.drawable.fa_arrows_up_to_line
        else R.drawable.fa_arrows_down_to_line,
        text = if (extreme.high) "High" else "Low",
        stamps = listOfNotNull(
            Stamp(R.drawable.fa_clock, extreme.time.asClockTime()),
            extreme.height?.let { Stamp(R.drawable.fa_water, feet(it), flat = "${feet(it)}ft") }
        )
    )

    /** Heights arrive with more precision than a glance wants. */
    private fun feet(value: String): String =
        value.toDoubleAsMetres()?.let { String.format("%.1f", it) } ?: value

    private fun String.toDoubleAsMetres(): Double? = toDoubleOrNull()
}
