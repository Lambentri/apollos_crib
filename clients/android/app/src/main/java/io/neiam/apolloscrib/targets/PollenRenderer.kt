package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.PollenCondensed
import io.neiam.apolloscrib.types.PollenTypeInfo
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Grass, trees and weeds.
 *
 * Worst first, and only what is in season: a zero for a type that stopped
 * flowering in June is not news in September.
 */
object PollenRenderer : SourceRenderer {

    override val type = SourceType.Pollen
    override val iconRes = R.drawable.fa_seedling
    override val label = "Apollo's Crib: Pollen"
    override val description = "Pollen counts at a focus in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val today = entry.decode<List<PollenCondensed>>()?.firstOrNull()
            ?: return emptyList()

        val worst = today.pollenTypeInfo
            .filter { it.inSeason || (it.indexInfo?.value ?: 0) > 0 }
            .sortedByDescending { it.indexInfo?.value ?: 0 }

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = worst.firstOrNull()?.let { "${it.name()} ${it.category()}" },
                iconRes = iconRes,
                rows = worst.map { info ->
                    Row(
                        iconRes = iconRes,
                        text = info.name(),
                        stamps = listOfNotNull(
                            info.indexInfo?.value?.let { Stamp(R.drawable.fa_gauge_high, "$it") },
                            info.indexInfo?.category?.let { Stamp(R.drawable.fa_circle_info, it) }
                        )
                    )
                },
                empty = "Nothing in season"
            )
        )
    }

    private fun PollenTypeInfo.name(): String =
        displayName ?: code?.lowercase()?.replaceFirstChar { it.uppercase() } ?: "Pollen"

    private fun PollenTypeInfo.category(): String = indexInfo?.category ?: "—"
}
