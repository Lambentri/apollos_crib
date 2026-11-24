package io.neiam.apolloscrib.ui.shader

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign
import kotlin.math.sin

/**
 * Everything that moves: neiam-device's droid/Motion.kt (itself a port of
 * the Plasma wallpaper's Field.qml), as the web's shader_field.js has it —
 * without following the sun, with colours handed in rather than scheduled,
 * and with the web's zoom for surfaces smaller than a screen. It advances in
 * double precision and hands the shader positions and wrapped phases, never
 * a raw clock.
 *
 * Pattern amounts ease over 1.5 s and colours over 4 s, so a change of
 * pattern or theme fades rather than cuts. The patterns with shaders of
 * their own ([PROGRAMS]) fade in over the layered one the same way, as
 * [shown] amounts; their motion (the prism's turns, the discs) is
 * droid/Motion.kt's and Balls.kt's, unchanged.
 */
class Motion {
    /** Seconds of motion so far, scaled by speed; a random start. */
    var clock = Math.random() * 10000
        private set
    private var frame = 0

    private val eased = HashMap<String, Double>()
    private var colours: List<FloatArray>? = null
    private var from: List<FloatArray> = emptyList()
    private var to: List<FloatArray> = emptyList()
    private var t = 1.0

    /** Prism's turns, in radians. Accumulated rather than taken from
     * the clock, so switching between the two motions carries on from
     * where they are. */
    var spin = Math.random() * 2 * PI
        private set
    var rayTurn = Math.random() * 2 * PI
        private set
    private var stepClock = 0.0

    private val bubbles = Balls.Bubbles()
    private val spheres = Balls.Absorbers()
    // Each as last stepped, kept while its pattern fades out.
    private var bubbleDiscs = Balls.Packed(emptyList(), 1.0)
    private var sphereDiscs = Balls.Packed(emptyList(), 0.0)

    // The surface's size in the shader's units, as last drawn.
    private var extentX = 16.0 / 9
    private var extentY = 1.0

    private fun sweep(period: Double, phase: Double) = sin(2 * PI * (clock / period + phase))

    /** How much of each own-shader pattern shows, 0-1, by name. */
    fun shown(program: String) = eased[program] ?: 0.0

    private fun layerOf(name: String, layer: String): Double =
        if (layer == name || (name == "both" && (layer == "moire" || layer == "halftone"))) 1.0 else 0.0

    internal fun amount(layer: String, s: ShaderSettings): Double =
        if (s.pattern == "alternate") {
            val t = 0.5 + 0.5 * sweep(360.0, 0.0)
            layerOf(s.fadeFrom, layer) * (1 - t) + layerOf(s.fadeTo, layer) * t
        } else {
            layerOf(s.pattern, layer)
        }

    private fun ease(key: String, target: Double, dt: Double, seconds: Double = 1.5) {
        val now = eased[key] ?: target
        val step = dt / seconds
        eased[key] = if (abs(target - now) <= step) target else now + sign(target - now) * step
    }

    fun advance(dt: Double, s: ShaderSettings, target: List<FloatArray>) {
        val step = s.speed * min(dt, 0.25)
        clock += step
        frame = (frame + 1) % 100000

        // Slow spin: a steady turn, the shape every 2 min and the rays
        // every 160 s. Otherwise both hold still, then every 15 s turn one
        // step (a side of the shape, one ray's spacing) over 2 s, eased.
        val tau = 2 * PI
        if (s.prismSlow) {
            spin = (spin + tau * step / 120) % tau
            rayTurn = (rayTurn + tau * step / 160) % tau
        } else {
            fun steps(t: Double): Double {
                val f = min(1.0, (t % 15) / 2)
                return floor(t / 15) + f * f * (3 - 2 * f)
            }
            val before = steps(stepClock)
            stepClock += step
            val moved = steps(stepClock) - before
            spin = (spin + moved * tau / (if (s.prismSides >= 3) s.prismSides else 6)) % tau
            rayTurn = (rayTurn + moved * tau / max(1, s.prismRays)) % tau
        }
        // Stepped even by nothing, so a still frame has its discs.
        val program = program(s)
        if (program == "bubbles") {
            bubbles.step(step, extentX, extentY, s.bubbleCount)
            bubbleDiscs = bubbles.pack()
        } else if (program == "spheres") {
            spheres.step(step, extentX, extentY, s.sphereCount)
            sphereDiscs = spheres.pack()
        }

        val current = colours
        if (current == null) {
            colours = target
            to = target
        } else if (!same(target, to)) {
            from = current
            to = target
            t = 0.0
        }
        if (t < 1) {
            t = min(1.0, t + dt / 4)
            val k = t.toFloat()
            colours = from.zip(to) { a, b -> FloatArray(3) { a[it] + (b[it] - a[it]) * k } }
        }

        // While alternating the amounts are already continuous, and easing
        // them would only make them lag.
        val direct = s.pattern == "alternate"
        for (layer in LAYERS) {
            val a = amount(layer, s)
            if (direct) eased[layer] = a else ease(layer, a, dt)
        }
        for (p in PROGRAMS) ease(p, if (program == p) 1.0 else 0.0, dt)
        ease("flare", if (s.foreground) 1.0 else 0.0, dt)
        ease("glints", if (s.glints) 1.0 else 0.0, dt)
        ease("grain", if (s.grain) 1.0 else 0.0, dt)
        ease("breathe", if (s.breathing) 1.0 else 0.0, dt)
    }

