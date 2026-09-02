package io.neiam.apolloscrib.types

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Sun and moon for a place.
 *
 * The condenser builds this from whatever periods the query asked for --
 * `sunrise`, `moonset`, `phase` -- so like AQI it is a name plus a flattened
 * map, and the crate models it the same way.
 */
data class EphemerisCondensed(
    val name: String?,
    val periods: Map<String, String>
) {
    val phase: String? get() = periods["phase"]
    val sunrise: String? get() = periods["sunrise"]
    val sunset: String? get() = periods["sunset"]
    val moonrise: String? get() = periods["moonrise"]
    val moonset: String? get() = periods["moonset"]

    /**
     * The moon as a character.
     *
     * Northern-hemisphere shapes, waxing from the right. The web preview's own
     * mapping has new moon drawing a full disc and full moon drawing a dark
     * one -- it is off by four -- so this does not copy it.
     */
    fun moonGlyph(): String? = when (phase) {
        "new_moon" -> "🌑"
        "waxing_crescent" -> "🌒"
        "first_quarter" -> "🌓"
        "waxing_gibbous" -> "🌔"
        "full_moon" -> "🌕"
        "waning_gibbous" -> "🌖"
        "third_quarter" -> "🌗"
        "waning_crescent" -> "🌘"
        else -> null
    }

    companion object {
        fun from(element: JsonElement): EphemerisCondensed? {
            val obj = element as? JsonObject ?: return null
            val name = (obj["name"] as? JsonPrimitive)?.contentOrNullSafe()
            val periods = obj
                .filterKeys { it != "name" }
                .mapNotNull { (key, value) ->
                    (value as? JsonPrimitive)?.contentOrNullSafe()?.let { key to it }
                }
                .toMap()
            return EphemerisCondensed(name, periods)
        }

        fun list(element: JsonElement): List<EphemerisCondensed> = when (element) {
            is JsonArray -> element.mapNotNull { from(it) }
            is JsonObject -> listOfNotNull(from(element))
            else -> emptyList()
        }
    }
}
