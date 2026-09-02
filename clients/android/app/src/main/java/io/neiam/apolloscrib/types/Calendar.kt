package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/** An event. Mirrors `CalendarCondensed` in the crate. */
@Serializable
data class CalendarCondensed(
    val date_start: String? = null,
    val description: String? = null
)
