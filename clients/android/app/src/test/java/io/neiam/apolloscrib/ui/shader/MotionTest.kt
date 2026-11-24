package io.neiam.apolloscrib.ui.shader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import kotlin.math.PI

// Robolectric because the palettes are built through android.graphics.Color.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MotionTest {
    private val qt = File("src/main/assets/field.frag").readText()

    /** Every member of the field's uniform block (but Qt's own matrix) gets
     * a value: one left out would sit at zero and quietly blank a layer.
     * The rest are the own-shader patterns' (ShaderTest.everyUniformIsSet). */
    @Test
    fun everyUniformIsGivenAValue() {
        val block = qt.substringAfter("uniform buf {").substringBefore("};")
        val names = Regex("""^\s*\w+\s+(\w+)\s*;""", RegexOption.MULTILINE)
            .findAll(block).map { it.groupValues[1] }.filter { it != "qt_Matrix" }.toSet()
        val motion = Motion()
        motion.advance(0.0, ShaderSettings(), ShaderColours.forTheme("dark"))
        val given = motion.uniforms(1080, 2400, ShaderSettings()).keys
        assertTrue((names - given).toString(), given.containsAll(names))
    }

    @Test
    fun eachPatternShowsItsLayers() {
        val motion = Motion()
        fun shown(pattern: String) =
            Motion.LAYERS.filter { motion.amount(it, ShaderSettings(pattern = pattern)) == 1.0 }.toSet()
        assertEquals(setOf("moire", "halftone"), shown("both"))
        assertEquals(setOf("bokeh"), shown("bokeh"))
        assertEquals(setOf("stars"), shown("stars"))
        assertEquals(emptySet<String>(), shown(Patterns.OFF))
    }

    /** A pattern change fades in over 1.5 s rather than cutting. */
    @Test
    fun aNewPatternEasesIn() {
        val motion = Motion()
        val colours = ShaderColours.forTheme("light")
        motion.advance(0.0, ShaderSettings(pattern = "bokeh"), colours)
        motion.advance(0.1, ShaderSettings(pattern = "stars"), colours)
        val stars = motion.uniforms(100, 100, ShaderSettings())["stars"]!![0]
        assertTrue("stars should be partway in, was $stars", stars > 0f && stars < 1f)
    }

    /** party²'s pattern list, so the stored keys mean the same there, and
     * the wallpaper's own-shader patterns before Alternate. */
    @Test
    fun thePatternsAreTheServers() {
        assertEquals(
            listOf("both", "moire", "halftone", "bokeh", "stars") + Motion.PROGRAMS + "alternate",
            Patterns.all.map { it.key },
        )
        assertTrue(Patterns.isOn("bokeh"))
        assertTrue(!Patterns.isOn(Patterns.NONE) && !Patterns.isOn(Patterns.OFF) && !Patterns.isOn(null))
    }

    private fun turned(motion: Motion, s: ShaderSettings, seconds: Double): Pair<Double, Double> {
        val colours = ShaderColours.forTheme("dark")
        val spin0 = motion.spin
        val rays0 = motion.rayTurn
        repeat((seconds / 0.25).toInt()) { motion.advance(0.25, s, colours) }
        fun delta(a: Double, b: Double) = ((b - a) % (2 * PI) + 2 * PI) % (2 * PI)
        return delta(spin0, motion.spin) to delta(rays0, motion.rayTurn)
    }

    @Test
    fun prismTurnsAStepEvery15s() {
        // A triangle's side and one of seven rays' spacing, per 15 s.
        val (spin, rays) = turned(Motion(), ShaderSettings(pattern = "prism"), 15.0)
        assertEquals(2 * PI / 3, spin, 1e-9)
        assertEquals(2 * PI / 7, rays, 1e-9)
    }

    @Test
    fun prismSlowSpinsSteadily() {
        val (spin, rays) = turned(Motion(), ShaderSettings(pattern = "prism", prismSlow = true), 30.0)
        assertEquals(2 * PI * 30 / 120, spin, 1e-9)
        assertEquals(2 * PI * 30 / 160, rays, 1e-9)
    }

    @Test
    fun ownShaderPatternsFadeOverTheField() {
        val motion = Motion()
        val s = ShaderSettings(pattern = "oil")
        val colours = ShaderColours.forTheme("dark")
        motion.advance(0.0, ShaderSettings(), colours)
        repeat(4) { motion.advance(0.25, s, colours) }
        assertEquals(1.0 / 1.5, motion.shown("oil"), 1e-9)
        repeat(4) { motion.advance(0.25, s, colours) }
        assertEquals(1.0, motion.shown("oil"), 0.0)
        assertEquals(0.0, motion.shown("prism"), 0.0)
        assertEquals("field", Motion.program(ShaderSettings(pattern = "bokeh")))
        assertEquals("oil", Motion.program(s))
    }

    /** Held still, a round of spheres shows as it is rather than faded out. */
    @Test
    fun stillSpheresAreNotFaded() {
        val motion = Motion()
        val s = ShaderSettings(pattern = "spheres")
        motion.advance(10.0, s, ShaderColours.forTheme("dark"))
        assertEquals(1f, motion.discUniforms("spheres", s, still = true)["fade"]!![0], 0f)
        assertTrue(motion.discUniforms("spheres", s)["fade"]!![0] < 1f)
        assertTrue(motion.discUniforms("spheres", s)["count"]!![0] in 4f..32f)
    }

    /** Every palette gets four shader colours, hand-tuned or derived. */
    @Test
    fun everyThemeHasShaderColours() {
        for (theme in io.neiam.apolloscrib.ui.theme.ALL_THEMES) {
            val c = ShaderColours.forTheme(theme)
            assertEquals(theme.key, 4, c.size)
            assertTrue(theme.key, c.all { rgb -> rgb.size == 3 && rgb.all { it in 0f..1f } })
        }
    }
}
