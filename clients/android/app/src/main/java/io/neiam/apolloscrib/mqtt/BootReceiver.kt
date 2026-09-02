package io.neiam.apolloscrib.mqtt

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * A board the user configured once should still be there after a reboot,
 * without them opening the app to say so.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AnkyraService.start(context)
        }
    }
}
