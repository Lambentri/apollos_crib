package io.neiam.apolloscrib.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.mqtt.AnkyraClient
import io.neiam.apolloscrib.mqtt.AnkyraService
import io.neiam.apolloscrib.targets.Preview
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.ui.theme.LocalAppTheme
import java.text.DateFormat
import java.util.Date

/**
 * The board, as the phone currently has it.
 *
 * What the app is for, once it is set up: every query in the vision drawn the
 * way its Target draws it, updating as payloads land. Not a mock -- these are
 * the same [Preview]s the Smartspace cards are built from, so what is on this
 * screen is what a Target added for that query will say.
 */
@Composable
fun BoardScreen(
    modifier: Modifier = Modifier,
    store: VisionStore,
    /** Null where the board is read-only -- the launcher's feed page. */
    onEditConnection: (() -> Unit)?
) {
    val boards by VisionStore.boards.collectAsState()
    val state by AnkyraService.connectionState.collectAsState()

    // Re-read whenever a board lands. Parsing a payload of this size on the
    // main thread is cheap, and it happens at most once a tick.
    val entries = remember(boards) { store.entries() }
    val unsupported = remember(boards) { store.unsupported() }
    val lastUpdated = remember(boards) { store.lastUpdated() }
    val stale = remember(boards) { store.isStale() }

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            StatusHeader(
                state = state,
                lastUpdated = lastUpdated,
                stale = stale,
                onEditConnection = onEditConnection
            )
        }

        if (entries.isEmpty()) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Nothing on the board yet", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "A Pythiae publishes when its vision changes. If this stays " +
                                "empty, check that one is pointed at this Ankyra.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }

        entries.forEach { entry ->
            val previews = Targets.preview(entry)
            if (previews.isEmpty()) {
                // A query this build can draw, that answered with nothing it
                // knows how to say. Worth showing as itself rather than as a
                // gap in the list.
                item(key = entry.key) {
                    PreviewCard(
                        Preview(
                            id = entry.key,
                            title = entry.label(),
                            subtitle = entry.key,
                            iconRes = io.neiam.apolloscrib.R.drawable.ic_crib,
                            empty = "Nothing to show"
                        )
                    )
                }
            } else {
                items(previews, key = { "${entry.key}-${it.id}" }) { preview ->
                    PreviewCard(preview)
                }
            }
        }

        if (unsupported.isNotEmpty()) {
            item {
                Text(
                    "Also on this board, with nothing here to draw them yet: " +
                        unsupported.joinToString(", "),
                    style = MaterialTheme.typography.bodySmall,
                    color = LocalAppTheme.current.dim
                )
            }
        }

        if (onEditConnection != null) {
            item {
                Text(
                    "Add these as Targets from Smartspacer: Targets, then Apollo's Crib. " +
                        "Each one asks which query it should show.",
                    style = MaterialTheme.typography.bodySmall,
                    color = LocalAppTheme.current.dim
                )
            }
        }
    }
}

@Composable
private fun StatusHeader(
    state: AnkyraClient.State,
    lastUpdated: Long?,
    stale: Boolean,
    onEditConnection: (() -> Unit)?
) {
    val palette = LocalAppTheme.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top
    ) {
        // The name, and when the board it is showing arrived. What the screen
        // is, on the left, where reading starts.
        Column(Modifier.weight(1f)) {
            Text(
                "Apollo's",
                style = MaterialTheme.typography.headlineSmall,
                color = palette.accent
            )
            Text(
                when {
                    lastUpdated == null -> "No board received yet"
                    stale -> "Last board ${clock(lastUpdated)} · stale"
                    else -> "Last board ${clock(lastUpdated)}"
                },
                style = MaterialTheme.typography.bodySmall,
                color = palette.dim
            )
        }
        // The connection, and the way into it, on the right: both about the
        // link rather than about the data.
        Column(horizontalAlignment = Alignment.End) {
            Text(
                when (state) {
                    AnkyraClient.State.Connected -> "Listening"
                    AnkyraClient.State.Connecting -> "Connecting"
                    AnkyraClient.State.Failed -> "Connection failed"
                    AnkyraClient.State.Disconnected -> "Not connected"
                },
                style = MaterialTheme.typography.titleMedium,
                color = when (state) {
                    AnkyraClient.State.Connected -> palette.liveGreen
                    AnkyraClient.State.Failed -> MaterialTheme.colorScheme.error
                    else -> palette.dim
                }
            )
            onEditConnection?.let { edit ->
                TextButton(
                    onClick = edit,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp)
                ) {
                    Text("Connection", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

/**
 * One card, drawn from the same description the Smartspace target is built
 * from -- and, where the Smartspace templates only take strings, with the
 * glyphs the web board uses.
 */
@Composable
private fun PreviewCard(preview: Preview) {
    val palette = LocalAppTheme.current
    Card(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(16.dp)) {
            Glyph(preview.iconRes, size = 28.dp, tint = palette.primary)
            Spacer(Modifier.width(12.dp))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(preview.title, style = MaterialTheme.typography.titleMedium)
                preview.subtitle?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall, color = palette.dim)
                }
                if (preview.style == Preview.Style.List) {
                    Spacer(Modifier.width(4.dp))
                    if (preview.rows.isEmpty()) {
                        Text(
                            preview.empty,
                            style = MaterialTheme.typography.bodyMedium,
                            color = palette.dim
                        )
                    } else {
                        // Every row, not the three a Smartspace card has room
                        // for. This screen scrolls, and "+1 more" is a worse
                        // use of a line than the thing it is counting.
                        preview.rows.forEach { row -> BoardRow(row) }
                    }
                }
            }
        }
    }
}

/** `[bus] 87 Arlington Center  [tower] 15:33  [clock] 15:56` */
@Composable
private fun BoardRow(row: io.neiam.apolloscrib.targets.Row) {
    val palette = LocalAppTheme.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Glyph(row.iconRes, size = 16.dp, tint = palette.dim)
        if (row.text.isNotEmpty()) {
            // The stamps are the numbers; the text is what they are about. A
            // long station name should lose its tail rather than push the
            // counts off the card.
            Text(
                row.text,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false)
            )
        }
        row.stamps.forEach { stamp ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                // A time from the feed and a time from the timetable are not
                // the same claim, and the glyph is what says which. Matched
                // to the row's own glyph: the broadcast tower is a thin mast
                // between two arcs, and below 16 it reads as a quote mark
                // rather than as an aerial.
                Glyph(stamp.iconRes, size = 16.dp, tint = palette.accent)
                Text(
                    stamp.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = palette.accent
                )
            }
        }
    }
}

@Composable
private fun Glyph(res: Int, size: Dp, tint: Color) {
    Icon(
        painter = painterResource(res),
        contentDescription = null,
        modifier = Modifier.size(size),
        tint = tint
    )
}

private fun clock(at: Long): String = DateFormat.getTimeInstance().format(Date(at))
