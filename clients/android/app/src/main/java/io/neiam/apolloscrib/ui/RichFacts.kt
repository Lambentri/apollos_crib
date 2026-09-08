package io.neiam.apolloscrib.ui

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.targets.asClockTime
import io.neiam.apolloscrib.types.AqiCondensed
import io.neiam.apolloscrib.types.EphemerisCondensed
import io.neiam.apolloscrib.types.GbfsCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.TidalCondensed
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.types.WeatherCondensed
import kotlin.math.roundToInt

/**
 * One card's worth of a query, in named parts.
 *
 * The compact card is a title and a few rows of icon-and-number. That is the
 * right shape for something glanced at, and it throws away the one thing a
 * detailed card is for: what the number *is*. A weather card shows 21° beside
 * a thermometer and 44 beside a droplet, and you know which is which because
 * you know what droplets mean -- read that sentence about pressure, or
 * visibility, and it stops working.
 *
 * So a rich card carries labels. [headline] is the thing being asked about,
 * [facts] are the things that qualify it, and each fact says its own name.
 */
data class RichFacts(
    val title: String,
    val iconRes: Int,
    val headline: String? = null,
    val caption: String? = null,
    val facts: List<Fact> = emptyList()
) {
    data class Fact(val label: String, val value: String)
}

/**
 * The rich reading of an entry, or null for one with nothing to say.
 *
 * Falls back to whatever the compact renderer made of it, so a type nobody has
 * written a rich reading for still gets a card rather than disappearing from a
 * mode that is meant to show more, not less.
 */
fun factsFor(entry: VisionEntry): RichFacts? = when (entry.type) {
    SourceType.Weather -> weather(entry)
    SourceType.Aqi -> aqi(entry)
    SourceType.Ephem -> ephem(entry)
    SourceType.Tidal -> tidal(entry)
    SourceType.Gbfs -> gbfs(entry)
    else -> generic(entry)
}

private fun weather(entry: VisionEntry): RichFacts? {
    val now = entry.decode<List<WeatherCondensed>>()?.firstOrNull() ?: return null
    val degrees = now.degrees()

    return RichFacts(
        title = now.name ?: entry.label(),
        iconRes = R.drawable.fa_temperature_half,
        headline = now.temp?.let { "${it.roundToInt()}$degrees" },
        caption = now.weather,
        facts = listOfNotNull(
            now.feel?.let { RichFacts.Fact("Feels like", "${it.roundToInt()}$degrees") },
            now.hum?.let { RichFacts.Fact("Humidity", "${it.roundToInt()}%") },
            now.pressure?.let { RichFacts.Fact("Pressure", "${it.roundToInt()} hPa") },
            now.wind?.speed?.let { speed ->
                val bearing = now.wind.deg?.let { " ${compassPoint(it.toFloat())}" }.orEmpty()
                RichFacts.Fact("Wind", "${speed.roundToInt()} m/s$bearing")
            },
            now.visibility?.let { RichFacts.Fact("Visibility", "${(it / 1000).roundToInt()} km") }
        )
    )
}

private fun aqi(entry: VisionEntry): RichFacts? {
    val site = entry.decode<List<AqiCondensed>>()?.firstOrNull() ?: return null

    // The worst reading leads, because that is the one that decides whether to
    // go outside; the rest qualify it.
    val worst = site.measurements.maxByOrNull { it.value.toIntOrNull() ?: -1 }

    return RichFacts(
        title = site.name ?: entry.label(),
        iconRes = R.drawable.fa_wind,
        headline = worst?.value,
        caption = worst?.key,
        facts = site.measurements
            .filterKeys { it != worst?.key }
            .map { (pollutant, value) -> RichFacts.Fact(pollutant, value) }
    )
}

