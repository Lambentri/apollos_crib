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


/**
 * Which cards to show right now, as indices into the list.
 *
 * A window of [size] moved along by **one** each turn: a card slides in at the
 * top and the bottom one falls off, so the two you were already reading stay
 * put. Advancing by a whole page instead would replace everything at once, and
 * a card you were halfway through would be gone for no reason you could see.
 *
 * Wraps, and when everything fits it never moves at all — rotating a list that
 * is already whole would take cards away and give them back for nothing.
 */
@Composable
fun rotatingWindow(total: Int, size: Int, intervalMs: Int): List<Int> {
    if (total <= 0 || size <= 0) return emptyList()
    if (total <= size) return (0 until total).toList()

    var first by remember(total, size) { mutableIntStateOf(0) }

    LaunchedEffect(total, size, intervalMs) {
        while (true) {
            kotlinx.coroutines.delay(intervalMs.toLong())
            first = (first + 1) % total
        }
    }

    // Modulo the total, so a window running off the end comes back round
    // rather than coming up short. Three cards should be three cards on every
    // turn.
    return (first until first + size).map { it % total }
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
fun rememberRotationProgress(rotating: Boolean, intervalMs: Int): State<Float?> {
    val progress = remember { mutableFloatStateOf(0f) }
    val result = remember { androidx.compose.runtime.mutableStateOf<Float?>(null) }

    LaunchedEffect(rotating, intervalMs) {
        if (!rotating) {
            result.value = null
            return@LaunchedEffect
        }

        var started = withFrameNanos { it }

        while (true) {
            val now = withFrameNanos { it }
            val elapsed = (now - started) / 1_000_000f

            if (elapsed >= intervalMs) {
                started = now
                progress.floatValue = 0f
            } else {
                progress.floatValue = elapsed / intervalMs
            }

            result.value = progress.floatValue
        }
    }

    return result
}
