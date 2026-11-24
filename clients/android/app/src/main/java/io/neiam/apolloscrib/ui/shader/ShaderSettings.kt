package io.neiam.apolloscrib.ui.shader

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import io.neiam.apolloscrib.ui.theme.AppTheme
import io.neiam.apolloscrib.ui.theme.appThemeByKey

/**
 * The background's settings, as the web keeps them per browser
 * (shader_background.js, the "app:shader" key): a pattern, "off" for
 * none, and the effects. Same names and defaults as the Plasma wallpaper's
 * settings; bokeh until somebody picks, as on the web.
 */
data class ShaderSettings(
    val pattern: String = DEFAULT_PATTERN,
    val fadeFrom: String = "moire",
    val fadeTo: String = "halftone",
    val lights: Int = 14,
    /** Prism: the beam's heading in degrees, 0 = rightward. */
    val prismAngle: Int = 20,
    /** Prism: the shape's sides, 0 for a circle, else 3 to 8. */
    val prismSides: Int = 3,
    val prismRays: Int = 7,
    /** Prism: a steady spin rather than a turn every 15 s. */
    val prismSlow: Boolean = false,
    /** Oil on glass: how much of the glass the slicks cover, percent. */
    val oilCoverage: Int = 50,
    val bubbleCount: Int = 12,
    /** Absorbing spheres: how many each round launches. */
    val sphereCount: Int = 32,
    val speed: Double = 1.0,
    val glints: Boolean = false,
    val breathing: Boolean = false,
    val foreground: Boolean = false,
    val grain: Boolean = false,
    val dither: Boolean = true,
    /** Animate even with animations off system-wide (otherwise one still frame). */
    val alwaysMove: Boolean = false,
) {
    companion object {
        const val DEFAULT_PATTERN = "bokeh"
    }
}

/**
 * A pattern the shader can draw: party²'s EventBackground, less none, and
 * the wallpaper's patterns with shaders of their own.
 */
data class Pattern(val key: String, val label: String, val about: String)

object Patterns {
    /** The viewer's "no background". */
    const val OFF = "off"

    /** A party's "no background of its own". */
    const val NONE = "none"

    /**
     * In EventBackground's order (party²'s src/entities/enums.rs), with its
     * words; the four drawn by shaders of their own (Motion.PROGRAMS) go
     * before Alternate, as neiam-org's shaders page and the Plasma wallpaper
     * list them. Only this phone stores these keys.
     */
    val all = listOf(
        Pattern("both", "Moire + Halftone", "The wallpaper's default: rings and dots together, fading out from a drifting hub."),
        Pattern("moire", "Moire", "Two ring families slightly apart; where they interleave and coincide, the moire beats."),
        Pattern("halftone", "Halftone", "Dots on a rotated grid, sized as in print by the fade and a travelling wave."),
        Pattern("bokeh", "Bokeh", "Soft out-of-focus discs drifting upward, fading in and out as they rise, each its own shade."),
        Pattern("stars", "Starfield", "Sparse stars, mostly faint and a few bright, each twinkling at its own rate."),
        Pattern("prism", "Prism", "A glowing beam strikes a turning shape and splits into rays, each its own width, slowly swelling and thinning."),
        Pattern("oil", "Oil on glass", "Slicks of oil on dark glass, their colours the bands of a thin film, swirling slowly."),
        Pattern("bubbles", "Bubbles", "Soap bubbles drifting about and bouncing off the edges and each other, their films swirling."),
        Pattern("spheres", "Absorbing spheres", "Spheres launched every which way; where two meet, the larger absorbs the smaller. At three, a new round."),
        Pattern("alternate", "Alternate", "Fades back and forth between moire and halftone every few minutes."),
    )

    fun isOn(key: String?): Boolean = all.any { it.key == key }

    /** The prism's shapes, by their number of sides. */
    val shapes = listOf(
        0 to "Circle", 3 to "Triangle", 4 to "Square", 5 to "Pentagon",
        6 to "Hexagon", 7 to "Heptagon", 8 to "Octagon",
    )

    fun label(key: String?): String = all.firstOrNull { it.key == key }?.label ?: "Off"
}

/**
 * neiam-device's themes (droid/Themes.kt, generated from waxx): ground,
 * ground at the edges, moire, halftone, as the web's shader_field.js has
 * them.
 *
 * Only light, dark and blueprint are the same palettes here as in party²;
 * this app's "Her" is the Scribus routes' oklch one rather than the web's
 * hex, and Forest, Sky and the rest have no shader colours anywhere. Those
 * are derived from the palette the same way the four above relate to theirs:
 * the ground, the ground darkened toward the edges, the accent for the rings
 * and the primary for the dots.
 */
object ShaderColours {
    private val themes = mapOf(
        "dark" to listOf(0x292F37, 0x13171C, 0xD16671, 0xB6797A),
        "light" to listOf(0xFEF6F6, 0xF3DFDD, 0x000000, 0xB6797A),
        "blueprint" to listOf(0x002661, 0x001241, 0xFDF2C6, 0x0E9DFF),
    )

    private fun rgb(c: Int) =
        floatArrayOf(((c shr 16) and 0xFF) / 255f, ((c shr 8) and 0xFF) / 255f, (c and 0xFF) / 255f)

    private fun rgb(c: Color) = floatArrayOf(c.red, c.green, c.blue)

    /** Four colours, each `[r, g, b]` from 0 to 1. */
    fun forTheme(theme: AppTheme): List<FloatArray> =
        themes[theme.key]?.map(::rgb) ?: listOf(
            rgb(theme.bg),
            rgb(lerp(theme.bg, if (theme.isLight) theme.dim else Color.Black, 0.45f)),
            rgb(theme.accent),
            rgb(theme.primary),
        )

    /** By key, for the tests; an unknown key draws in the first palette. */
    fun forTheme(key: String): List<FloatArray> = forTheme(appThemeByKey(key))
}
