package io.neiam.apolloscrib.types

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject

/**
 * Pollutant readings for a reporting area.
 *
 * Not a fixed struct: `HourlyObsData.compile_pairs` emits whatever the monitor
 * measured, and the crate models the rest as a flattened map for the same
 * reason. Decoded by hand rather than with a serializer, because the shape is
 * "a name and then whatever else".
 */
data class AqiCondensed(
    val name: String?,
    /** Pollutant to reading, in the order the publisher sent them. */
    val measurements: Map<String, String>
) {
    companion object {
        /** Fields that are not a pollutant reading. */
        private val NOT_A_MEASUREMENT = setOf("name", "combined")

        /** How the web names them, for the ones it knows. */
        private val LABELS = mapOf(
            "pm25" to "PM2.5",
            "pm10" to "PM10",
            "no2" to "NO2",
            "ozone" to "O3",
            "so2" to "SO2",
            "co" to "CO"
        )

        fun label(key: String): String = LABELS[key] ?: key.uppercase()

        fun from(element: JsonElement): AqiCondensed? {
            val obj = element as? JsonObject ?: return null
            val name = (obj["name"] as? JsonPrimitive)?.contentOrNullSafe()
            val measurements = obj
                .filterKeys { it !in NOT_A_MEASUREMENT }
                .mapNotNull { (key, value) ->
                    (value as? JsonPrimitive)?.contentOrNullSafe()?.let { key to it }
                }
                .toMap()
            return AqiCondensed(name, measurements)
        }

        fun list(element: JsonElement): List<AqiCondensed> =
            when (element) {
                is kotlinx.serialization.json.JsonArray -> element.mapNotNull { from(it) }
                is JsonObject -> listOfNotNull(from(element))
                else -> emptyList()
            }
    }
}

/** A JSON null reads as the literal "null" through `content`; this does not. */
internal fun JsonPrimitive.contentOrNullSafe(): String? =
    if (this is kotlinx.serialization.json.JsonNull) null else content.takeIf { it.isNotBlank() }