    /** Where the surface's size is known before the first frame. */
    fun resize(width: Int, height: Int) {
        val shorter = max(1, min(width, height)).toDouble()
        extentX = width / shorter
        extentY = height / shorter
    }

    /** The shader's uniforms for a surface of this size, by name. */
    fun uniforms(width: Int, height: Int, s: ShaderSettings): Map<String, FloatArray> {
        val c = colours ?: return emptyMap()
        val shorter = max(1, min(width, height)).toDouble()
        // The rings and dots are sized for a full screen (~1000 px on the
        // short side); on anything much smaller they fall below a pixel apart
        // and blur into a glow, so scale them up to keep their look.
        val zoom = min(6.0, max(1.0, 1000 / shorter))
        resize(width, height)
        val ex = extentX
        val ey = extentY
        val hub = doubleArrayOf(0.62 * ex + 0.05 * sweep(97.0, 0.0), 0.46 * ey + 0.04 * sweep(131.0, 0.3))
        val spread = 0.03 * (1 + 0.35 * sweep(71.0, 0.1))
        val turn = 2 * PI * clock / 53
        val breathe = eased["breathe"] ?: 0.0

        fun f(vararg v: Double) = FloatArray(v.size) { v[it].toFloat() }
        fun rgba(x: FloatArray) = floatArrayOf(x[0], x[1], x[2], 1f)

        return mapOf(
            "qt_Opacity" to f(1.0),
            "size" to f(width.toDouble(), height.toDouble()),
            "hub" to f(hub[0], hub[1]),
            "ringA" to f(hub[0] - spread * cos(turn) / 2, hub[1] - spread * sin(turn) / 2),
            "ringB" to f(hub[0] + spread * cos(turn) / 2, hub[1] + spread * sin(turn) / 2),
            "reach" to f(0.95 + 0.06 * sweep(43.0, 0.7) + 0.08 * breathe * sweep(16.0, 0.0)),
            "period" to f(zoom / 110),
            "moire" to f(eased["moire"] ?: 0.0),
            "halftone" to f(eased["halftone"] ?: 0.0),
            "cell" to f(zoom / 70),
            "angle" to f(0.26 + 0.03 * sweep(211.0, 0.2)),
            "wave" to f((2 * PI * clock / 16) % (2 * PI)),
            "bokeh" to f(eased["bokeh"] ?: 0.0),
            "lights" to f(s.lights.toDouble()),
            "flare" to f(eased["flare"] ?: 0.0),
            "drift" to f((clock / 600) % 1),
            "stars" to f(eased["stars"] ?: 0.0),
            "twinkle" to f((clock / 12) % 1),
            "glints" to f(eased["glints"] ?: 0.0),
            "glintPhase" to f((clock / 90) % 1),
            "breath" to f(1 - 0.2 * breathe * (0.5 - 0.5 * sweep(16.0, 0.0))),
            "grain" to f(eased["grain"] ?: 0.0),
            "dither" to f(if (s.dither) 1.0 else 0.0),
            "seed" to f((frame * 0.618034) % 1),
            "base" to rgba(c[0]),
            "deep" to rgba(c[1]),
            "ink" to rgba(c[2]),
            "tone" to rgba(c[3]),
            // Prism
            "centre" to f(0.5 * ex + 0.03 * sweep(97.0, 0.0), 0.5 * ey + 0.03 * sweep(131.0, 0.3)),
            "radius" to f(0.15),
            "sides" to f(s.prismSides.toDouble()),
            "spin" to f(spin),
            "beamAngle" to f(s.prismAngle * PI / 180),
            "rays" to f(s.prismRays.toDouble()),
            "rayTurn" to f(rayTurn),
            "cycle" to f((clock / 900) % 1),
            // Oil on glass
            "oilCycle" to f((clock / 240) % 1),
            "coverage" to f(s.oilCoverage / 100.0),
        )
    }

    /** The discs' uniforms for bubbles.frag or spheres.frag: ball0-ball47,
     * count and (spheres) fade. Unused slots are zero. Held [still], a
     * round never fades in, so it shows as it is. */
    fun discUniforms(program: String, s: ShaderSettings, still: Boolean = false): Map<String, FloatArray> {
        val packed = if (program == "spheres") sphereDiscs else bubbleDiscs
        val out = HashMap<String, FloatArray>()
        for (i in 0 until Balls.MAX) out["ball$i"] = packed.balls.getOrNull(i) ?: FloatArray(4)
        out["count"] = floatArrayOf(packed.count.toFloat())
        out["fade"] = floatArrayOf(if (s.speed > 0 && !still) packed.fade.toFloat() else 1f)
        return out
    }

    /** The settled ground colour, for clearing when the shader can't run. */
    val base: FloatArray get() = colours?.get(0) ?: floatArrayOf(0f, 0f, 0f)

    private fun same(a: List<FloatArray>, b: List<FloatArray>) =
        a.size == b.size && a.indices.all { a[it].contentEquals(b[it]) }

    companion object {
        val LAYERS = listOf("moire", "halftone", "bokeh", "stars")

        /** Patterns drawn by a shader of their own, over field.frag. */
        val PROGRAMS = listOf("prism", "oil", "bubbles", "spheres")

        /** Which shader draws the pattern: "field" for the layered ones. */
        fun program(s: ShaderSettings) = if (s.pattern in PROGRAMS) s.pattern else "field"
    }
}
