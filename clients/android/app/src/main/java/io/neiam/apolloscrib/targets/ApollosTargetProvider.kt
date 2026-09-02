package io.neiam.apolloscrib.targets

import android.content.ComponentName
import android.content.Intent
import com.kieronquinn.app.smartspacer.sdk.model.SmartspaceTarget
import com.kieronquinn.app.smartspacer.sdk.provider.SmartspacerTargetProvider
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.ui.ConfigurationActivity
import android.graphics.drawable.Icon as AndroidIcon

/**
 * Everything a Target provider does that is not "what does this look like".
 *
 * Reads the board off disk, finds the query this instance was bound to, hands
 * it to a [SourceRenderer], and drops anything the user has dismissed. A
 * concrete provider is its renderer and nothing else -- see [GtfsTargetProvider].
 *
 * Instances are per-query: the user adds the Transit target once per stop they
 * care about, and the configuration activity records which is which, so
 * [SmartspacerTargetProvider.Config.allowAddingMoreThanOnce] is on.
 */
abstract class ApollosTargetProvider : SmartspacerTargetProvider() {

    abstract val renderer: SourceRenderer

    private val settings by lazy { Settings(provideContext()) }
    private val store by lazy { VisionStore(provideContext()) }

    override fun getSmartspaceTargets(smartspacerId: String): List<SmartspaceTarget> {
        val ctx = RenderContext(
            context = provideContext(),
            componentName = ComponentName(provideContext(), this::class.java),
            idPrefix = "$smartspacerId-",
            stale = store.isStale()
        )

        val entry = boundEntry(smartspacerId)
            ?: return listOf(setupPrompt(ctx, smartspacerId))

        val dismissed = settings.dismissed()
        return runCatching { renderer.render(ctx, entry) }
            .getOrDefault(emptyList())
            .filterNot { dismissed.contains(it.smartspaceTargetId) }
    }

    /**
     * The query this instance shows. A binding to a query that has since left
     * the vision reads as unbound rather than as an error: the user needs to
     * be told to pick again, and the prompt does that.
     */
    private fun boundEntry(smartspacerId: String): VisionEntry? {
        val key = settings.boundKey(smartspacerId) ?: return null
        return store.entry(key)
    }

    /**
     * Shown when there is nothing to show: no board yet, or a binding that no
     * longer resolves. A target rather than silence, because a Smartspacer
     * Target that renders nothing looks identical to one that is broken.
     */
    private fun setupPrompt(ctx: RenderContext, smartspacerId: String): SmartspaceTarget {
        val subtitle = when {
            !settings.isConfigured -> "Set up your Ankyra connection"
            store.lastUpdated() == null -> "Waiting for the first board"
            else -> "Tap to choose a query"
        }
        return ctx.basic(
            id = "setup",
            title = renderer.label,
            subtitle = subtitle,
            iconRes = renderer.iconRes
        )
    }

    override fun getConfig(smartspacerId: String?): Config = Config(
        label = renderer.label,
        description = renderer.description,
        icon = AndroidIcon.createWithResource(provideContext(), renderer.iconRes),
        allowAddingMoreThanOnce = true,
        configActivity = configIntent(smartspacerId),
        setupActivity = configIntent(smartspacerId),
        // The board arrives by push, and we call notifyChange when it does.
        // Smartspacer polling on top of that would only ever redraw what it
        // already has.
        refreshPeriodMinutes = 0
    )

    private fun configIntent(smartspacerId: String?): Intent =
        Intent(provideContext(), ConfigurationActivity::class.java).apply {
            putExtra(ConfigurationActivity.EXTRA_SOURCE_TYPE, renderer.type.wire)
            if (smartspacerId != null) {
                putExtra(ConfigurationActivity.EXTRA_SMARTSPACER_ID, smartspacerId)
            }
        }

    override fun onDismiss(smartspacerId: String, targetId: String): Boolean {
        settings.dismiss(targetId)
        notifyChange(smartspacerId)
        return true
    }

    override fun onProviderRemoved(smartspacerId: String) {
        settings.unbind(smartspacerId)
    }
}
