package io.neiam.apolloscrib.ui.shader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class BallsTest {
    private val w = 16.0 / 9
    private val h = 1.0

    @Test
    fun bubblesKeepTheirCountAndStayInside() {
        val b = Balls.Bubbles(Random(1))
        repeat(2000) { b.step(1.0 / 30, w, h, 12) }
        assertEquals(12, b.list.size)
        for (d in b.list) {
            assertTrue(d.x >= d.r - 1e-9 && d.x <= w - d.r + 1e-9)
            assertTrue(d.y >= d.r - 1e-9 && d.y <= h - d.r + 1e-9)
            assertTrue(d.extra in 0.0..1.0)
        }
        b.step(0.0, w, h, 5)
        assertEquals(5, b.pack().count)
    }

    @Test
    fun absorbingKeepsAreaAndMomentum() {
        val a = Balls.Absorbers(Random(2))
        a.step(0.0, w, h, 4)
        a.list.clear()
        a.list += Balls.Disc(0.5, 0.5, 0.1, 0.01, 0.0)
        a.list += Balls.Disc(0.62, 0.5, 0.05, -0.02, 0.01)
        fun area() = a.list.sumOf { it.r * it.r }
        fun momentum() = a.list.sumOf { it.r * it.r * it.vx } to a.list.sumOf { it.r * it.r * it.vy }
        val (area0, p0) = area() to momentum()
        a.absorb()
        assertEquals(area0, area(), 1e-12)
        assertEquals(p0.first, momentum().first, 1e-12)
        assertEquals(p0.second, momentum().second, 1e-12)
        // Just touching now.
        val (big, small) = a.list
        assertEquals(0.12, big.r + small.r, 1e-9)
        assertTrue(big.r > 0.1)
    }

    @Test
    fun roundsEndAtThreeAndStartAgain() {
        val a = Balls.Absorbers(Random(3))
        val seen = mutableSetOf<Balls.Absorbers.State>()
        var relaunched = false
        var last = a.state
        repeat(30 * 60 * 60) {
            a.step(1.0 / 30, w, h, 8)
            seen += a.state
            if (last == Balls.Absorbers.State.OUT && a.state == Balls.Absorbers.State.IN) {
                relaunched = true
                assertEquals(8, a.list.size)
                assertEquals(0.0, a.fade, 1e-9)
            }
            last = a.state
            if (a.state == Balls.Absorbers.State.HOLD) assertTrue(a.list.size <= 3)
        }
        assertTrue(seen.toString(), seen.containsAll(Balls.Absorbers.State.values().toList()))
        assertTrue(relaunched)
    }
}
