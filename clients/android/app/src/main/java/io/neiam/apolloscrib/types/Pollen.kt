package io.neiam.apolloscrib.types

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** A day's pollen. Mirrors `PollenCondensed` in the crate. */
@Serializable
data class PollenCondensed(
    val date: PollenDate? = null,
    @SerialName("pollenTypeInfo") val pollenTypeInfo: List<PollenTypeInfo> = emptyList()
)

@Serializable
data class PollenDate(val year: Int? = null, val month: Int? = null, val day: Int? = null)

@Serializable
data class PollenTypeInfo(
    /** `GRASS`, `TREE` or `WEED`. */
    val code: String? = null,
    @SerialName("displayName") val displayName: String? = null,
    @SerialName("inSeason") val inSeason: Boolean = false,
    @SerialName("indexInfo") val indexInfo: PollenIndexInfo? = null
)

@Serializable
data class PollenIndexInfo(
    val value: Int? = null,
    val category: String? = null,
    @SerialName("indexDescription") val indexDescription: String? = null
)
