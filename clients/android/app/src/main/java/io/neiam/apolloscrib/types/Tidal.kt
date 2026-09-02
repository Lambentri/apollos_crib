package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * The day's high and low water. Mirrors `TidalCondensed` in the crate.
 *
 * Every field is optional because a station's day does not always hold two of
 * each -- a diurnal tide has one high and one low, and a query run late in the
 * day has whatever is left of it.
 *
 * Heights arrive as strings from some publishers and numbers from others; the
 * crate has a custom deserializer for exactly that, and this keeps them as
 * strings because nothing here does arithmetic on them.
 */
@Serializable
data class TidalCondensed(
    val first_h: String? = null,
    val first_hv: String? = null,
    val second_h: String? = null,
    val second_hv: String? = null,
    val first_l: String? = null,
    val first_lv: String? = null,
    val second_l: String? = null,
    val second_lv: String? = null
)
