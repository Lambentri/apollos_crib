package io.neiam.apolloscrib.feed

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.ui.BoardScreen
import io.neiam.apolloscrib.ui.theme.CribTheme
import io.neiam.apolloscrib.ui.theme.appThemeByKey
import kotlin.math.abs

/**
 * The board, as the page to the left of the home screen.
 *
 * The launcher owns the gesture: it tells us how far the user has dragged and
 * we slide to match. The window is a child of the launcher's own -- added
 * against the token it hands over -- which is what lets a service draw over a
 * launcher at all.
 *
 * Read-only by construction. It draws the same [BoardScreen] the app does and
 * offers no way in: a page you swipe onto by accident should not be able to
 * change anything.
 */
class OverlayPanel(
    private val context: Context,
    private val onScrollSettled: (Float) -> Unit
) {

    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val host = OverlayHost()

    private var view: View? = null
    private var width = 0
    private var animator: ValueAnimator? = null

    /** 0 closed, 1 fully open. What the launcher's drag reports. */
    private var progress = 0f

    val isOpen: Boolean get() = progress > 0.99f

    fun attach(token: IBinder?) {
        if (view != null) return

        val content = ComposeView(context).apply {
            setContent {
                val settings = Settings(context)
                CribTheme(theme = appThemeByKey(settings.themeKey)) {
                    Surface(modifier = Modifier.fillMaxSize()) {
                        Scaffold { padding ->
                            BoardScreen(
                                modifier = Modifier.fillMaxSize().padding(padding),
                                store = VisionStore(context),
                                // No way through to settings from here: the
                                // page is a read-only board.
                                onEditConnection = null
                            )
                        }
                    }
                }
            }
        }

        val root = FrameLayout(context).apply {
            // Explicitly: a FrameLayout child defaults to WRAP_CONTENT, and a
            // page that does not fill its window leaves the strips behind the
            // system bars showing whatever is under it.
            addView(
                content,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )
            // Off screen until the launcher says otherwise.
            alpha = 0f
        }

        host.attachTo(root)
        host.moveTo(Lifecycle.State.STARTED)

        width = context.resources.displayMetrics.widthPixels

        runCatching {
            windowManager.addView(root, layoutParams(token))
            view = root
            root.translationX = -width.toFloat()
        }.onFailure {
            // Loudly: a window that will not attach is the whole feature
            // failing, and it fails silently otherwise -- the launcher goes on
            // scrolling a page that is not there.
            Log.e(TAG, "could not attach the overlay window", it)
            host.moveTo(Lifecycle.State.CREATED)
        }
    }

    /**
     * A window belonging to the launcher's activity.
     *
     * The token is the whole trick: without it this is a window a service is
     * not allowed to add at all, and with it the window manager treats it as
     * the launcher's own.
     *
     * `TYPE_APPLICATION` rather than a sub-window type. What a launcher hands
     * over is `window.attributes.token`, which is its activity's app token,
     * and the sub-window types want the *window* token of a parent window --
     * ask for one with the other and the window manager refuses with
     * "Attempted to add window with token that is not a window".
     */
    private fun layoutParams(token: IBinder?) = WindowManager.LayoutParams().apply {
        this.token = token
        type = WindowManager.LayoutParams.TYPE_APPLICATION
        width = WindowManager.LayoutParams.MATCH_PARENT
        height = WindowManager.LayoutParams.MATCH_PARENT
        format = PixelFormat.TRANSLUCENT
        gravity = Gravity.START or Gravity.TOP
        flags = WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
            // Behind the status and navigation bars rather than between them.
            // A window of this type is otherwise laid out inside the content
            // area, and the wallpaper shows through the strips at top and
            // bottom -- the page reads as a card floating on the home screen
            // instead of as a page.
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            // Without this the system paints its own opaque backgrounds for
            // the status and navigation bars on top of the window -- the
            // frame is already full screen, and the strips came out black
            // anyway. Saying we draw them ourselves is what makes the page's
            // own colour reach the edges. The GSA overlay controller sets the
            // same flag for the same reason.
            WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS or
            // Not focusable: the launcher keeps the key events, and this page
            // has nothing to type into.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            // Starts closed, so starts letting touches through to the launcher.
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        // Into the cutout too, so the notch area is the page's colour and not
        // a black bar.
        layoutInDisplayCutoutMode =
            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Draw behind the bars; the Scaffold inside still keeps the
            // content itself clear of them.
            fitInsetsTypes = 0
        }
    }

    fun detach() {
        animator?.cancel()
        view?.let { runCatching { windowManager.removeView(it) } }
        view = null
        host.destroy()
    }

    /** The launcher is dragging. Follow it exactly rather than animating. */
    fun onScroll(value: Float) {
        animator?.cancel()
        apply(value.coerceIn(0f, 1f))
    }

    /** The drag ended wherever it ended; settle to the nearer edge. */
    fun settle() {
        animateTo(if (progress > 0.5f) 1f else 0f)
    }

    fun open() = animateTo(1f)

    fun close() = animateTo(0f)

    fun onActivityState(state: Int) {
        // Bit 1 is "resumed" in the launcher's own state flags. A launcher
        // that is not on screen does not need this recomposing.
        val resumed = state and 2 != 0
        host.moveTo(if (resumed) Lifecycle.State.RESUMED else Lifecycle.State.STARTED)
    }

    fun onPause() = host.moveTo(Lifecycle.State.STARTED)

    fun onResume() = host.moveTo(Lifecycle.State.RESUMED)

    private fun animateTo(target: Float) {
        val from = progress
        if (abs(from - target) < 0.001f) {
            onScrollSettled(target)
            return
        }
        animator?.cancel()
        animator = ValueAnimator.ofFloat(from, target).apply {
            duration = SETTLE_MS
            addUpdateListener { apply(it.animatedValue as Float) }
            // Told at the end rather than throughout: the launcher moves its
            // own workspace while it is driving, and echoing every frame back
            // makes the two fight.
            addListener(
                object : android.animation.AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        onScrollSettled(target)
                    }
                }
            )
            start()
        }
    }

    private fun apply(value: Float) {
        progress = value
        view?.let { panel ->
            panel.translationX = -width * (1f - value)
            panel.alpha = value
        }
        // The window is full screen whatever the content is doing, so a closed
        // panel goes on swallowing every touch meant for the home screen
        // unless it is made untouchable. Translating the view off screen does
        // not move the window.
        setTouchable(value > 0f)
    }

    private fun setTouchable(touchable: Boolean) {
        val panel = view ?: return
        val params = panel.layoutParams as? WindowManager.LayoutParams ?: return
        val flag = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        val updated = if (touchable) params.flags and flag.inv() else params.flags or flag
        if (updated != params.flags) {
            params.flags = updated
            runCatching { windowManager.updateViewLayout(panel, params) }
        }
    }

    companion object {
        private const val TAG = "OverlayPanel"
        private const val SETTLE_MS = 200L
    }
}