private fun ephem(entry: VisionEntry): RichFacts? {
    val sky = entry.decode<List<EphemerisCondensed>>()?.firstOrNull() ?: return null

    return RichFacts(
        title = sky.name ?: entry.label(),
        iconRes = R.drawable.fa_sun,
        headline = sky.sunset?.asClockTime(),
        caption = sky.sunset?.let { "Sunset" },
        facts = listOfNotNull(
            sky.sunrise?.let { RichFacts.Fact("Sunrise", it.asClockTime()) },
            sky.moonrise?.let { RichFacts.Fact("Moonrise", it.asClockTime()) },
            sky.moonset?.let { RichFacts.Fact("Moonset", it.asClockTime()) },
            sky.phase?.let { RichFacts.Fact("Moon", it) }
        )
    )
}

private fun tidal(entry: VisionEntry): RichFacts? {
    val tide = entry.decode<List<TidalCondensed>>()?.firstOrNull() ?: return null

    val extremes = Tides.order(tide)
    if (extremes.isEmpty()) return null

    val now = java.time.LocalTime.now().let { it.hour * 60 + it.minute }
    val next = Tides.next(extremes, now)

    return RichFacts(
        title = entry.label(),
        iconRes = R.drawable.fa_water,
        // The next tide, not the first field the publisher filled in.
        headline = next?.at?.asClockTime(),
        // What the water is doing, which tide brings it, and how long: the
        // three in that order, because that is the order they are wanted in.
        // The first needs nothing known to read, the second names what the
        // headline is a time for, and the third is the only one that is
        // arithmetic.
        caption = next?.let { extreme ->
            listOfNotNull(
                Tides.state(extreme),
                if (extreme.high) "Next high" else "Next low",
                Tides.until(now, extreme.minutes)
            ).joinToString(" · ")
        },
        // The rest in clock order, each saying which it is and how high.
        facts = extremes
            .filter { it != next }
            .map { extreme ->
                RichFacts.Fact(
                    if (extreme.high) "High" else "Low",
                    listOfNotNull(extreme.at.asClockTime(), extreme.height).joinToString("  ")
                )
            }
    )
}

private fun gbfs(entry: VisionEntry): RichFacts? {
    val stations = entry.decode<List<GbfsCondensed>>().orEmpty()
    if (stations.isEmpty()) return null

    val loose = stations.all { it.isFreeBike() }
    val bikes = stations.sumOf { it.avail ?: 0 }

    return RichFacts(
        title = entry.label(),
        iconRes = R.drawable.fa_bicycle,
        headline = if (loose) stations.size.toString() else bikes.toString(),
        caption = if (loose) "nearby" else "available",
        facts = if (loose) {
            // A loose fleet has no docks to count; what it has is charge, and
            // which way to walk.
            stations.take(4).mapNotNull { bike ->
                val charge = bike.fuel_pct?.let { "${(it * 100).roundToInt()}%" }
                val where = bike.dir
                val value = listOfNotNull(charge, where).joinToString(" · ")

                if (value.isEmpty()) null else RichFacts.Fact(bike.name, value)
            }
        } else {
            listOfNotNull(
                stations.sumOf { it.avail_elec ?: 0 }.takeIf { it > 0 }
                    ?.let { RichFacts.Fact("Electric", it.toString()) },
                stations.sumOf { it.docks_avail ?: 0 }.takeIf { it > 0 }
                    ?.let { RichFacts.Fact("Docks free", it.toString()) },
                stations.firstOrNull()?.dir?.let { RichFacts.Fact("Direction", it) }
            ) + stations.take(3).map {
                RichFacts.Fact(it.name, "${it.avail ?: 0} bikes")
            }
        }
    )
}

/**
 * Whatever the compact renderer made of it, laid out with room.
 *
 * No labels, because the compact card has none to give -- its rows are a glyph
 * and a value and the glyph carries the meaning. Still worth showing: a type
 * without a rich reading written for it should be quieter in this mode, not
 * absent from it.
 */
private fun generic(entry: VisionEntry): RichFacts? {
    val preview = Targets.preview(entry).firstOrNull() ?: return null

    return RichFacts(
        title = preview.title,
        iconRes = preview.iconRes,
        caption = preview.subtitle,
        facts = preview.rows.take(6).map { row ->
            RichFacts.Fact(
                row.text.ifBlank { "—" },
                row.stamps.joinToString(" · ") { it.text }
            )
        }
    )
}
