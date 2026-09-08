package io.neiam.apolloscrib.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.ui.RichFacts
import io.neiam.apolloscrib.ui.factsFor
import io.neiam.apolloscrib.ui.theme.AppTheme
import io.neiam.apolloscrib.ui.theme.appThemeByKey

/**
 * The cards behind the detailed widget.
 *
 * Built from [factsFor], which is the same reading the app's detailed mode
 * uses — a headline that answers the question and beneath it the things that
 * qualify it, each saying its own name. That function has no Compose in it,
 * which is what lets a RemoteViews surface share it rather than growing a
 * second opinion about what a weather card should say.
 */
class RichBoardWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Factory(applicationContext)

    private class Factory(private val context: Context) : RemoteViewsFactory {

        private val store = VisionStore(context)
        private var cards: List<RichFacts> = emptyList()
        private var palette: AppTheme = appThemeByKey(Settings(context).themeKey)

        override fun onCreate() = Unit

        override fun onDataSetChanged() {
            palette = appThemeByKey(Settings(context).themeKey)

            // The Plus board where there is one, as the compact widget does:
            // the same board with more on it, and Basic's own answer for every
            // type Plus does not extend.
            val board = store.plusEntries().ifEmpty { store.entries() }

            // Transit is left to the compact widget. Its detailed card is a
            // route badge and a list of departures each with its own delay and
            // crowding, which is a scrolling thing, and a widget card does not
            // scroll -- it would come out truncated in a way that hides the
            // very detail it is here for.
            cards = board
                .filter { it.type != SourceType.Gtfs && it.type != SourceType.GtfsPlus }
                .mapNotNull { factsFor(it) }
        }

        override fun onDestroy() {
            cards = emptyList()
        }

        override fun getCount(): Int = cards.size

        override fun getViewAt(position: Int): RemoteViews {
            val card = cards.getOrNull(position) ?: return loading()

            return RemoteViews(context.packageName, R.layout.widget_rich_card).apply {
                setInt(R.id.rich_root, "setBackgroundColor", palette.cardBg.toArgb())

                setImageViewResource(R.id.rich_icon, card.iconRes)
                setInt(R.id.rich_icon, "setColorFilter", palette.primary.toArgb())

                setTextViewText(R.id.rich_title, card.title)
                setTextColor(R.id.rich_title, palette.content.toArgb())

                setTextViewText(R.id.rich_headline, card.headline.orEmpty())
                setTextColor(R.id.rich_headline, palette.accent.toArgb())
                setViewVisibility(
                    R.id.rich_headline,
                    if (card.headline == null) android.view.View.GONE else android.view.View.VISIBLE
                )

                setTextViewText(R.id.rich_caption, card.caption.orEmpty())
                setTextColor(R.id.rich_caption, palette.dim.toArgb())
                setViewVisibility(
                    R.id.rich_caption,
                    if (card.caption == null) android.view.View.GONE else android.view.View.VISIBLE
                )

                // The picture of the answer, where there is one worth drawing.
                if (card.glyph != null) {
                    setImageViewResource(R.id.rich_glyph, card.glyph)
                    setInt(R.id.rich_glyph, "setColorFilter", palette.accent.toArgb())
                    setViewVisibility(R.id.rich_glyph, android.view.View.VISIBLE)
                } else {
                    setViewVisibility(R.id.rich_glyph, android.view.View.GONE)
                }

                removeAllViews(R.id.rich_facts)

                // Four, because a widget card does not scroll and a fifth row
                // would be drawn off the bottom of it -- present, unreadable,
                // and indistinguishable from a card that simply ended.
                card.facts.take(4).forEach { fact ->
                    addView(
                        R.id.rich_facts,
                        RemoteViews(context.packageName, R.layout.widget_fact).apply {
                            setTextViewText(R.id.fact_label, fact.label)
                            setTextColor(R.id.fact_label, palette.dim.toArgb())
                            setTextViewText(R.id.fact_value, fact.value)
                            setTextColor(R.id.fact_value, palette.content.toArgb())
                        }
                    )
                }
            }
        }

        private fun loading() = RemoteViews(context.packageName, R.layout.widget_rich_card)

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount(): Int = 1

        override fun getItemId(position: Int): Long = position.toLong()

        override fun hasStableIds(): Boolean = true
    }
}
