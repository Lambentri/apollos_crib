package io.neiam.apolloscrib.data

import android.content.Context
import androidx.core.content.edit
import io.neiam.apolloscrib.ui.Freshness
import io.neiam.apolloscrib.ui.Seen

/**
 * [Freshness]'s memory, on disk.
 *
 * Kept so an app opened after an hour away still knows the weather card has
 * not moved in that hour -- in memory alone, every card would be new again on
 * every launch, and nothing would ever look stale on a board that is mostly
 * opened rather than left open.
 */
class CardAges(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun load(): Map<String, Seen> = Freshness.decode(prefs.getString(KEY, "").orEmpty())

    fun save(seen: Map<String, Seen>) = prefs.edit { putString(KEY, Freshness.encode(seen)) }

    private companion object {
        const val NAME = "apollos_crib_card_ages"
        const val KEY = "seen"
    }
}
