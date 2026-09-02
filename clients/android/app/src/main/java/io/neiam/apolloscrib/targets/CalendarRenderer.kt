package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.CalendarCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/** What is coming up. Soonest first, which is not the order the feed sends. */
object CalendarRenderer : SourceRenderer {

    override val type = SourceType.Calendar
    override val iconRes = R.drawable.fa_calendar_day
    override val label = "Apollo's Crib: Calendar"
    override val description = "Upcoming events from a calendar in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val events = entry.decode<List<CalendarCondensed>>().orEmpty()
            .sortedBy { it.date_start ?: "9999" }

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = events.firstOrNull()?.description,
                iconRes = iconRes,
                rows = events.map { event ->
                    Row(
                        iconRes = iconRes,
                        text = event.description ?: "(untitled)",
                        stamps = listOfNotNull(
                            event.date_start?.let { Stamp(R.drawable.fa_clock, it.asDate()) }
                        )
                    )
                },
                empty = "Nothing coming up"
            )
        )
    }

    /** The publisher sends a date, sometimes with a time welded to it. */
    private fun String.asDate(): String = substringBefore('T').take(10)
}
