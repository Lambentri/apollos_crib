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
 * The detailed board on the home screen, a card at a time.
 *
 * Its own widget rather than a mode on the compact one, because a home screen
 * has room for both and they answer different questions. The compact card is
 * for a glance -- when is the next one -- and this is for the readings a
 * glyph cannot label: pressure, visibility, which tide and how long.
 *
 * Both draw the same board. This one draws it through
 * [io.neiam.apolloscrib.ui.factsFor], the same reading the app's detailed mode
 * uses, so a card says the same thing on a home screen as it does in the app.
 */
class RichBoardWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray
    ) {
        widgetIds.forEach { id -> manager.updateAppWidget(id, build(context, id)) }
    }

    private fun build(context: Context, widgetId: Int): RemoteViews {
        val palette = appThemeByKey(Settings(context).themeKey)

        return RemoteViews(context.packageName, R.layout.widget_rich_board).apply {
            setInt(R.id.rich_board_root, "setBackgroundColor", palette.bg.toArgb())
            setTextColor(R.id.rich_board_empty, palette.dim.toArgb())

            // The factory needs the widget id, and an Intent's extras are not
            // part of its identity -- two widgets would share one factory
            // unless the data URI differs.
            val data = Intent(context, RichBoardWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                setData(Uri.parse("apolloscrib://richwidget/$widgetId"))
            }
            setRemoteAdapter(R.id.rich_flipper, data)
            setEmptyView(R.id.rich_flipper, R.id.rich_board_empty)

            // Tapping any card opens the app. Read-only, like every other
            // surface: there is nothing on a card to act on.
            val open = PendingIntent.getActivity(
                context,
                widgetId,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            setPendingIntentTemplate(R.id.rich_flipper, open)
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
            val ids = manager.getAppWidgetIds(ComponentName(context, RichBoardWidget::class.java))
            if (ids.isEmpty()) return
            manager.notifyAppWidgetViewDataChanged(ids, R.id.rich_flipper)
            context.sendBroadcast(
                Intent(context, RichBoardWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }
}
