package io.neiam.apolloscrib.feed

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * What a launcher needs to know about us before it will use us as its feed.
 *
 * Launchers that take a "minus one" provider generally check the provider's
 * signing certificate against a list they ship -- Lawnchair keeps one in
 * `FeedBridge.initializeWhitelist`, keyed by package and by
 * `Signature.hashCode()`. An unlisted package is filtered out of the picker
 * before the user ever sees it.
 *
 * So the hash is reported here rather than left to be worked out with keytool:
 * it is the one value an entry needs, it is different for every keystore, and
 * a debug build's is not a release build's.
 */
object FeedProvider {

    /**
     * This install's signing certificate hash, as a launcher computes it.
     *
     * `Signature.hashCode()` is `Arrays.hashCode` over the certificate bytes,
     * which is what the lists are keyed by -- not a digest anybody would get
     * from `apksigner`.
     */
    fun signatureHash(context: Context): String? {
        val hash = runCatching {
            val pm = context.packageManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = pm.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                val signing = info.signingInfo ?: return null
                // A launcher checks the history, so report the current one:
                // the value to list is what this install actually presents.
                signing.signingCertificateHistory?.firstOrNull()?.hashCode()
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
                    .signatures?.firstOrNull()?.hashCode()
            }
        }.getOrNull() ?: return null

        return "0x%x".format(hash)
    }
}
