package io.neiam.apolloscrib.ui.shader

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * The moving parts of the Bubbles and Absorbing spheres patterns, as the
 * Plasma wallpaper's balls.js (neiam-device's droid/Balls.kt, unchanged
 * but for its package); keep them in step. Both keep their
 * discs in units of the screen's shorter side (as the shaders do), step
 * them with Motion's clock, and hand them over as x, y, radius and a
 * fourth value of their own, for the shaders' ball0-ball47.
 */
object Balls {
    const val MAX = 48

    class Disc(var x: Double, var y: Double, var r: Double, var vx: Double, var vy: Double) {
        /** Bubbles: the film's phase. Spheres: the colour. */
        var extra = 0.0
        var swirl = 0.0
        var gone = false
    }

    /** The discs as the shaders take them, and the whole set's fade. */
    class Packed(val balls: List<FloatArray>, val fade: Double) {
        val count get() = balls.size
    }

    internal fun rand(lo: Double, hi: Double, random: Random) = lo + random.nextDouble() * (hi - lo)

    /** Off the walls: back inside, heading away. */
    internal fun walls(b: Disc, w: Double, h: Double) {
        if (b.x - b.r < 0) { b.x = b.r; b.vx = abs(b.vx) }
        if (b.x + b.r > w) { b.x = w - b.r; b.vx = -abs(b.vx) }
        if (b.y - b.r < 0) { b.y = b.r; b.vy = abs(b.vy) }
        if (b.y + b.r > h) { b.y = h - b.r; b.vy = -abs(b.vy) }
    }

    internal fun launch(w: Double, h: Double, r: Double, speed: Double, random: Random): Disc {
        val a = random.nextDouble() * 2 * PI
        return Disc(
            rand(r, max(r, w - r), random), rand(r, max(r, h - r), random), r,
            speed * cos(a), speed * sin(a),
        )
    }

    private fun pack(list: List<Disc>, fade: Double) = Packed(
        list.take(MAX).map { floatArrayOf(it.x.toFloat(), it.y.toFloat(), it.r.toFloat(), it.extra.toFloat()) },
        fade,
    )

    /**
     * Soap bubbles drifting about, bouncing off the walls and each other
     * (elastic, with mass by area). The fourth value is the phase their
     * film's colours swirl through.
     */
    class Bubbles(private val random: Random = Random.Default) {
        val list = mutableListOf<Disc>()

        fun step(dt: Double, w: Double, h: Double, count: Int) {
            val n = count.coerceIn(1, MAX)
            while (list.size > n) list.removeAt(list.size - 1)
            while (list.size < n) {
                list += launch(w, h, rand(0.035, 0.1, random), rand(0.009, 0.024, random), random).apply {
                    extra = random.nextDouble()
                    swirl = rand(0.02, 0.06, random) * (if (random.nextDouble() < 0.5) -1 else 1)
                }
            }

            for (b in list) {
                b.x += b.vx * dt
                b.y += b.vy * dt
                b.extra = (b.extra + b.swirl * dt + 1) % 1
                walls(b, w, h)
            }
            for (i in list.indices) {
                for (j in i + 1 until list.size) {
                    val a = list[i]
                    val b = list[j]
                    val dx = b.x - a.x
                    val dy = b.y - a.y
                    val dist = hypot(dx, dy).takeIf { it != 0.0 } ?: 1e-6
                    val overlap = a.r + b.r - dist
                    if (overlap <= 0) continue
                    val nx = dx / dist
                    val ny = dy / dist
                    val ma = a.r * a.r
                    val mb = b.r * b.r
                    // Apart, the lighter one moving further.
                    a.x -= nx * overlap * mb / (ma + mb)
                    a.y -= ny * overlap * mb / (ma + mb)
                    b.x += nx * overlap * ma / (ma + mb)
                    b.y += ny * overlap * ma / (ma + mb)
                    // And bounce, if they're closing.
                    val closing = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
                    if (closing > 0) {
                        val ja = 2 * mb * closing / (ma + mb)
                        val jb = 2 * ma * closing / (ma + mb)
                        a.vx -= ja * nx
                        a.vy -= ja * ny
                        b.vx += jb * nx
                        b.vy += jb * ny
                    }
                }
            }
        }

        fun pack() = pack(list, 1.0)
    }

    /**
     * Spheres launched in every direction at their own speeds. They
     * bounce off the walls, but where two meet the larger eats into the
     * smaller: the area the smaller loses the larger gains, with the
     * momentum that came with it, the two just touching, until the
     * smaller is gone. With three left, they hold 4 s, fade out over 2 s,
     * and a new set is launched, fading in over 1.5 s. The fourth value
     * picks each sphere's colour.
     */
    class Absorbers(private val random: Random = Random.Default) {
        enum class State { IN, LIVE, HOLD, OUT }

        var list = mutableListOf<Disc>()
            private set
        var state = State.IN
            private set
        var fade = 0.0
            private set
        private var timer = 0.0
        private var n = 0

        private fun launchAll(w: Double, h: Double, count: Int) {
            n = count
            list = MutableList(count) {
                launch(w, h, rand(0.012, 0.045, random), rand(0.009, 0.03, random), random)
                    .apply { extra = random.nextDouble() }
            }
        }

        fun step(dt: Double, w: Double, h: Double, count: Int) {
            val want = count.coerceIn(4, MAX)
            if (list.isEmpty() || (want != n && state != State.OUT)) {
                launchAll(w, h, want)
                state = State.IN
            }

            for (b in list) {
                b.x += b.vx * dt
                b.y += b.vy * dt
                walls(b, w, h)
            }
            absorb()

            when {
                state == State.IN -> {
                    fade = min(1.0, fade + dt / 1.5)
                    if (fade >= 1) state = State.LIVE
                }
                state == State.LIVE && list.size <= 3 -> {
                    state = State.HOLD
                    timer = 4.0
                }
                state == State.HOLD -> {
                    timer -= dt
                    if (timer <= 0) state = State.OUT
                }
                state == State.OUT -> {
                    fade = max(0.0, fade - dt / 2)
                    if (fade <= 0) {
                        launchAll(w, h, want)
                        state = State.IN
                    }
                }
            }
        }

        internal fun absorb() {
            for (i in list.indices) {
                for (j in i + 1 until list.size) {
                    val a = list[i]
                    val b = list[j]
                    if (a.gone || b.gone) continue
                    val dist = hypot(b.x - a.x, b.y - a.y)
                    if (dist >= a.r + b.r) continue
                    val big = if (a.r >= b.r) a else b
                    val small = if (a.r >= b.r) b else a
                    val area = big.r * big.r + small.r * small.r
                    // The radii that keep the area and just touch: big + small = dist.
                    var grown = (dist + sqrt(max(0.0, 2 * area - dist * dist))) / 2
                    var left = dist - grown
                    if (left < 0.003 || grown >= dist) {
                        grown = sqrt(area)
                        left = 0.0
                        small.gone = true
                    }
                    val before = big.r * big.r
                    val after = grown * grown
                    val taken = after - before
                    big.vx = (before * big.vx + taken * small.vx) / after
                    big.vy = (before * big.vy + taken * small.vy) / after
                    big.r = grown
                    small.r = left
                }
            }
            list.removeAll { it.gone }
        }

        fun pack() = pack(list, fade)
    }
}
