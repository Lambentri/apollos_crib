package io.neiam.apolloscrib.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos

/** How long one page of cards stays before the next takes its place. */
const val ROTATION_MS = 12_000L

/**
 * Which cards to show right now, as indices into the list.
 *
 * A window of [size] moved along by [size] each turn, so every route gets its
 * turn rather than the first few holding the screen for ever. Wraps, and when
 * everything fits it never moves at all — rotating a list that is already
 * whole would take cards away and give them back for no reason.
 */
@Composable
fun rotatingWindow(total: Int, size: Int): List<Int> {
    if (total <= 0 || size <= 0) return emptyList()
    if (total <= size) return (0 until total).toList()

    val pages = (total + size - 1) / size
    var page by remember(total, size) { mutableIntStateOf(0) }

    LaunchedEffect(total, size) {
        while (true) {
            kotlinx.coroutines.delay(ROTATION_MS)
            page = (page + 1) % pages
        }
    }

    // Taken modulo the total rather than truncated, so a last page with room
    // to spare is filled from the front instead of coming up short. Three
    // cards should be three cards on every turn.
    val start = page * size
    return (start until start + size).map { it % total }
}

/**
 * How far through the current turn, 0 to 1, or null when nothing is rotating.
 *
 * Advanced per frame rather than by a timer, so the ring it draws moves
 * smoothly instead of stepping. Null is what tells the compass to draw no ring
 * at all: a full circle sitting still would say a turn is about to happen when
 * none is.
 */
@Composable
fun rememberRotationProgress(rotating: Boolean): State<Float?> {
    val progress = remember { mutableFloatStateOf(0f) }
    val result = remember { androidx.compose.runtime.mutableStateOf<Float?>(null) }

    LaunchedEffect(rotating) {
        if (!rotating) {
            result.value = null
            return@LaunchedEffect
        }

        var started = withFrameNanos { it }

        while (true) {
            val now = withFrameNanos { it }
            val elapsed = (now - started) / 1_000_000f

            if (elapsed >= ROTATION_MS) {
                started = now
                progress.floatValue = 0f
            } else {
                progress.floatValue = elapsed / ROTATION_MS
            }

            result.value = progress.floatValue
        }
    }

    return result
}
