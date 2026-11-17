package io.neiam.apolloscrib.ui.shader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

// Robolectric because the palettes are built through android.graphics.Color.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class MotionTest {
    private val qt = File("src/main/assets/field.frag").readText()

    /** Every member of the shader's uniform block (but Qt's own matrix) gets
     * a value: one left out would sit at zero and quietly blank a layer. */
    @Test
    fun everyUniformIsGivenAValue() {
        val block = qt.substringAfter("uniform buf {").substringBefore("};")
        val names = Regex("""^\s*\w+\s+(\w+)\s*;""", RegexOption.MULTILINE)
            .findAll(block).map { it.groupValues[1] }.filter { it != "qt_Matrix" }.toSet()
        val motion = Motion()
        motion.advance(0.0, ShaderSettings(), ShaderColours.forTheme("dark"))
        val given = motion.uniforms(1080, 2400, ShaderSettings()).keys
        assertEquals(names, given)
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

    /** party²'s pattern list, unchanged: the stored keys mean the same there. */
    @Test
    fun thePatternsAreTheServers() {
        assertEquals(
            listOf("both", "moire", "halftone", "bokeh", "stars", "alternate"),
            Patterns.all.map { it.key },
        )
        assertTrue(Patterns.isOn("bokeh"))
        assertTrue(!Patterns.isOn(Patterns.NONE) && !Patterns.isOn(Patterns.OFF) && !Patterns.isOn(null))
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
