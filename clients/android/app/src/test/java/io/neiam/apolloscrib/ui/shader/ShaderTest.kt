package io.neiam.apolloscrib.ui.shader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ShaderTest {
    // Unit tests run from the module directory, android/app; these are the
    // copies the app packages.
    private val names = listOf("field") + Motion.PROGRAMS
    private val qt = names.associateWith { File("src/main/assets/$it.frag").readText() }
    private val gles = qt.mapValues { Shader.toGles(it.value) }

    @Test
    fun headerIsGles() {
        // Kept for inspection, and for checking against a real GLES
        // compiler off-device.
        File("build/shaders").mkdirs()
        for ((name, g) in gles) {
            File("build/shaders/$name-gles.frag").writeText(g)

            assertTrue(name, g.startsWith("#version 300 es\nprecision highp float;\n"))
            assertFalse(name, g.contains("layout("))
            assertFalse(name, g.contains("#version 440"))
            assertTrue(name, g.contains("\nin vec2 qt_TexCoord0;\n"))
            assertTrue(name, g.contains("\nout vec4 fragColor;\n"))
        }
    }

    @Test
    fun everyBlockMemberBecomesAUniform() {
        for ((name, src) in qt) {
            val block = src.substringAfter("uniform buf {").substringBefore("};")
            val members = Regex("""^\s*\w+\s+(\w+)\s*;""", RegexOption.MULTILINE)
                .findAll(block).map { it.groupValues[1] }.toList()
            assertTrue(name, members.containsAll(listOf("size", "tone", "seed")))
            for (m in members) assertTrue("$name: $m", gles.getValue(name).contains(Regex("""uniform \w+ $m;""")))
        }
        assertTrue(gles.getValue("field").contains("uniform vec2 hub;"))
    }

    @Test
    fun discsArriveAsSeparateUniforms() {
        // Qt's ShaderEffect has no array properties, so the discs are
        // ball0-ball47, one each, as Motion.discUniforms sets them.
        val motion = Motion()
        for (name in listOf("bubbles", "spheres")) {
            val g = gles.getValue(name)
            for (i in 0 until Balls.MAX) assertTrue("$name: ball$i", g.contains("uniform vec4 ball$i;"))
            assertFalse(name, g.contains(Regex("""uniform \w+ \w+\[""")))
            assertTrue(name, motion.discUniforms(name, ShaderSettings()).keys.containsAll((0 until Balls.MAX).map { "ball$it" }))
        }
    }

    @Test
    fun everyUniformIsSet() {
        // Every uniform a shader reads is one Motion hands over, so none
        // is left at zero by a misspelling.
        val motion = Motion()
        val s = ShaderSettings()
        motion.advance(0.0, s, listOf(FloatArray(3), FloatArray(3), FloatArray(3), FloatArray(3)))
        val given = motion.uniforms(1920, 1080, s).keys + motion.discUniforms("spheres", s).keys
        for ((name, g) in gles) {
            for (m in Regex("""^uniform \w+ (\w+);""", RegexOption.MULTILINE).findAll(g).map { it.groupValues[1] }) {
                if (m == "qt_Matrix") continue
                assertTrue("$name: $m", m in given)
            }
        }
    }

    @Test
    fun bodyIsUntouched() {
        for ((name, src) in qt) assertEquals(name, src.substringAfter("void main()"), gles.getValue(name).substringAfter("void main()"))
    }
}
