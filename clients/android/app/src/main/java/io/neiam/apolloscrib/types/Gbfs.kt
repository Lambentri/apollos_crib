package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * A dock, or a loose bike. Mirrors `GbfsCondensed` in the apollos-types crate,
 * with the free-bike fields the crate carries on the same struct: an area
 * query answers with bikes rather than stations, and a bike has none of a
 * dock's counts.
 */
@Serializable
data class GbfsCondensed(
    val name: String,
    val id: String,
    val avail: Int? = null,
    val avail_elec: Int? = null,
    val avail_std: Int? = null,
    val docks_avail: Int? = null,
    val docks_disabled: Int? = null,
    val capacity: Int? = null,
    val ebikes_info: List<EbikeInfo> = emptyList(),
    // Free-bike shape.
    val kind: String? = null,
    /**
     * What kind of vehicle, in GBFS's own words: "bicycle", "cargo_bicycle",
     * "scooter_standing", "moped", "car". Present where the feed publishes
     * vehicle types.
     */
    val form_factor: String? = null,
    val lat: Double? = null,
    val lon: Double? = null,
    val range_m: Double? = null,
    val fuel_pct: Double? = null,
    val reserved: Boolean? = null,
    val disabled: Boolean? = null,
    /**
     * Which way it lies from where you are, as a sixteen-point bearing.
     *
     * Only a Plani sets this -- a vision's foci is a fixed place, so there is
     * nothing for a direction to be relative to -- and it is absent for
     * anything close enough that "which way" has no answer.
     */
    val dir: String? = null
) {
    /** Told apart by what came back, not by the query -- as the condenser does. */
    fun isFreeBike(): Boolean = kind == "free_bike" || capacity == null
}

@Serializable
data class EbikeInfo(
    val name: String? = null,
    val battery_pct: Double? = null,
    val range_mi_cons: Double? = null,
    val range_me_est: Double? = null
)
