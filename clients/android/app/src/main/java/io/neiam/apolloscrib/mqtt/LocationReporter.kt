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
    private val publish: (LocationUplink) -> Unit
) {

    private val manager =
        context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private var listening = false

    /**
     * Set when the broker will not take the uplink.
     *
     * A client that publishes where it has no write permission is not sent an
     * error -- RabbitMQ closes the connection. So a client reporting into a
     * server that has not been upgraded loses its board every couple of
     * minutes: connect, publish, disconnected, reconnect, publish. Giving up
     * on the uplink keeps the board, which is what the app is for.
     */
    @Volatile
    private var blocked = false

    private var failures = 0

    private val listener = LocationListener { location -> report(location) }

    /** True when the user has asked for this and Android has allowed it. */
    fun canReport(): Boolean =
        settings.publishLocation && !blocked && hasPermission()

    /**
     * Told when a publish did not land. A few in a row means the server will
     * not take this at all, rather than the network having been away.
     */
    fun onPublishFailed() {
        failures += 1
        if (failures >= GIVE_UP_AFTER && !blocked) {
            blocked = true
            Log.w(
                TAG,
                "giving up on the uplink after $failures failures: the board matters more"
            )
            stop()
        }
    }

    fun onPublishSucceeded() {
        failures = 0
    }

    /** Turning the setting off and on again is a deliberate retry. */
    fun retry() {
        blocked = false
        failures = 0
    }

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

        val provider = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                manager.allProviders.contains(LocationManager.FUSED_PROVIDER) ->
                LocationManager.FUSED_PROVIDER
            manager.allProviders.contains(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> LocationManager.GPS_PROVIDER
        }

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

    private fun stop() {
        if (!listening) return
        runCatching { manager?.removeUpdates(listener) }
        listening = false
        Log.d(TAG, "stopped reporting location")
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
         * Two minutes and a hundred metres, whichever the provider reaches
         * first. A foci that travels is answering "which stop am I near",
         * which does not change at walking pace within a block -- and the
         * cost of asking more often is the phone's battery.
         */
        private const val MIN_INTERVAL_MS = 2 * 60 * 1000L
        private const val MIN_DISTANCE_M = 100f

        /**
         * Three refusals is a server that does not want this, not a network
         * that was briefly away.
         */
        private const val GIVE_UP_AFTER = 3
    }
}
