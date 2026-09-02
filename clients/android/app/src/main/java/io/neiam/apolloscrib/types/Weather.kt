package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * Current conditions. Mirrors `WeatherCondensed` in the apollos-types crate.
 *
 * Carried here as the worked example of adding a source: this type, a
 * renderer, a provider subclass and a manifest entry are the whole of it.
 */
@Serializable
data class WeatherCondensed(
    val name: String? = null,
    val weather: String? = null,
    val temp: Double? = null,
    val feel: Double? = null,
    val hum: Double? = null,
    val pressure: Double? = null,
    val wind: WindInfo? = null,
    val visibility: Double? = null,
    /** `metric`, `imperial`, or `standard`, as the source was configured. */
    val units: String? = null
) {
    fun degrees(): String = when (units) {
        "imperial" -> "°F"
        "standard" -> "K"
        else -> "°C"
    }
}

@Serializable
data class WindInfo(
    val speed: Double? = null,
    val deg: Double? = null
)
