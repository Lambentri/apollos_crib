package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.AqiCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * What is in the air at a reporting area.
 *
 * The publisher sends whatever the monitor measured, so nothing is assumed
 * present: every reading it did send gets a row, named the way the web names
 * the ones it recognises.
 */
object AqiRenderer : SourceRenderer {

    override val type = SourceType.Aqi
    override val iconRes = R.drawable.fa_lungs
    override val label = "Apollo's Crib: Air quality"
    override val description = "Pollutant readings for an area in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val readings = AqiCondensed.list(entry.data).firstOrNull() ?: return emptyList()

        return listOf(
            Preview(
                id = entry.key,
                title = readings.name ?: entry.label(),
                subtitle = readings.measurements.entries.firstOrNull()?.let {
                    "${AqiCondensed.label(it.key)} ${it.value}"
                },
                iconRes = iconRes,
                rows = readings.measurements.map { (key, value) ->
                    Row(
                        iconRes = R.drawable.fa_lungs,
                        text = AqiCondensed.label(key),
                        stamps = listOf(Stamp(R.drawable.fa_gauge_high, value))
                    )
                },
                empty = "No readings"
            )
        )
    }
}
