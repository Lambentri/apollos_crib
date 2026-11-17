package io.neiam.apolloscrib.ui.shader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ShaderTest {
    // Unit tests run from the module directory, android/app; this is the
    // copy the app packages.
    private val qt = File("src/main/assets/field.frag").readText()
    private val gles = Shader.toGles(qt)

    @Test
    fun headerIsGles() {
        // Kept for inspection, and for checking against a real GLES
        // compiler off-device.
        File("build/shaders").mkdirs()
        File("build/shaders/field-gles.frag").writeText(gles)

        assertTrue(gles.startsWith("#version 300 es\nprecision highp float;\n"))
        assertFalse(gles.contains("layout("))
        assertFalse(gles.contains("#version 440"))
        assertTrue(gles.contains("\nin vec2 qt_TexCoord0;\n"))
        assertTrue(gles.contains("\nout vec4 fragColor;\n"))
    }

    @Test
    fun everyBlockMemberBecomesAUniform() {
        val block = qt.substringAfter("uniform buf {").substringBefore("};")
        val names = Regex("""^\s*\w+\s+(\w+)\s*;""", RegexOption.MULTILINE)
            .findAll(block).map { it.groupValues[1] }.toList()
        assertTrue(names.containsAll(listOf("size", "hub", "moire", "tone", "seed")))
        for (name in names) assertTrue(name, gles.contains(Regex("""uniform \w+ $name;""")))
    }

    @Test
    fun bodyIsUntouched() {
        assertEquals(qt.substringAfter("void main()"), gles.substringAfter("void main()"))
    }
}
