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
import io.neiam.apolloscrib.targets.Targets
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

    override fun onCreate() {
        super.onCreate()
        settings = Settings(this)
        store = VisionStore(this)
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
            )
        }
        client?.connect()
        // Sticky: if Android kills this for memory, the board should come back
        // when there is room again, without the user opening the app.
        return START_STICKY
    }

    private fun onPayload(payload: String) {
        Log.d(TAG, "payload: ${payload.length} bytes")
        store.save(payload)
        // A fresh payload can un-dismiss: a target the user swiped away was
        // about a departure that has since gone.
        settings.clearDismissed()
        Targets.notifyAll(this)
    }

    private fun onState(newState: AnkyraClient.State) {
        state.value = newState
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

        /** Connection state, for the settings screen to show. */
        val state = MutableStateFlow(AnkyraClient.State.Disconnected)
        val connectionState: StateFlow<AnkyraClient.State> get() = state

        fun start(context: Context) {
            if (!Settings(context).isConfigured) return
            context.startForegroundService(Intent(context, AnkyraService::class.java))
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, AnkyraService::class.java).setAction(ACTION_STOP)
            )
        }
    }
}
