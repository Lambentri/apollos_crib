package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * A route's upcoming departures from one stop, as `BasicMQTT.condense_data`
 * publishes them. Mirrors `GtfsCondensed` in the apollos-types crate.
 */
@Serializable
data class GtfsCondensed(
    /** The feed's own route id -- what everything downstream keys on. */
    val route: String,
    val dest: String,
    val dir: String,
    val mode: String = "Unknown",
    /** Scheduled times, `HH:MM:SS` in the stop's own timezone. */
    val times: List<String> = emptyList(),
    /** Realtime estimates, positionally aligned with [times]. Absent when the
     *  feed offered none for any departure; individual entries may still be null. */
    val times_live: List<String?>? = null,
    val alerts: List<AlertCondensed>? = null,
    /** What is written on the front of the vehicle. Older publishers omit it. */
    val route_name: String? = null,
    val route_long: String? = null,
    /**
     * Which way this stop lies from where you are, as a sixteen-point bearing.
     *
     * Not [dir], which is the feed's own inbound/outbound. Only a Plani sets
     * it, and it is absent when a route was blended across two stops lying in
     * different directions.
     */
    val bearing: String? = null,
    /** `#RRGGBB` -- the hash is added publisher-side. */
    val color: String? = null,
    val text_color: String? = null
) {
    /** The name to show: the feed's short name, else its id. */
    fun displayName(): String = route_name ?: route

    /**
     * The departures a rider actually cares about: realtime where the feed
     * gave it, schedule otherwise, paired so a missing estimate falls back
     * rather than shifting every later time up a slot.
     */
    fun departures(): List<String> = times.mapIndexed { index, scheduled ->
        times_live?.getOrNull(index) ?: scheduled
    }
}

@Serializable
data class AlertCondensed(
    val effect: String,
    val cause: String,
    val header: String? = null,
    val description: String? = null,
    val route_id: String? = null,
    /** `INFO`, `WARNING`, `SEVERE`, or `UNKNOWN_SEVERITY`. */
    val severity: String? = null,
    /** Whether the alert names this stop, as against the line it is on. */
    val stop_specific: Boolean? = null
)
