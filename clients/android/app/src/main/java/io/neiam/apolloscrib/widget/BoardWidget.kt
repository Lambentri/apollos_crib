package io.neiam.apolloscrib.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.mqtt.AnkyraService
import io.neiam.apolloscrib.ui.MainActivity
import io.neiam.apolloscrib.ui.theme.appThemeByKey
import io.neiam.apolloscrib.data.Settings

/**
 * The board on the home screen, a card at a time.
 *
 * A third way to read the same thing: the Smartspace targets show one query
 * each, the launcher feed page shows all of them, and this cycles. The cards
 * are built from the same [io.neiam.apolloscrib.targets.Preview]s as both, so
 * a route reads the same wherever it is drawn.
 *
 * The cycling is the host's: `autoAdvanceViewId` in the widget's metadata
 * points at the flipper, and launchers that honour it advance the card. On the
 * ones that do not, the flipper can still be swiped.
 */
class BoardWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray
    ) {
        widgetIds.forEach { id -> manager.updateAppWidget(id, build(context, id)) }
    }

    private fun build(context: Context, widgetId: Int): RemoteViews {
        val palette = appThemeByKey(Settings(context).themeKey)

        return RemoteViews(context.packageName, R.layout.widget_board).apply {
            setInt(R.id.board_root, "setBackgroundColor", palette.bg.toArgb())
            setTextColor(R.id.board_empty, palette.dim.toArgb())

            // The factory needs the widget id, and an Intent's extras are not
            // part of its identity -- two widgets would share one factory
            // unless the data URI differs.
            val data = Intent(context, BoardWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                setData(Uri.parse("apolloscrib://widget/$widgetId"))
            }
            setRemoteAdapter(R.id.board_flipper, data)
            setEmptyView(R.id.board_flipper, R.id.board_empty)

            // Tapping any card opens the app. Read-only, like every other
            // surface: there is nothing on a card to act on.
            val open = PendingIntent.getActivity(
                context,
                widgetId,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            setPendingIntentTemplate(R.id.board_flipper, open)
        }
    }

    override fun onEnabled(context: Context) {
        // A widget on the home screen is a reason to be connected, the same
        // way the feed page is.
        AnkyraService.resume(context)
    }

    companion object {

        /**
         * Redraw every widget from what just arrived.
         *
         * Two calls: the data change reloads the factory, and the update
         * rebuilds the flipper around it. Without the second, a widget added
         * before the first board keeps showing its empty view.
         */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, BoardWidget::class.java))
            if (ids.isEmpty()) return
            manager.notifyAppWidgetViewDataChanged(ids, R.id.board_flipper)
            context.sendBroadcast(
                Intent(context, BoardWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }
}

/** Compose colours carry an alpha as a float; RemoteViews wants an int. */
internal fun androidx.compose.ui.graphics.Color.toArgb(): Int =
    android.graphics.Color.argb(
        (alpha * 255f + 0.5f).toInt(),
        (red * 255f + 0.5f).toInt(),
        (green * 255f + 0.5f).toInt(),
        (blue * 255f + 0.5f).toInt()
    )
