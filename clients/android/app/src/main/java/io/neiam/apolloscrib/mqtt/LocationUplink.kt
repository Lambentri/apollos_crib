package io.neiam.apolloscrib.mqtt

import android.location.Location
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * Where a client is, published back to its Ankyra.
 *
 * The point of it is a foci that travels: a vision anchored to the phone
 * rather than to a place, so the stops it shows are the ones you are near.
 * Nothing consumes this yet -- the Plani the README describes is not built --
 * so this is the half that can exist on its own, and the shape the other half
 * would read.
 *
 * Field names match the condensed data the other direction uses: short, flat,
 * and no more precision than is meant. When it is consumed, this belongs in
 * the apollos-types crate alongside the rest of the wire format.
 */
@Serializable
data class LocationUplink(
    val lat: Double,
    val lon: Double,
    /** Metres, as the provider reports it; a fix worse than this is not a fix. */
    @SerialName("accuracy_m") val accuracyM: Float? = null,
    /** Metres per second, where the provider has one. */
    @SerialName("speed_mps") val speedMps: Float? = null,
    /** Degrees from true north, where the provider has one. */
    @SerialName("heading_deg") val headingDeg: Float? = null,
    /** When the fix was taken, not when it was sent. */
    val at: String,
    /** Which client this is, so an Ankyra with two can tell them apart. */
    @SerialName("client_id") val clientId: String
) {
    companion object {
        /**
         * The uplink's own topic, under the prefix the broker allows a client
         * to write. See `RoomHermesWeb.TopicController.uplink_prefix/1`: a
         * client may write `<topic>.up.` and below, and nothing above it.
         */
        fun topicFor(ankyraTopic: String): String = "$ankyraTopic.up.loc"

        fun from(location: Location, clientId: String): LocationUplink = LocationUplink(
            lat = location.latitude,
            lon = location.longitude,
            accuracyM = location.accuracy.takeIf { location.hasAccuracy() },
            speedMps = location.speed.takeIf { location.hasSpeed() },
            headingDeg = location.bearing.takeIf { location.hasBearing() },
            at = Instant.ofEpochMilli(location.time).toString(),
            clientId = clientId
        )
    }
}
