package io.neiam.apolloscrib.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.targets.Preview
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.ui.theme.AppTheme
import io.neiam.apolloscrib.ui.theme.appThemeByKey

/** The cards the widget flips through. */
class BoardWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        BoardFactory(applicationContext)
}

private class BoardFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private val store = VisionStore(context)
    private var cards: List<Preview> = emptyList()
    private var palette: AppTheme = appThemeByKey(Settings(context).themeKey)

    override fun onCreate() = Unit

    /**
     * Called on create and on every notified change, on a background thread.
     * Reading the board here rather than per card keeps one payload being
     * parsed once for the whole cycle.
     */
    override fun onDataSetChanged() {
        palette = appThemeByKey(Settings(context).themeKey)
        cards = store.entries().flatMap { Targets.preview(it) }
    }

    override fun onDestroy() {
        cards = emptyList()
    }

    override fun getCount(): Int = cards.size

    override fun getViewAt(position: Int): RemoteViews {
        val card = cards.getOrNull(position) ?: return loading()

        return RemoteViews(context.packageName, R.layout.widget_card).apply {
            setInt(R.id.card_root, "setBackgroundColor", palette.cardBg.toArgb())

            setImageViewResource(R.id.card_icon, card.iconRes)
            setInt(R.id.card_icon, "setColorFilter", palette.primary.toArgb())

            setTextViewText(R.id.card_title, card.title)
            setTextColor(R.id.card_title, palette.content.toArgb())

            setTextViewText(R.id.card_subtitle, card.subtitle.orEmpty())
            setTextColor(R.id.card_subtitle, palette.dim.toArgb())
            setViewVisibility(
                R.id.card_subtitle,
                if (card.subtitle.isNullOrEmpty()) android.view.View.GONE
                else android.view.View.VISIBLE
            )

            removeAllViews(R.id.card_rows)
            if (card.style == Preview.Style.List) {
                if (card.rows.isEmpty()) {
                    addView(R.id.card_rows, emptyRow(card.empty))
                } else {
                    // A widget's height is whatever the user dragged it to and
                    // cannot be measured from here, so the count is a guess
                    // that errs towards fitting. The app's board is where all
                    // of them are.
                    card.rows.take(MAX_ROWS).forEach { addView(R.id.card_rows, row(it)) }
                    val extra = card.rows.size - MAX_ROWS
                    if (extra > 0) addView(R.id.card_rows, emptyRow("+$extra more"))
                }
            }
        }
    }

    private fun row(source: io.neiam.apolloscrib.targets.Row) =
        RemoteViews(context.packageName, R.layout.widget_row).apply {
            setImageViewResource(R.id.row_icon, source.iconRes)
            setInt(R.id.row_icon, "setColorFilter", palette.dim.toArgb())
            setTextViewText(R.id.row_label, source.text)
            setTextColor(R.id.row_label, palette.content.toArgb())

            removeAllViews(R.id.row_values)
            source.stamps.forEach { stamp ->
                addView(
                    R.id.row_values,
                    RemoteViews(context.packageName, R.layout.widget_stamp).apply {
                        setImageViewResource(R.id.stamp_icon, stamp.iconRes)
                        setInt(R.id.stamp_icon, "setColorFilter", palette.accent.toArgb())
                        setTextViewText(R.id.stamp_text, stamp.text)
                        setTextColor(R.id.stamp_text, palette.accent.toArgb())
                    }
                )
            }
        }

    /** A line of prose where a list would go: "Nothing due", "+2 more". */
    private fun emptyRow(text: String) =
        RemoteViews(context.packageName, R.layout.widget_row).apply {
            setViewVisibility(R.id.row_icon, android.view.View.GONE)
            setTextViewText(R.id.row_label, text)
            setTextColor(R.id.row_label, palette.dim.toArgb())
        }

    private fun loading() = RemoteViews(context.packageName, R.layout.widget_card)

    override fun getLoadingView(): RemoteViews? = null

    /** Positions are stable: the same query keeps the same card. */
    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        cards.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    companion object {
        private const val MAX_ROWS = 4
    }
}
