package io.neiam.apolloscrib.feed

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import com.google.android.libraries.launcherclient.ILauncherOverlay
import com.google.android.libraries.launcherclient.ILauncherOverlayCallback
import io.neiam.apolloscrib.mqtt.AnkyraService

/**
 * The board as a launcher's page to the left of the home screen.
 *
 * Launchers that implement Google's "minus one" gesture -- Lawnchair among
 * them -- bind a service exposing [ILauncherOverlay] and hand it their own
 * window token. This is that service: it means the board is on the home screen
 * with nothing else installed, rather than only through Smartspacer.
 *
 * Everything arrives on a binder thread and every window call has to happen on
 * the main one, so each is posted.
 */
class FeedOverlayService : Service() {

    private val main = Handler(Looper.getMainLooper())
    private var panel: OverlayPanel? = null
    private var callback: ILauncherOverlayCallback? = null

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onDestroy() {
        main.post { panel?.detach(); panel = null }
        super.onDestroy()
    }

    /** Tell the launcher where we ended up, so it can settle its workspace. */
    private fun reportScroll(progress: Float) {
        runCatching { callback?.overlayScrollChanged(progress) }
    }

    private val binder = object : ILauncherOverlay.Stub() {

        override fun windowAttached(
            lp: WindowManager.LayoutParams?,
            cb: ILauncherOverlayCallback?,
            flags: Int
        ) {
            attach(lp?.token, cb)
        }

        override fun windowAttached2(bundle: Bundle?, cb: ILauncherOverlayCallback?) {
            // The newer form: the same LayoutParams, inside a bundle.
            val lp = bundle?.let {
                @Suppress("DEPRECATION")
                it.getParcelable("layout_params") as? WindowManager.LayoutParams
            }
            attach(lp?.token, cb)
        }

        private fun attach(token: IBinder?, cb: ILauncherOverlayCallback?) {
            callback = cb
            main.post {
                panel?.detach()
                panel = OverlayPanel(this@FeedOverlayService, ::reportScroll)
                    .also { it.attach(token) }
                // Bit 0 is the launcher's "this overlay is live" flag; without
                // it Lawnchair ignores every scroll we are sent.
                runCatching { cb?.overlayStatusChanged(STATUS_ATTACHED) }
                // A board nobody has connected shows nothing, so the page is
                // the moment to make sure the subscription is up.
                AnkyraService.resume(this@FeedOverlayService)
                // Swiping onto the page is the same moment as opening the
                // app: whatever is on it should be current.
                AnkyraService.requestBoard(this@FeedOverlayService)
            }
        }

        override fun windowDetached(isChangingConfigurations: Boolean) {
            main.post {
                panel?.detach()
                panel = null
            }
            callback = null
        }

        override fun startScroll() {
            main.post { panel?.onScroll(0f) }
        }

        override fun onScroll(progress: Float) {
            main.post { panel?.onScroll(progress) }
        }

        override fun endScroll() {
            main.post { panel?.settle() }
        }

        override fun openOverlay(flags: Int) {
            main.post { panel?.open() }
        }

        override fun closeOverlay(flags: Int) {
            main.post { panel?.close() }
        }

        override fun onPause() {
            main.post { panel?.onPause() }
        }

        override fun onResume() {
            main.post { panel?.onResume() }
        }

        override fun setActivityState(flags: Int) {
            main.post { panel?.onActivityState(flags) }
        }

        /** Yes: there is always a board to show, even if it is an empty one. */
        override fun hasOverlayContent(): Boolean = true

        // The rest of the interface is Google's search integration, which this
        // has no part of. Answered rather than left to time out.
        override fun requestVoiceDetection(start: Boolean) = Unit
        override fun getVoiceSearchLanguage(): String? = null
        override fun isVoiceDetectionRunning(): Boolean = false
        override fun startSearch(data: ByteArray?, bundle: Bundle?): Boolean = false
        override fun unusedMethod() = Unit
    }

    companion object {
        private const val TAG = "FeedOverlay"

        /** The launcher checks this bit before honouring a scroll. */
        private const val STATUS_ATTACHED = 1
    }
}
