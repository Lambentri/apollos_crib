package io.neiam.apolloscrib.targets

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.kieronquinn.app.smartspacer.sdk.model.SmartspaceTarget
import com.kieronquinn.app.smartspacer.sdk.model.uitemplatedata.Icon
import com.kieronquinn.app.smartspacer.sdk.model.uitemplatedata.TapAction
import com.kieronquinn.app.smartspacer.sdk.model.uitemplatedata.Text
import com.kieronquinn.app.smartspacer.sdk.utils.TargetTemplate
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.ui.MainActivity
import android.graphics.drawable.Icon as AndroidIcon

/**
 * What one query's answer looks like on the Smartspace.
 *
 * A renderer knows one source type and nothing about MQTT, storage or
 * Smartspacer's provider plumbing -- [ApollosTargetProvider] holds all of
 * that. Supporting a new source is a type in `types/`, a renderer here, an
 * entry in [Targets] and four lines of manifest.
 */
interface SourceRenderer {
    val type: SourceType

    /** The icon and label Smartspacer shows when adding this Target. */
    val iconRes: Int
    val label: String
    val description: String

    fun render(ctx: RenderContext, entry: VisionEntry): List<SmartspaceTarget>
}

/**
 * Everything a renderer needs to build a target without knowing which provider
 * it is being built for.
 */
class RenderContext(
    val context: Context,
    val componentName: ComponentName,
    /** Prefix every target id with this, so two instances of the same provider
     *  showing different stops do not collide. */
    val idPrefix: String,
    /** True when the board on disk is old enough to be worth saying so. */
    val stale: Boolean
) {
    fun icon(res: Int): Icon = Icon(AndroidIcon.createWithResource(context, res))

    /** Tapping anything opens the app -- there is nowhere better to send it yet. */
    fun openApp(): TapAction = TapAction(
        intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )

    /**
     * A list target, the shape most of these want: a heading, a supporting
     * line, and up to three rows underneath.
     */
    fun list(
        id: String,
        title: String,
        subtitle: String?,
        iconRes: Int,
        items: List<String>,
        empty: String
    ): SmartspaceTarget = TargetTemplate.ListItems(
        id = "$idPrefix$id",
        componentName = componentName,
        context = context,
        title = Text(title),
        subtitle = subtitle?.let { Text(withStaleness(it)) },
        icon = icon(iconRes),
        listItems = items.take(MAX_LIST_ITEMS).map { Text(it) },
        listIcon = icon(iconRes),
        emptyListMessage = Text(empty),
        onClick = openApp()
    ).create()

    fun basic(
        id: String,
        title: String,
        subtitle: String?,
        iconRes: Int
    ): SmartspaceTarget = TargetTemplate.Basic(
        id = "$idPrefix$id",
        componentName = componentName,
        title = Text(title),
        subtitle = subtitle?.let { Text(withStaleness(it)) },
        icon = icon(iconRes),
        onClick = openApp()
    ).create()

    /**
     * Said on the subtitle rather than by hiding the target. A board that has
     * gone quiet is still the last thing known about the stop, and a rider
     * looking at old times needs to be told they are old, not shown nothing.
     */
    private fun withStaleness(subtitle: String): String =
        if (stale) "$subtitle · stale" else subtitle

    companion object {
        /** Smartspacer's own ceiling for the list template. */
        const val MAX_LIST_ITEMS = 3
    }
}

/**
 * The registry. Every provider in the manifest appears here, and nothing else
 * needs to know the set.
 */
object Targets {

    val renderers: List<SourceRenderer> = listOf(
        GtfsRenderer,
        GbfsRenderer,
        WeatherRenderer
    )

    private val providers: List<Class<out ApollosTargetProvider>> = listOf(
        GtfsTargetProvider::class.java,
        GbfsTargetProvider::class.java,
        WeatherTargetProvider::class.java
    )

    fun rendererFor(type: SourceType): SourceRenderer? =
        renderers.firstOrNull { it.type == type }

    /** Tell Smartspacer every one of our Targets has something new to say. */
    fun notifyAll(context: Context) {
        providers.forEach { provider ->
            runCatching {
                com.kieronquinn.app.smartspacer.sdk.provider.SmartspacerTargetProvider
                    .notifyChange(context, provider)
            }
        }
    }
}

/** `08:00:00` is not what anybody reads off a departure board. */
internal fun String.asClockTime(): String =
    if (length >= 5 && this[2] == ':') substring(0, 5) else this
