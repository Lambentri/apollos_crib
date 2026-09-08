package io.neiam.apolloscrib.ui

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.types.SourceType
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The picture the weather card draws.
 *
 * Reached through `factsFor`, because the mapping is private and what matters
 * is what the card ends up with rather than how it got there.
 */
class SkyGlyphTest {

    private fun glyphFor(condition: String?): Int? {
        val sky = if (condition == null) "" else ""","weather":"$condition""""
        val json = """[{"name":"Somerville","temp":21.5,"units":"metric"$sky}]"""

        val data: JsonElement = Json.parseToJsonElement(json)
        val entry = VisionEntry("weather-1", SourceType.Weather, "1", "Home", emptyMap(), data)

        return factsFor(entry)?.glyph
    }

    @Test
    fun `a clear sky is the sun`() {
        assertEquals(R.drawable.fa_sun, glyphFor("Clear"))
    }

    @Test
    fun `overcast is a cloud, and broken cloud is a cloud with sun behind it`() {
        // "Clouds" alone means overcast here; the sun showing through is a
        // different sky and says so.
        assertEquals(R.drawable.fa_cloud, glyphFor("Clouds"))
        assertEquals(R.drawable.fa_cloud_sun, glyphFor("few clouds"))
        assertEquals(R.drawable.fa_cloud_sun, glyphFor("scattered clouds"))
    }

    @Test
    fun `rain and drizzle are told apart by how hard it is coming down`() {
        assertEquals(R.drawable.fa_cloud_showers_heavy, glyphFor("Rain"))
        assertEquals(R.drawable.fa_cloud_rain, glyphFor("Drizzle"))
    }

    @Test
    fun `a storm is a storm before it is rain`() {
        // "Thunderstorm" contains neither "rain" nor "shower", but the order
        // matters for anything that does.
        assertEquals(R.drawable.fa_cloud_bolt, glyphFor("Thunderstorm"))
    }

    @Test
    fun `every way the air stops being clear is one glyph`() {
        for (condition in listOf("Mist", "Fog", "Haze", "Smoke", "Dust", "Sand", "Ash")) {
            assertEquals(condition, R.drawable.fa_smog, glyphFor(condition))
        }
    }

    @Test
    fun `snow and sleet are the snowflake`() {
        assertEquals(R.drawable.fa_snowflake, glyphFor("Snow"))
        assertEquals(R.drawable.fa_snowflake, glyphFor("Sleet"))
    }

    @Test
    fun `an unrecognised sky draws nothing rather than a guess`() {
        // A wrong picture is read before the word beside it and believed
        // instead of it.
        assertNull(glyphFor("Sharknado"))
        assertNull(glyphFor(null))
    }
}
