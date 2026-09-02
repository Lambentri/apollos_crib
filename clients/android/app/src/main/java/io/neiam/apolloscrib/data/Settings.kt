package io.neiam.apolloscrib.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import java.util.UUID

/**
 * The Ankyra connection, and which query each added Target is showing.
 *
 * One connection for the whole app: an Ankyra is a single rabbit user with a
 * single topic, and a phone subscribing to two of them is not a case that
 * exists yet.
 */
class Settings(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    var host: String
        get() = prefs.getString(KEY_HOST, "").orEmpty()
        set(value) = prefs.edit { putString(KEY_HOST, value.trim()) }

    var port: Int
        get() = prefs.getInt(KEY_PORT, 1883)
        set(value) = prefs.edit { putInt(KEY_PORT, value) }

    var username: String
        get() = prefs.getString(KEY_USER, "").orEmpty()
        set(value) = prefs.edit { putString(KEY_USER, value.trim()) }

    var password: String
        get() = prefs.getString(KEY_PASS, "").orEmpty()
        set(value) = prefs.edit { putString(KEY_PASS, value) }

    /** The rabbit user's topic, verbatim -- the same string the LilyGo client subscribes to. */
    var topic: String
        get() = prefs.getString(KEY_TOPIC, "").orEmpty()
        set(value) = prefs.edit { putString(KEY_TOPIC, value.trim()) }

    /**
     * Which of the ported palettes the app's own screens use. Not a
     * light/dark switch: these are the same named themes the Scribus routes
     * render under, and the user picks one.
     */
    var themeKey: String
        get() = prefs.getString(KEY_THEME, "after-dark").orEmpty()
        set(value) = prefs.edit { putString(KEY_THEME, value) }

    var useTls: Boolean
        get() = prefs.getBoolean(KEY_TLS, false)
        set(value) = prefs.edit { putBoolean(KEY_TLS, value) }

    /**
     * Stable per-install client id. Ankyra counts its consumers by looking for
     * `mqtt-subscription-<client_id>qos0`, so this has to survive restarts for
     * the phone to show up as connected in the Ankyra config page -- and has
     * to be registered there (or auto-registration left on) to connect at all.
     */
    val clientId: String
        get() = prefs.getString(KEY_CLIENT_ID, null) ?: UUID.randomUUID().toString()
            .take(8).let { "smartspacer-$it" }.also { prefs.edit { putString(KEY_CLIENT_ID, it) } }

    val isConfigured: Boolean
        get() = host.isNotEmpty() && topic.isNotEmpty()

    /**
     * The entry key (`"gtfs-12"`) a given Target instance shows, chosen in the
     * configuration activity Smartspacer opens. Null means "not chosen yet",
     * which the providers render as a prompt rather than as nothing.
     */
    fun boundKey(smartspacerId: String): String? =
        prefs.getString("$KEY_BINDING_PREFIX$smartspacerId", null)

    fun bind(smartspacerId: String, entryKey: String) =
        prefs.edit { putString("$KEY_BINDING_PREFIX$smartspacerId", entryKey) }

    fun unbind(smartspacerId: String) =
        prefs.edit { remove("$KEY_BINDING_PREFIX$smartspacerId") }

    /**
     * Targets the user has dismissed, kept until the underlying data changes.
     * Smartspacer asks us to forget them ourselves; keyed by target id so
     * dismissing one route does not dismiss the stop.
     */
    fun dismiss(targetId: String) =
        prefs.edit { putStringSet(KEY_DISMISSED, dismissed() + targetId) }

    fun dismissed(): Set<String> = prefs.getStringSet(KEY_DISMISSED, emptySet()).orEmpty()

    fun clearDismissed() = prefs.edit { remove(KEY_DISMISSED) }

    companion object {
        private const val NAME = "apollos_crib"
        private const val KEY_HOST = "host"
        private const val KEY_PORT = "port"
        private const val KEY_USER = "username"
        private const val KEY_PASS = "password"
        private const val KEY_TOPIC = "topic"
        private const val KEY_TLS = "tls"
        private const val KEY_THEME = "theme"
        private const val KEY_CLIENT_ID = "client_id"
        private const val KEY_BINDING_PREFIX = "binding_"
        private const val KEY_DISMISSED = "dismissed"
    }
}
