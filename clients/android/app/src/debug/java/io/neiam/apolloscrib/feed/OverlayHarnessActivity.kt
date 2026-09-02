package io.neiam.apolloscrib.feed

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.libraries.launcherclient.ILauncherOverlay
import com.google.android.libraries.launcherclient.ILauncherOverlayCallback

/**
 * A stand-in launcher, for testing [FeedOverlayService] without one.
 *
 * Launchers gate feed providers on a signature whitelist they ship, so an
 * unlisted app cannot be selected as the feed at all -- which leaves the
 * riskiest part of the overlay, attaching a window to somebody else's token,
 * untestable through the real path.
 *
 * This does what a launcher does: binds the service, hands over its own window
 * token, and drives the scroll. Debug-only; it is a test rig, not a feature.
 */
class OverlayHarnessActivity : Activity() {

    // Not `overlay`: inside an `apply` on a View that name resolves to
    // View.getOverlay(), and the shadowing is silent until something fails to
    // compile against the wrong type.
    private var client: ILauncherOverlay? = null
    private lateinit var status: TextView

    private val callback = object : ILauncherOverlayCallback.Stub() {
        override fun overlayScrollChanged(progress: Float) {
            Log.d(TAG, "overlayScrollChanged($progress)")
            runOnUiThread { status.text = "overlay reported scroll $progress" }
        }

        override fun overlayStatusChanged(state: Int) {
            Log.d(TAG, "overlayStatusChanged($state)")
            runOnUiThread { status.text = "overlay reported status $state" }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            client = ILauncherOverlay.Stub.asInterface(binder)
            Log.d(TAG, "bound: ${client != null}")
            attach()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            client = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        status = TextView(this).apply { text = "binding…" }
        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(48, 200, 48, 48)
                addView(status)
                addView(button("attach") { attach() })
                addView(button("scroll 0 → 1") { sweep() })
                addView(button("open") { client?.openOverlay(0) })
                addView(button("close") { client?.closeOverlay(0) })
                addView(button("detach") { client?.windowDetached(false) })
            }
        )

        bindService(
            Intent(this, FeedOverlayService::class.java),
            connection,
            Context.BIND_AUTO_CREATE
        )
    }

    private fun button(label: String, onClick: () -> Unit) = Button(this).apply {
        text = label
        setOnClickListener { runCatching(onClick).onFailure { Log.e(TAG, label, it) } }
    }

    /**
     * The launcher's half of the handshake: its own window's LayoutParams,
     * whose token is what lets the service put a window over this one.
     */
    private fun attach() {
        val overlay = client ?: return
        val lp = window.attributes
        val bundle = Bundle().apply {
            putParcelable("layout_params", lp)
            putParcelable("configuration", resources.configuration)
            putInt("client_options", 7)
        }
        Log.d(TAG, "windowAttached2 token=${lp.token}")
        overlay.windowAttached2(bundle, callback)
        overlay.setActivityState(ACTIVITY_STARTED or ACTIVITY_RESUMED)
    }

    /** A drag, as the launcher reports one. */
    private fun sweep() {
        val overlay = client ?: return
        overlay.startScroll()
        Thread {
            for (step in 0..20) {
                overlay.onScroll(step / 20f)
                Thread.sleep(16)
            }
            overlay.endScroll()
        }.start()
    }

    override fun onDestroy() {
        runCatching { client?.windowDetached(false) }
        runCatching { unbindService(connection) }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OverlayHarness"

        // The launcher's own activity-state bits.
        private const val ACTIVITY_STARTED = 1
        private const val ACTIVITY_RESUMED = 2
    }
}
