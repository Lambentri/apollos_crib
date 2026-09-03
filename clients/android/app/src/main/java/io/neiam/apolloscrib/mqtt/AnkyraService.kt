package io.neiam.apolloscrib.mqtt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.widget.BoardWidget
import io.neiam.apolloscrib.ui.MainActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Holds the Ankyra subscription open.
 *
 * A foreground service because that is what an always-on socket costs on
 * Android: nothing else in this app is running when the phone is in a pocket,
 * and a Target provider is only alive for the length of one call. The
 * notification is the honest statement of that.
 */
class AnkyraService : Service() {

    private lateinit var settings: Settings
    private lateinit var store: VisionStore
    private var client: AnkyraClient? = null
    private var location: LocationReporter? = null

    /**
     * Set when the broker will not take anything this client sends.
     *
     * A publish to a topic a client may not write is not answered with an
     * error -- RabbitMQ closes the connection -- so an uplink the server does
     * not know about costs the board every couple of minutes. After a few
     * refusals the uplink stops and the board goes on, which is the right one
     * to keep.
     */
    private var uplinkFailures = 0
    private var uplinkBlocked = false

    override fun onCreate() {
        super.onCreate()
        running = this
        settings = Settings(this)
        store = VisionStore(this)
        location = LocationReporter(this, settings, allowed = { !uplinkBlocked }) { uplink ->
            sendUplink(LocationUplink.topicFor(settings.topic), Json.encodeToString(uplink))
        }
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundCompat(notification(state.value))

        if (client == null) {
            client = AnkyraClient(
                settings = settings,
                onMessage = ::onPayload,
                onState = ::onState
            ).also { it.connect() }
        }
        // Whether this reports its location is a setting, so every start is a
        // chance for it to have changed.
        location?.sync()
        // Sticky: if Android kills this for memory, the board should come back
        // when there is room again, without the user opening the app.
        return START_STICKY
    }

    /**
     * Send something to the server, while it is still taking things.
     *
     * Everything a client says goes through here so one refusal count covers
     * all of it: a location and a request for a board are refused for the same
     * reason, and either one costs the same connection.
     */
    private fun sendUplink(topic: String, payload: String) {
        if (uplinkBlocked) return
        client?.publish(topic, payload) { ok ->
            if (ok) {
                uplinkFailures = 0
            } else {
                uplinkFailures += 1
                if (uplinkFailures >= GIVE_UP_AFTER) {
                    uplinkBlocked = true
                    Log.w(TAG, "giving up on the uplink: the board matters more")
                    location?.sync()
                }
            }
        }
    }

    /**
     * Ask for a board.
     *
     * A Pythiae publishes on change and on its own tick, so a client that has
     * just woken up can be looking at something old with no way to say so.
     * Cheap to ask and debounced at the other end.
     */
    fun requestBoard() {
        if (!settings.isConfigured) return
        sendUplink("${settings.topic}.publish.board", "{}")
    }

    /** Say where this client is, now. See [LocationReporter.reportNow]. */
    fun reportLocationNow(onResult: (Boolean) -> Unit) {
        val reporter = location
        if (reporter == null) onResult(false) else reporter.reportNow(onResult)
    }

    private fun onPayload(payload: String) {
        Log.d(TAG, "payload: ${payload.length} bytes")
        store.save(payload)
        // A fresh payload can un-dismiss: a target the user swiped away was
        // about a departure that has since gone.
        settings.clearDismissed()
        Targets.notifyAll(this)
        BoardWidget.refresh(this)
    }

    private fun onState(newState: AnkyraClient.State) {
        state.value = newState
        // Proof the settings are right, which is what licenses reconnecting on
        // a later launch without asking.
        if (newState == AnkyraClient.State.Connected) {
            settings.hasConnected = true
            // Just subscribed, so whatever is on disk is from before the gap.
            // This covers the cases the callers below cannot: a cold start,
            // where the service is not up yet when the screen asks, and every
            // reconnect after a tunnel.
            requestBoard()
        }
        // The notification is the only place a connection problem is visible,
        // since the Targets themselves fall back to the stored board.
        runCatching {
            getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, notification(newState))
        }
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notification(state: AnkyraClient.State): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val text = when (state) {
            AnkyraClient.State.Connected -> "Listening to ${settings.topic}"
            AnkyraClient.State.Connecting -> "Connecting to ${settings.host}"
            AnkyraClient.State.Failed -> "Not connected -- check settings"
            AnkyraClient.State.Disconnected -> "Disconnected"
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Apollo's Crib")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_crib)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Ankyra connection",
            // Low: this notification exists because Android requires one, not
            // because it is news.
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        running = null
        location?.shutDown()
        client?.disconnect()
        client = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "AnkyraService"
        private const val CHANNEL_ID = "ankyra"
        private const val NOTIFICATION_ID = 1
        const val ACTION_STOP = "io.neiam.apolloscrib.STOP"

        /** Three refusals is a server that will not take this, not a blip. */
        private const val GIVE_UP_AFTER = 3

        /**
         * The running service, for the few callers that need to reach the
         * live connection rather than start one.
         */
        private var running: AnkyraService? = null

        /** Connection state, for the settings screen to show. */
        val state = MutableStateFlow(AnkyraClient.State.Disconnected)
        val connectionState: StateFlow<AnkyraClient.State> get() = state

        fun start(context: Context) {
            if (!Settings(context).isConfigured) return
            context.startForegroundService(Intent(context, AnkyraService::class.java))
        }

        /**
         * Reconnect on launch, if this connection has worked before.
         *
         * START_STICKY covers the service being killed while the phone stays
         * up; this covers everything else -- a reboot the receiver missed, a
         * force-stop, an app update. Cheap when the service is already
         * running: [onStartCommand] finds a live client and leaves it alone.
         */
        fun resume(context: Context) {
            val settings = Settings(context)
            if (settings.isConfigured && settings.hasConnected) start(context)
        }

        /**
         * Ask for a fresh board, if anything is listening.
         *
         * Sent through the running service rather than a new connection: the
         * one that is subscribed is the one the answer comes back on.
         */
        fun requestBoard(context: Context) {
            running?.requestBoard()
        }

        /**
         * Publish a position on demand.
         *
         * Reports false when nothing is listening, which is the same answer
         * the button wants for a service that is not running: it did not go.
         */
        fun reportLocationNow(context: Context, onResult: (Boolean) -> Unit) {
            val service = running
            if (service == null) onResult(false) else service.reportLocationNow(onResult)
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, AnkyraService::class.java).setAction(ACTION_STOP)
            )
        }
    }
}
