package io.neiam.apolloscrib.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos

/**
 * A window onto a list, moved along by a timer or by hand.
 *
 * @property window which cards to show, as indices
 * @property progress how far through the current turn, 0..1, or null when
 *   nothing is turning — the compass draws no ring in that case, because a
 *   full circle sitting still would promise a turn that is not coming
 * @property advance move on now, and start the turn again from the top
 */
data class Rotation(
    val window: List<Int>,
    val progress: Float?,
    val advance: () -> Unit
)

/**
 * The rotation for a list of [total] cards showing [size] at a time.
 *
 * One clock for both the moving and the drawing of it. Two would drift — the
 * ring would fill while the cards had already turned, or worse, an advance by
 * hand would leave the countdown where it was and the next card would arrive a
 * moment later.
 *
 * The window moves by **one**: a card slides in at the top and the bottom one
 * falls off, so what you were reading stays put. Wraps, and never moves at all
 * when everything already fits.
 */
@Composable
fun rememberRotation(total: Int, size: Int, intervalMs: Int): Rotation {
    if (total <= 0 || size <= 0) return Rotation(emptyList(), null, {})
    if (total <= size) return Rotation((0 until total).toList(), null, {})

    var first by remember(total, size) { mutableIntStateOf(0) }
    val progress = remember { mutableFloatStateOf(0f) }

    // Bumped by a turn taken by hand. The loop owns the clock -- it is the
    // only thing holding a frame time -- so a flick asks for a reset rather
    // than writing one, which would mean inventing a timestamp from outside
    // the frame callback and getting it wrong by however long the frame was.
    var restarts by remember { mutableIntStateOf(0) }

    LaunchedEffect(total, size, intervalMs) {
        var startedAt = withFrameNanos { it }
        var seen = restarts

        while (true) {
            val now = withFrameNanos { it }

            if (restarts != seen) {
                seen = restarts
                startedAt = now
                progress.floatValue = 0f
                continue
            }

            val elapsed = (now - startedAt) / 1_000_000f

            if (elapsed >= intervalMs) {
                first = (first + 1) % total
                startedAt = now
                progress.floatValue = 0f
            } else {
                progress.floatValue = elapsed / intervalMs
            }
        }
    }

    return Rotation(
        // Modulo the total, so a window running off the end comes back round
        // rather than coming up short. Three cards should be three cards on
        // every turn.
        window = (first until first + size).map { it % total },
        progress = progress.floatValue,
        advance = {
            first = (first + 1) % total
            // The turn starts again, rather than the next card landing
            // however much of the interval happened to be left.
            restarts += 1
        }
    )
}
