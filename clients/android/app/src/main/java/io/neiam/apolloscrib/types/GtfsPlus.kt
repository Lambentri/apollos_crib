package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * The extended reading of a transit query.
 *
 * Mirrors `RoomSanctum.Condenser.PlusMQTT`. Where Basic flattens a route into
 * parallel lists of times, Plus keeps each arrival whole — so everything the
 * feed said about *this* departure stays attached to it rather than to an
 * index into three lists.
 *
 * Every field past the route itself is optional, because every one of them is
 * something a particular agency may or may not publish. A feed that sends only
 * times reads here exactly as it does in Basic.
 */
@Serializable
data class GtfsPlusCondensed(
    val route: String,
    val dest: String? = null,
    val dir: String? = null,
    val mode: String? = null,
    val arrivals: List<PlusArrival> = emptyList(),
    val alerts: List<AlertCondensed>? = null,
    /** Which way this stop lies from you. Only a Plani sends it. */
    val bearing: String? = null,
    // Presentation, as Basic carries it.
    val route_name: String? = null,
    val route_long: String? = null,
    val color: String? = null,
    val text_color: String? = null
) {
    /** What is written on the front of the vehicle, falling back to the id. */
    fun displayName(): String = route_name ?: route
}

/**
 * One departure, with everything the feed said about it.
 *
 * [time] is the timetable; [time_live] is the feed's revision of it, absent
 * when the feed said nothing. The rest is why Plus exists: how late, how sure,
 * how full, which platform, and whether it is running at all.
 */
@Serializable
data class PlusArrival(
    val time: String? = null,
    val time_live: String? = null,
    /** Seconds off the timetable. Negative is early. */
    val delay: Int? = null,
    /** The feed's own confidence: 0 means it is certain. */
    val uncertainty: Int? = null,
    val occupancy: String? = null,
    val occupancy_pct: Int? = null,
    /** The number on the side of the train, where an agency gives one. */
    val name: String? = null,
    val bikes: String? = null,
    val carriages: List<PlusCarriage>? = null,
    /** Not running at all: `CANCELED`, `ADDED`, `DUPLICATED`. */
    val trip_status: String? = null,
    /** Running, but not calling here: `SKIPPED`, `NO_DATA`. */
    val stop_status: String? = null,
    /** What this call says about itself, over what the trip says. */
    val headsign: String? = null,
    val platform: String? = null,
    val trip_id: String? = null
) {
    /** The time to show: the feed's revision where it has one. */
    fun best(): String? = time_live ?: time

    /** Whether that time came from the feed rather than the timetable. */
    fun live(): Boolean = time_live != null

    /**
     * Whether this departure is not going to happen.
     *
     * A cancelled trip and a skipped stop are different news to a rider -- the
     * line is not running, versus it is running past you -- but both mean do
     * not stand here waiting for it.
     */
    fun cancelled(): Boolean = trip_status == "CANCELED" || stop_status == "SKIPPED"

    /** Minutes off the timetable, rounded, or null when the feed did not say. */
    fun delayMinutes(): Int? = delay?.let { it / 60 }
}

@Serializable
data class PlusCarriage(
    val id: String? = null,
    val label: String? = null,
    val occupancy: String? = null,
    val occupancy_pct: Int? = null
)
