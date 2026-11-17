package io.neiam.apolloscrib.ui.shader

import android.animation.ValueAnimator
import android.opengl.GLSurfaceView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import io.neiam.apolloscrib.ui.theme.AppTheme

/** Frames per second, as the web's background draws (shader_field.js). */
private const val FPS = 30

/**
 * The field, drawn by one GLSurfaceView. A SurfaceView sits behind its
 * window and shows through wherever the window is transparent, so this goes
 * first in a Box and everything above it draws over it as usual.
 *
 * Paced from Compose's frame clock at [FPS] while resumed; paused with the
 * activity, so a phone in a pocket draws nothing. With animations off
 * system-wide it draws one settled frame per change, as the web does for
 * prefers-reduced-motion.
 */
@Composable
fun ShaderBackground(settings: ShaderSettings, theme: AppTheme, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val renderer = remember {
        FieldRenderer(context.assets.open("field.frag").bufferedReader().use { it.readText() })
    }
    var view by remember { mutableStateOf<GLSurfaceView?>(null) }
    val colours = remember(theme) { ShaderColours.forTheme(theme) }
    val still = !ValueAnimator.areAnimatorsEnabled()

    SideEffect {
        renderer.settings = settings
        renderer.colours = colours
        renderer.still = still
    }

    AndroidView(
        factory = { ctx ->
            GLSurfaceView(ctx).apply {
                setEGLContextClientVersion(3)
                preserveEGLContextOnPause = true
                setRenderer(renderer)
                renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
            }.also { view = it }
        },
        modifier = modifier,
    )

    var resumed by remember { mutableStateOf(true) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, view) {
        val v = view
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> { v?.onResume(); resumed = true }
                Lifecycle.Event.ON_PAUSE -> { v?.onPause(); resumed = false }
                else -> {}
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(view, resumed, still, settings, colours) {
        val v = view ?: return@LaunchedEffect
        if (!resumed) return@LaunchedEffect
        if (still) {
            v.requestRender()
            return@LaunchedEffect
        }
        val interval = 1_000_000_000L / FPS - 2_000_000L
        var last = 0L
        while (true) {
            withFrameNanos { now ->
                if (now - last >= interval) {
                    v.requestRender()
                    last = now
                }
            }
        }
    }
}
