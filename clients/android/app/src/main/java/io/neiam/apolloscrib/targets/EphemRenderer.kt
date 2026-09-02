package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.EphemerisCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Sunrise, sunset, and what the moon is doing.
 *
 * The moon's phase leads, since it is the part that is not the same every day
 * at a glance. Whatever other periods the query asked for follow.
 */
object EphemRenderer : SourceRenderer {

    override val type = SourceType.Ephem
    override val iconRes = R.drawable.fa_moon
    override val label = "Apollo's Crib: Sun and moon"
    override val description = "Sunrise, sunset and moon phase at a focus in one of your visions"

    /** The order a day is read in, before anything the query added. */
    private val KNOWN = listOf("sunrise", "sunset", "moonrise", "moonset")

    override fun preview(entry: VisionEntry): List<Preview> {
        val sky = EphemerisCondensed.list(entry.data).firstOrNull() ?: return emptyList()

        val times = (KNOWN + (sky.periods.keys - KNOWN.toSet() - setOf("phase")))
            .mapNotNull { key -> sky.periods[key]?.let { key to it } }

        return listOf(
            Preview(
                id = entry.key,
                title = sky.name ?: entry.label(),
                subtitle = sky.phase?.let { phase ->
                    listOfNotNull(sky.moonGlyph(), phase.humanise()).joinToString(" ")
                },
                iconRes = iconRes,
                rows = times.map { (key, value) ->
                    Row(
                        iconRes = glyph(key),
                        text = key.humanise(),
                        stamps = listOf(Stamp(R.drawable.fa_clock, value.asClockTime()))
                    )
                },
                empty = "Nothing published"
            )
        )
    }

    private fun glyph(period: String): Int = when {
        period.startsWith("sun") -> R.drawable.fa_sun
        period.startsWith("moon") -> R.drawable.fa_moon
        else -> R.drawable.fa_clock
    }

    private fun String.humanise(): String =
        replace('_', ' ').replaceFirstChar { it.uppercase() }
}
