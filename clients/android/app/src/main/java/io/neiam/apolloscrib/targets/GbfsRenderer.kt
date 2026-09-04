package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.GbfsCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Docks, or loose bikes.
 *
 * The same query answers with either, depending on whether it names a station
 * or an area, and the condenser tells them apart by what came back rather than
 * by the query. This does the same.
 */
object GbfsRenderer : SourceRenderer {

    override val type = SourceType.Gbfs
    override val iconRes = R.drawable.fa_bicycle
    override val label = "Apollo's Crib: Bikeshare"
    override val description = "Bikes and docks at a station in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val stations = entry.decode<List<GbfsCondensed>>().orEmpty()

        // Most bikes first: for a dock that is the one worth walking to, and
        // for loose bikes the feed implies no order to preserve.
        val ordered = stations.sortedByDescending { it.avail ?: 0 }

        val title = entry.label()
        // A station query names the station and the query the same thing, so
        // the row would repeat the card's own heading back at it -- and, being
        // long, push the counts off the edge doing it.
        val named = ordered.size > 1 || ordered.firstOrNull()?.name != title

        return listOf(
            Preview(
                id = entry.key,
                title = title,
                subtitle = summary(ordered),
                iconRes = iconRes,
                rows = ordered.map { row(it, named = named) },
                empty = "No bikes nearby"
            )
        )
    }

    /**
     * A dock counts what is in it and what is free to return to; a loose bike
     * has only its charge. The web board stamps the same three things --
     * bikes, a bolt for the electric ones, and parking for the docks.
     */
    /**
     * The glyph for what this actually is.
     *
     * A GBFS feed is not always bicycles -- Getaround publishes cars, other
     * operators mopeds -- and a car share drawn as a row of bicycles is wrong
     * in the way a glance cannot recover from, because nobody reads the label
     * first. Only where the free icon set has a truthful glyph: it has no kick
     * scooter, and drawing a standing scooter as a motorcycle would trade one
     * wrong picture for another.
     */
    private fun formIcon(form: String?): Int = when (form) {
        "car" -> R.drawable.fa_car
        "moped" -> R.drawable.fa_motorcycle
        else -> R.drawable.fa_bicycle
    }

    private fun row(station: GbfsCondensed, named: Boolean): Row = when {
        station.isFreeBike() -> Row(
            iconRes = formIcon(station.form_factor),
            text = if (named) station.name else "",
            stamps = buildList {
                addAll(bearing(station))
                station.fuel_pct?.let {
                    add(Stamp(R.drawable.fa_battery_half, "${(it * 100).toInt()}%"))
                }
            }
        )

        else -> Row(
            iconRes = R.drawable.fa_bicycle,
            text = if (named) station.name else "",
            stamps = buildList {
                addAll(bearing(station))
                val bikes = station.avail ?: 0
                add(Stamp(R.drawable.fa_bicycle, "$bikes", flat = "${bikes}b"))
                val electric = station.avail_elec ?: 0
                if (electric > 0) {
                    add(Stamp(R.drawable.fa_bolt_lightning, "$electric", flat = "${electric}e"))
                }
                val docks = station.docks_avail ?: 0
                add(Stamp(R.drawable.fa_square_parking, "$docks", flat = "${docks}d"))
            }
        )
    }

    /**
     * Which way to walk, when the publisher said.
     *
     * First on the row, ahead of the counts: "four bikes" is a fact and "NE"
     * is an instruction, and the instruction is the one worth reading first.
     * Only a Plani sends it, so this is empty on a vision's cards.
     */
    private fun bearing(station: GbfsCondensed): List<Stamp> =
        station.dir?.let { listOf(Stamp(R.drawable.fa_location_arrow, it, flat = it)) }.orEmpty()

    /**
     * What to call them, when they are all the same kind of thing.
     *
     * "4 bikes nearby" is wrong for a car share and "4 vehicles nearby" is
     * clumsy for a bike share, so the fleet decides. A mixed fleet, or one
     * whose feed publishes no vehicle types, gets the neutral word rather than
     * the majority's -- being vague is recoverable, being confidently wrong is
     * not.
     */
    private fun noun(stations: List<GbfsCondensed>, plural: Boolean): String {
        val forms = stations.map { it.form_factor }.distinct()

        // Nothing said what these are. Almost every GBFS feed is bicycles and
        // this renderer's own card is titled Bikeshare, so the old word stays
        // the default -- calling a bike share "vehicles" for want of a field
        // would make every existing source read worse to no purpose.
        if (forms == listOf(null)) return if (plural) "bikes" else "bike"

        return when (forms.singleOrNull()) {
            "car" -> if (plural) "cars" else "car"
            "moped" -> if (plural) "mopeds" else "moped"
            "scooter_standing", "scooter_seated", "scooter" ->
                if (plural) "scooters" else "scooter"
            "bicycle", "cargo_bicycle" -> if (plural) "bikes" else "bike"
            else -> if (plural) "vehicles" else "vehicle"
        }
    }

    private fun summary(stations: List<GbfsCondensed>): String? {
        if (stations.isEmpty()) return null

        if (stations.all { it.isFreeBike() }) {
            return "${stations.size} ${noun(stations, stations.size != 1)} nearby"
        }

        val bikes = stations.sumOf { it.avail ?: 0 }
        val electric = stations.sumOf { it.avail_elec ?: 0 }
        return if (electric > 0) "$bikes bikes · $electric electric" else "$bikes bikes"
    }
}
