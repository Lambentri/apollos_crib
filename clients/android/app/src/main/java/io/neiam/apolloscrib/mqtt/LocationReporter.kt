package io.neiam.apolloscrib.mqtt

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import io.neiam.apolloscrib.data.Settings

/**
 * Reports where this client is, when it has been asked to.
 *
 * Opt-in and silent otherwise: most of these are on a wall showing a fixed
 * vision, and have no business holding a location permission. Nothing here
 * runs -- no permission checked, no provider registered -- unless
 * [Settings.publishLocation] is on.
 *
 * The system's own provider rather than Play Services: this app has no other
 * dependency on Google's libraries and a fix good enough to say which stop you
 * are near does not need one.
 */
class LocationReporter(
    private val context: Context,
    private val settings: Settings,
    /** Whether the server is still taking anything from this client. */
    private val allowed: () -> Boolean,
    private val publish: (LocationUplink) -> Unit
) {

    private val manager =
        context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private var listening = false


    private val listener = LocationListener { location -> report(location) }

    /** True when the user has asked for this and Android has allowed it. */
    fun canReport(): Boolean =
        settings.publishLocation && allowed() && hasPermission()

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Start, stop, or leave alone, according to the setting. Called whenever
     * either the setting or the connection changes, so there is one place that
     * decides whether the provider should be running.
     */
    fun sync() {
        if (canReport()) start() else stop()
    }

    /** Called when the service goes away; there is nothing left to report to. */
    fun shutDown() = stop()

    private fun start() {
        if (listening) return
        val manager = manager ?: return

        val provider = bestProvider(manager)

        runCatching {
            manager.requestLocationUpdates(
                provider,
                MIN_INTERVAL_MS,
                MIN_DISTANCE_M,
                listener,
                context.mainLooper
            )
            listening = true
            Log.d(TAG, "reporting location from $provider")
            // The last known fix rather than waiting out the first interval:
            // a foci that travels is most wrong right after it is turned on.
            manager.getLastKnownLocation(provider)?.let(::report)
        }.onFailure { Log.w(TAG, "could not start location updates", it) }
    }

    private fun bestProvider(manager: LocationManager): String = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            manager.allProviders.contains(LocationManager.FUSED_PROVIDER) ->
            LocationManager.FUSED_PROVIDER
        manager.allProviders.contains(LocationManager.NETWORK_PROVIDER) ->
            LocationManager.NETWORK_PROVIDER
        else -> LocationManager.GPS_PROVIDER
    }

    private fun stop() {
        if (!listening) return
        runCatching { manager?.removeUpdates(listener) }
        listening = false
        Log.d(TAG, "stopped reporting location")
    }

    /**
     * Report where this client is, now, whatever the floors say.
     *
     * Asked for rather than waited for: the interval and the distance between
     * updates are there to keep a phone in a pocket quiet, and a person
     * looking at the screen has better information about whether this moment
     * matters than either of them does.
     */
    fun reportNow(onResult: (Boolean) -> Unit = {}) {
        if (!canReport()) return onResult(false)
        val manager = manager ?: return onResult(false)

        val provider = bestProvider(manager)

        runCatching {
            // A current fix rather than the last known one: "report now" that
            // sends a position from an hour ago is worse than useless, since
            // it looks like it worked.
            manager.getCurrentLocation(
                provider,
                null,
                context.mainExecutor
            ) { location ->
                if (location != null) {
                    report(location)
                    onResult(true)
                } else {
                    // No fix in the time it was willing to wait -- indoors,
                    // usually. The last one known is better than nothing.
                    val last = runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
                    last?.let(::report)
                    onResult(last != null)
                }
            }
        }.onFailure {
            Log.w(TAG, "could not take a fix", it)
            onResult(false)
        }
    }

    private fun report(location: Location) {
        // Checked again at the moment of sending: the setting can be turned
        // off between a fix being requested and arriving, and that fix should
        // not be the one that gets out.
        if (!canReport()) return
        publish(LocationUplink.from(location, settings.clientId))
    }

    companion object {
        private const val TAG = "LocationReporter"

        /**
         * Two minutes *and* a hundred metres: Android treats both as floors,
         * so a fix arrives only once each has been passed.
         *
         * Which means a phone standing still reports nothing at all, and that
         * is the intent -- a foci that travels is answering "which stop am I
         * near", which does not change while you are sitting down, and the
         * cost of asking more often is the battery. [reportNow] is the way to
         * say where you are without waiting for either.
         */
        private const val MIN_INTERVAL_MS = 2 * 60 * 1000L
        private const val MIN_DISTANCE_M = 100f
    }
}
