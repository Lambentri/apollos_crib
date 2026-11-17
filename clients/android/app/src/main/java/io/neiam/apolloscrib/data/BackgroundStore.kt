package io.neiam.apolloscrib.data

import android.content.Context
import androidx.core.content.edit
import io.neiam.apolloscrib.ui.shader.Patterns
import io.neiam.apolloscrib.ui.shader.ShaderSettings

/**
 * This phone's shader background, ported from party²'s store of the same
 * name and kept in the same preferences as [Settings].
 *
 * Off until somebody picks a pattern. party² defaults to bokeh, but this app
 * is as often a panel left on a wall as a phone in a hand, and thirty frames
 * a second of GPU nobody asked for is the wrong thing to turn on by update.
 */
class BackgroundStore(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences("apollos_crib", Context.MODE_PRIVATE)

    fun load(): ShaderSettings {
        val d = ShaderSettings()
        return ShaderSettings(
            // A pattern since dropped falls back to off, not to a surprise.
            pattern = prefs.getString(PATTERN, null)
                ?.takeIf { it == Patterns.OFF || Patterns.isOn(it) } ?: Patterns.OFF,
            lights = prefs.getInt(LIGHTS, d.lights).coerceIn(4, 64),
            speed = prefs.getFloat(SPEED, d.speed.toFloat()).toDouble().coerceIn(0.25, 4.0),
            glints = prefs.getBoolean(GLINTS, d.glints),
            breathing = prefs.getBoolean(BREATHING, d.breathing),
            foreground = prefs.getBoolean(FOREGROUND, d.foreground),
            grain = prefs.getBoolean(GRAIN, d.grain),
            dither = prefs.getBoolean(DITHER, d.dither),
        )
    }

    fun save(s: ShaderSettings) = prefs.edit {
        putString(PATTERN, s.pattern)
        putInt(LIGHTS, s.lights)
        putFloat(SPEED, s.speed.toFloat())
        putBoolean(GLINTS, s.glints)
        putBoolean(BREATHING, s.breathing)
        putBoolean(FOREGROUND, s.foreground)
        putBoolean(GRAIN, s.grain)
        putBoolean(DITHER, s.dither)
    }

    private companion object {
        const val PATTERN = "shader_pattern"
        const val LIGHTS = "shader_lights"
        const val SPEED = "shader_speed"
        const val GLINTS = "shader_glints"
        const val BREATHING = "shader_breathing"
        const val FOREGROUND = "shader_foreground"
        const val GRAIN = "shader_grain"
        const val DITHER = "shader_dither"
    }
}
