package io.neiam.apolloscrib.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.GtfsPlusCondensed
import io.neiam.apolloscrib.types.PlusArrival
import io.neiam.apolloscrib.targets.asClockTime
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.ui.theme.LocalAppTheme

/**
 * One route, in as much detail as the feed gave.
 *
 * The compact card answers "when is the next one". This answers the questions
 * you ask once you know that: how late is it really, is it actually running,
 * which platform, and is there any room on it. All of that arrives in the Plus
 * feed and none of it fits on a card three lines high, which is why this is a
 * mode rather than a bigger card.
 */
@Composable
fun RichCard(entry: VisionEntry, route: GtfsPlusCondensed, modifier: Modifier = Modifier) {
    val palette = LocalAppTheme.current

    Card(modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Header(entry, route, palette.dim)

            // Four is what fits without the card becoming a timetable. Past
            // that the answer is the stop's own board, not this.
            route.arrivals.take(4).forEach { arrival -> Arrival(arrival, palette.dim) }

            if (route.arrivals.isEmpty()) {
                Text(
                    "Nothing due",
                    style = MaterialTheme.typography.bodyMedium,
                    color = palette.dim
                )
            }

            route.alerts.orEmpty().take(2).forEach { alert ->
                Row(verticalAlignment = Alignment.Top) {
                    Glyph(R.drawable.fa_triangle_exclamation, 14.dp, MaterialTheme.colorScheme.error)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        alert.header ?: alert.effect,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

@Composable
private fun Header(entry: VisionEntry, route: GtfsPlusCondensed, dim: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // The route, and which way this stop lies. One line, because between
        // them they are the card's identity.
        Row(verticalAlignment = Alignment.CenterVertically) {
            RouteBadge(route)

            Spacer(Modifier.weight(1f))

            route.bearing?.let { bearing ->
                Glyph(R.drawable.fa_location_arrow, 13.dp, dim)
                Spacer(Modifier.width(5.dp))
                Text(bearing, style = MaterialTheme.typography.titleSmall, color = dim)
            }
        }

        // Where it goes, given the room to say so. This is what somebody
        // reads first and the compact card could only ever abbreviate: two
        // lines here rather than one ellipsised one, because "Alewife via
        // Harvard" cut to "Alewife via..." is a different destination.
        Text(
            route.dest ?: entry.label(),
            style = MaterialTheme.typography.headlineSmall,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        // The stop it leaves from, on its own line. In compact mode this is
        // the card's title and the destination is squeezed in beside it; here
        // there is room for both to be themselves.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Glyph(R.drawable.fa_location_dot, 13.dp, dim)
            Spacer(Modifier.width(6.dp))
            Text(
                entry.label(),
                style = MaterialTheme.typography.titleSmall,
                color = dim,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        val extra =
            listOfNotNull(route.dir, route.route_long?.takeIf { it != route.dest })
                .distinct()
                .joinToString(" · ")

        if (extra.isNotEmpty()) {
            Text(
                extra,
                style = MaterialTheme.typography.bodySmall,
                color = dim,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun RouteBadge(route: GtfsPlusCondensed) {
    val background = route.color?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() }
    val foreground = route.text_color?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() }

    Text(
        route.displayName(),
        style = MaterialTheme.typography.headlineSmall,
        color = foreground ?: MaterialTheme.colorScheme.onSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(background ?: MaterialTheme.colorScheme.secondary)
            .padding(horizontal = 12.dp, vertical = 4.dp)
    )
}

/**
 * One departure and everything known about it.
 *
 * The time leads because it is what is being asked. What follows it qualifies
 * it, in the order a rider cares: is it happening, how late, from where, how
 * full.
 */
@Composable
private fun Arrival(arrival: PlusArrival, dim: Color) {
    val cancelled = arrival.cancelled()

    Row(verticalAlignment = Alignment.CenterVertically) {
        Glyph(
            if (arrival.live()) R.drawable.fa_tower_broadcast else R.drawable.fa_clock,
            14.dp,
            if (arrival.live()) LocalAppTheme.current.liveGreen else dim
        )

        Spacer(Modifier.width(8.dp))

        Text(
            arrival.best()?.asClockTime() ?: "--:--",
            style = MaterialTheme.typography.headlineSmall,
            fontFamily = FontFamily.Monospace,
            textDecoration = if (cancelled) TextDecoration.LineThrough else null,
            color = if (cancelled) dim else MaterialTheme.colorScheme.onSurface
        )

        Spacer(Modifier.width(10.dp))

        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            val status = statusOf(arrival)
            if (status != null) {
                Text(
                    status,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (cancelled) MaterialTheme.colorScheme.error else dim
                )
            }

            val detail = listOfNotNull(
                arrival.platform?.let { "Platform $it" },
                arrival.name,
                arrival.headsign,
                occupancyOf(arrival),
                arrival.carriages?.size?.takeIf { it > 0 }?.let { "$it cars" }
            )

            if (detail.isNotEmpty()) {
                Text(
                    detail.joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = dim,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * How this departure is doing, in a rider's words.
 *
 * "On time" is only said when the feed actually said so -- a scheduled time
 * with no realtime behind it is not a promise, and claiming it is on time
 * would be inventing confidence the agency never offered.
 */
private fun statusOf(arrival: PlusArrival): String? = when {
    arrival.trip_status == "CANCELED" -> "Cancelled"
    arrival.stop_status == "SKIPPED" -> "Not stopping here"
    arrival.trip_status == "ADDED" -> "Extra service"
    else -> arrival.delayMinutes()?.let { minutes ->
        when {
            minutes >= 1 -> "$minutes min late"
            minutes <= -1 -> "${-minutes} min early"
            // Inside a minute either way, which is on time by any reading a
            // person standing at a stop would give it.
            else -> "On time"
        }
    }
}

// GTFS-RT spells these `FEW_SEATS_AVAILABLE`; nobody says that out loud.
private fun occupancyOf(arrival: PlusArrival): String? {
    arrival.occupancy_pct?.let { return "$it% full" }

    return when (arrival.occupancy) {
        "EMPTY" -> "Empty"
        "MANY_SEATS_AVAILABLE" -> "Seats"
        "FEW_SEATS_AVAILABLE" -> "Few seats"
        "STANDING_ROOM_ONLY" -> "Standing"
        "CRUSHED_STANDING_ROOM_ONLY" -> "Very full"
        "FULL" -> "Full"
        "NOT_ACCEPTING_PASSENGERS" -> "Not boarding"
        else -> null
    }
}

@Composable
private fun Glyph(res: Int, size: androidx.compose.ui.unit.Dp, tint: Color) {
    Icon(
        painter = painterResource(res),
        contentDescription = null,
        modifier = Modifier.size(size),
        tint = tint
    )
}

/**
 * A non-transit query, in as much detail as it has.
 *
 * The same weight as [RichCard] so the two sit together in one rotation: a
 * headline that answers the question, and beneath it the things that qualify
 * it, each saying its own name.
 */
@Composable
fun RichFactsCard(facts: RichFacts, modifier: Modifier = Modifier) {
    val palette = LocalAppTheme.current

    Card(modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Glyph(facts.iconRes, 18.dp, palette.accent)
                Spacer(Modifier.width(10.dp))
                Text(
                    facts.title,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            if (facts.headline != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(
                        Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(facts.headline, style = MaterialTheme.typography.displaySmall)

                        facts.caption?.let {
                            Text(
                                it,
                                style = MaterialTheme.typography.titleSmall,
                                color = palette.dim
                            )
                        }
                    }

                    // The picture of the answer, opposite the number. Sized to
                    // the headline rather than to the text beside it: from
                    // across a room this is the part that reads.
                    facts.glyph?.let { glyph -> Glyph(glyph, 52.dp, palette.accent) }
                }
            } else {
                facts.caption?.let {
                    Text(it, style = MaterialTheme.typography.titleMedium, color = palette.dim)
                }
            }

            // Two to a row: a label and its value need to stay together, and
            // one per line would make a card of six facts taller than the
            // screen for no gain.
            facts.facts.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    pair.forEach { fact ->
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                            Text(
                                fact.label,
                                style = MaterialTheme.typography.labelSmall,
                                color = palette.dim,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                fact.value.ifBlank { "—" },
                                style = MaterialTheme.typography.titleMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }

                    // A lone fact on the last row keeps its half rather than
                    // stretching across a width the others do not use.
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}
