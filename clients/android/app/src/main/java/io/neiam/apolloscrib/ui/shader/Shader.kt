package io.neiam.apolloscrib.ui.shader

/**
 * neiam-device's droid/Shader.kt, unchanged but for its package. The
 * fragment shader is the Plasma wallpaper's moire/shaders/field.frag,
 * packaged unchanged as assets/field.frag (the web's copy is
 * assets/f/js/shaders/field.frag; tests/shader_copies.rs keeps the two the
 * same). It is written for Qt,
 * whose qsb compiles it: Vulkan-style GLSL 440 with its uniforms in a
 * std140 block. This rewrites only that header for OpenGL ES 3.0; the
 * shader body is the same code the desktop runs.
 */
object Shader {

    /** Qt's default ShaderEffect vertex stage, for a full-screen quad. */
    const val VERTEX = """#version 300 es
in vec2 position;
out vec2 qt_TexCoord0;
void main()
{
    // Qt's texture coordinates run top to bottom; GL's clip space runs
    // bottom to top.
    qt_TexCoord0 = vec2(position.x * 0.5 + 0.5, 0.5 - position.y * 0.5);
    gl_Position = vec4(position, 0.0, 1.0);
}
"""

    private val member = Regex("""^\s*(\w+)\s+(\w+)\s*;""")

    fun toGles(qt: String): String {
        // #version goes first: GLSL ES allows comments before it, but not
        // every mobile driver agrees.
        val out = mutableListOf("#version 300 es", "precision highp float;")
        var inBlock = false
        for (line in qt.lines()) {
            val trimmed = line.trim()
            when {
                trimmed.startsWith("#version") -> {}
                trimmed.startsWith("layout(location") -> out += trimmed.substringAfter(")").trim()
                trimmed.startsWith("layout(std140") -> inBlock = true
                inBlock && trimmed.startsWith("};") -> inBlock = false
                inBlock -> member.find(line)?.let {
                    out += "uniform ${it.groupValues[1]} ${it.groupValues[2]};"
                }
                else -> out += line
            }
        }
        require(!inBlock) { "unterminated uniform block" }
        return out.joinToString("\n")
    }
}
