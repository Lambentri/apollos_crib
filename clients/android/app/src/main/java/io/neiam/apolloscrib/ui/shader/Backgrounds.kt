package io.neiam.apolloscrib.ui.shader

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import io.neiam.apolloscrib.data.BackgroundStore

/**
 * The background this phone draws, and the way to change it.
 *
 * party²'s holder without its per-party override: there a party can bring a
 * background of its own, and here there is only the one board.
 */
@Stable
class Backgrounds(private val store: BackgroundStore?) {
    var mine by mutableStateOf(store?.load() ?: ShaderSettings(pattern = Patterns.OFF))
        private set

    val isOn: Boolean get() = Patterns.isOn(mine.pattern)

    fun update(settings: ShaderSettings) {
        mine = settings
        store?.save(settings)
    }
}

/** Null-store default: off, and changes go nowhere. The feed panel gets this. */
val LocalBackgrounds = staticCompositionLocalOf { Backgrounds(null) }
