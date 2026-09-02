package io.neiam.apolloscrib.targets

import com.kieronquinn.app.smartspacer.sdk.model.SmartspaceTarget
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.types.WeatherCondensed
import kotlin.math.roundToInt

/**
 * Current conditions.
 *
 * Kept deliberately small: it is the worked example of what adding a source
 * costs, next to the two that carry real weight.
 */
object WeatherRenderer : SourceRenderer {

    override val type = SourceType.Weather
    override val iconRes = R.drawable.ic_weather
    override val label = "Apollo's Crib: Weather"
    override val description = "Conditions at a focus in one of your visions"

    override fun render(ctx: RenderContext, entry: VisionEntry): List<SmartspaceTarget> {
        val current = entry.decode<List<WeatherCondensed>>()?.firstOrNull()
            ?: return emptyList()

        val temp = current.temp?.roundToInt()?.let { "$it${current.degrees()}" }
        val title = listOfNotNull(temp, current.weather).joinToString(" · ")
            .ifEmpty { entry.label() }

        return listOf(
            ctx.basic(
                id = entry.key,
                title = title,
                subtitle = current.name ?: entry.label(),
                iconRes = iconRes
            )
        )
    }
}
