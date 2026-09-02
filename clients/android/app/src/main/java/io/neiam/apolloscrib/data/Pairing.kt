package io.neiam.apolloscrib.data

import android.net.Uri

/**
 * A connection handed over as a link.
 *
 * The Ankyra config page draws `apolloscrib://ankyra?host=..&topic=..` as a QR;
 * the phone's camera opens it and this reads it. A scheme rather than a payload
 * the app has to be aimed at, so there is no scanner here to keep working.
 */
data class Pairing(
    val host: String,
    val port: Int,
    val username: String,
    val password: String,
    val topic: String,
    val useTls: Boolean
) {
    fun applyTo(settings: Settings) {
        settings.host = host
        settings.port = port
        settings.username = username
        settings.password = password
        settings.topic = topic
        settings.useTls = useTls
    }

    companion object {
        const val SCHEME = "apolloscrib"
        const val HOST = "ankyra"

        /**
         * Read a pairing link, or null if this is not one. Host and topic are
         * the two without which there is nothing to connect to; the rest have
         * defaults, since an unauthenticated broker on 1883 is a real setup.
         */
        fun from(uri: Uri?): Pairing? {
            if (uri == null || uri.scheme != SCHEME || uri.host != HOST) return null
            val host = uri.getQueryParameter("host")?.takeIf { it.isNotBlank() } ?: return null
            val topic = uri.getQueryParameter("topic")?.takeIf { it.isNotBlank() } ?: return null
            return Pairing(
                host = host.trim(),
                port = uri.getQueryParameter("port")?.toIntOrNull() ?: 1883,
                username = uri.getQueryParameter("user").orEmpty(),
                password = uri.getQueryParameter("pass").orEmpty(),
                topic = topic.trim(),
                useTls = uri.getQueryParameter("tls") == "1"
            )
        }
    }
}
