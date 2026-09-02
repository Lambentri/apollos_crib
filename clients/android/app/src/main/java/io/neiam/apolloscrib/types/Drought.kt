package io.neiam.apolloscrib.types

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * US Drought Monitor coverage for an area. Mirrors `UsdmStats`.
 *
 * The categories are cumulative as the USDM publishes them: `d0` includes
 * everything worse than it, so a county at 100% d0 and 50% d1 has half its
 * area at D1 or worse. The renderer reports the worst category with any
 * coverage rather than adding them up.
 */
@Serializable
data class DroughtCondensed(
    @SerialName("mapDate") val mapDate: String? = null,
    val state: String? = null,
    val county: String? = null,
    val none: Double? = null,
    val d0: Double? = null,
    val d1: Double? = null,
    val d2: Double? = null,
    val d3: Double? = null,
    val d4: Double? = null
) {
    /** The worst category with any of the area in it, and how much. */
    fun worst(): Pair<String, Double>? = listOf(
        "D4" to d4, "D3" to d3, "D2" to d2, "D1" to d1, "D0" to d0
    ).firstOrNull { (_, pct) -> (pct ?: 0.0) > 0.0 }
        ?.let { (label, pct) -> label to pct!! }

    fun where(): String? = listOfNotNull(county, state).joinToString(", ").ifEmpty { null }
}
