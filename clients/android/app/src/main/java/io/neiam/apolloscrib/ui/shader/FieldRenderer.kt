package io.neiam.apolloscrib.ui.shader

import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Draws the field: neiam-device's droid/FieldRenderer.kt without the
 * wordmark or the sun. Runs on GLSurfaceView's thread; [settings],
 * [colours] and [still] are written from the UI thread and read each frame.
 *
 * A shader that fails to compile clears to the theme's ground instead of
 * throwing: on the GL thread an exception takes the whole app down, and a
 * plain background is a fine way for a decoration to fail.
 */
class FieldRenderer(private val fragmentSource: String) : GLSurfaceView.Renderer {
    @Volatile var settings = ShaderSettings()
    @Volatile var colours: List<FloatArray> = ShaderColours.forTheme("dark")

    /** Animations are off system-wide: draw each frame as if settled. */
    @Volatile var still = false

    private val motion = Motion()
    private var program = 0
    private val uniforms = HashMap<String, Int>()
    private var width = 0
    private var height = 0
    private var lastFrame = 0L

    private val quad = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
        .apply { put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)); position(0) }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        uniforms.clear()
        lastFrame = 0
        program = try {
            link(Shader.VERTEX, Shader.toGles(fragmentSource))
        } catch (e: RuntimeException) {
            Log.e(TAG, "shader background disabled", e)
            0
        }
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        width = w
        height = h
        GLES30.glViewport(0, 0, w, h)
    }

    override fun onDrawFrame(gl: GL10?) {
        val now = System.nanoTime()
        val dt = when {
            still -> 10.0
            lastFrame == 0L -> 0.0
            else -> (now - lastFrame) / 1e9
        }
        lastFrame = now
        val s = settings
        motion.advance(dt, s, colours)

        if (program == 0) {
            val c = motion.base
            GLES30.glClearColor(c[0], c[1], c[2], 1f)
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
            return
        }
        GLES30.glUseProgram(program)
        for ((name, v) in motion.uniforms(width, height, s)) {
            val at = uniforms.getOrPut(name) { GLES30.glGetUniformLocation(program, name) }
            if (at < 0) continue
            when (v.size) {
                1 -> GLES30.glUniform1f(at, v[0])
                2 -> GLES30.glUniform2f(at, v[0], v[1])
                4 -> GLES30.glUniform4f(at, v[0], v[1], v[2], v[3])
            }
        }
        val at = GLES30.glGetAttribLocation(program, "position")
        GLES30.glEnableVertexAttribArray(at)
        GLES30.glVertexAttribPointer(at, 2, GLES30.GL_FLOAT, false, 0, quad)
        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        GLES30.glDisableVertexAttribArray(at)
    }

    private fun link(vertex: String, fragment: String): Int {
        fun compile(type: Int, src: String): Int {
            val shader = GLES30.glCreateShader(type)
            GLES30.glShaderSource(shader, src)
            GLES30.glCompileShader(shader)
            val ok = IntArray(1).also { GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, it, 0) }
            if (ok[0] == 0) error("shader failed to compile: ${GLES30.glGetShaderInfoLog(shader)}")
            return shader
        }
        val p = GLES30.glCreateProgram()
        GLES30.glAttachShader(p, compile(GLES30.GL_VERTEX_SHADER, vertex))
        GLES30.glAttachShader(p, compile(GLES30.GL_FRAGMENT_SHADER, fragment))
        GLES30.glLinkProgram(p)
        val ok = IntArray(1).also { GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, it, 0) }
        if (ok[0] == 0) error("program failed to link: ${GLES30.glGetProgramInfoLog(p)}")
        return p
    }

    companion object {
        private const val TAG = "apollos-shader"
    }
}
