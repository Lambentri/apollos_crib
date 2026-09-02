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
 * What one query's answer says, before anything decides where to draw it.
 *
 * A renderer produces these; [RenderContext.target] turns one into a
 * Smartspacer target, and the app's own board draws the same thing as a card.
 * One description, two surfaces -- so the card on the phone's home screen and
 * the card in the app cannot drift apart.
 */
data class Preview(
    val id: String,
    val title: String,
    val subtitle: String?,
    val iconRes: Int,
    val items: List<String> = emptyList(),
    val empty: String = "Nothing to show",
    val style: Style = Style.List
) {
    enum class Style { Basic, List }
}

/**
 * What one source type looks like.
 *
 * A renderer knows its source and nothing about MQTT, storage or Smartspacer's
 * provider plumbing -- [ApollosTargetProvider] holds all of that. Supporting a
 * new source is a type in `types/`, a renderer here, an entry in [Targets] and
 * four lines of manifest.
 */
interface SourceRenderer {
    val type: SourceType

    /** The icon and label Smartspacer shows when adding this Target. */
    val iconRes: Int
    val label: String
    val description: String

    fun preview(entry: VisionEntry): List<Preview>

    /**
     * Smartspacer targets for this entry. Every renderer wants the same
     * mapping, so none of them writes it.
     */
    fun render(ctx: RenderContext, entry: VisionEntry): List<SmartspaceTarget> =
        preview(entry).map { ctx.target(it) }
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

    fun target(preview: Preview): SmartspaceTarget = when (preview.style) {
        Preview.Style.List -> TargetTemplate.ListItems(
            id = "$idPrefix${preview.id}",
            componentName = componentName,
            context = context,
            title = Text(preview.title),
            subtitle = preview.subtitle?.let { Text(withStaleness(it)) },
            icon = icon(preview.iconRes),
            listItems = preview.items.take(MAX_LIST_ITEMS).map { Text(it) },
            listIcon = icon(preview.iconRes),
            emptyListMessage = Text(preview.empty),
            onClick = openApp()
        ).create()

        Preview.Style.Basic -> TargetTemplate.Basic(
            id = "$idPrefix${preview.id}",
            componentName = componentName,
            title = Text(preview.title),
            subtitle = preview.subtitle?.let { Text(withStaleness(it)) },
            icon = icon(preview.iconRes),
            onClick = openApp()
        ).create()
    }

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

    /** What one entry says, for anything drawing it outside Smartspacer. */
    fun preview(entry: VisionEntry): List<Preview> =
        rendererFor(entry.type)?.let { renderer ->
            runCatching { renderer.preview(entry) }.getOrDefault(emptyList())
        }.orEmpty()

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
