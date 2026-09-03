package io.neiam.apolloscrib.ui

import androidx.compose.foundation.gestures.detectHorizontalDragGestures
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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.mqtt.AnkyraClient
import io.neiam.apolloscrib.mqtt.AnkyraService
import io.neiam.apolloscrib.targets.Preview
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.ui.theme.LocalAppTheme
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull
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
@OptIn(ExperimentalMaterial3Api::class)
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

    val context = LocalContext.current

    // A pull asks for a board; the wait ends when one lands. There is no
    // acknowledgement to wait for -- a Pythiae answers on its own tick and the
    // request is debounced at the other end -- so a new payload is the only
    // honest signal that it worked, and a timeout covers nothing coming back.
    var refreshing by remember { mutableStateOf(false) }

    LaunchedEffect(refreshing) {
        if (!refreshing) return@LaunchedEffect

        val before = VisionStore.boards.value
        withTimeoutOrNull(8_000) {
            snapshotFlow { VisionStore.boards.value }.first { it != before }
        }
        refreshing = false
    }

    // What the last side-swipe did. Cleared after a moment: it is what
    // happened when the gesture was made, not the state of anything.
    var swiped by remember { mutableStateOf("") }

    LaunchedEffect(swiped) {
        if (swiped.isNotEmpty()) {
            kotlinx.coroutines.delay(3_000)
            swiped = ""
        }
    }

    // The launcher's feed page owns horizontal drags -- that is how the panel
    // is dismissed -- so this gesture belongs to the app alone. Read-only is
    // also the wrong place to be publishing anything from.
    val sideSwipeModifier = if (onEditConnection == null) {
        Modifier
    } else {
        Modifier.pointerInput(Unit) {
            var travelled = 0f

            detectHorizontalDragGestures(
                onDragStart = { travelled = 0f },
                onDragEnd = {
                    // A quarter of the width, so a lazy thumb on a card does
                    // not publish a position by accident.
                    if (kotlin.math.abs(travelled) > size.width / 4f) {
                        val settings = Settings(context)

                        // Opt-in means opt-in: a gesture is not consent, and a
                        // wall-mounted client should not start taking fixes
                        // because somebody brushed the screen.
                        if (!settings.publishLocation) {
                            swiped = "Location reporting is off"
                        } else {
                            swiped = "Publishing position..."
                            AnkyraService.reportLocationNow(context) { sent ->
                                // False covers both no fix and no running
                                // service, and this cannot tell them apart --
                                // so it says the thing that is true of both
                                // rather than guessing at the reason.
                                swiped = if (sent) "Position sent" else "Could not send a position"
                            }
                        }
                    }
                }
            ) { _, amount -> travelled += amount }
        }
    }

    Column(modifier = modifier.fillMaxSize().then(sideSwipeModifier)) {
        // Outside the list rather than its first row: what the connection is
        // doing should not scroll away, since it is the thing that tells you
        // whether the board under it is worth reading.
        StatusHeader(
            state = state,
            lastUpdated = lastUpdated,
            stale = stale,
            onEditConnection = onEditConnection,
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp)
        )

        // Only when there is something to say: an empty line still takes one,
        // and the board would shift under the reader every time it cleared.
        if (swiped.isNotEmpty()) {
            Text(
                text = swiped,
                style = MaterialTheme.typography.bodySmall,
                color = LocalAppTheme.current.dim,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 4.dp)
            )
        }

        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = {
                refreshing = true
                AnkyraService.requestBoard(context)
            },
            modifier = Modifier.fillMaxSize()
        ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
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
            // No preview means the renderer had nothing worth a card -- a
            // stop with nothing due says so by not being there.
            items(Targets.preview(entry), key = { "${entry.key}-${it.id}" }) { preview ->
                PreviewCard(preview)
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
    }
}

@Composable
private fun StatusHeader(
    state: AnkyraClient.State,
    lastUpdated: Long?,
    stale: Boolean,
    onEditConnection: (() -> Unit)?,
    modifier: Modifier = Modifier
) {
    val palette = LocalAppTheme.current
    Row(
        modifier = modifier.fillMaxWidth(),
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
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
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
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Glyph(row.iconRes, size = 16.dp, tint = palette.dim)
        if (row.text.isNotEmpty()) {
            // Takes the space between, so the values end up against the right
            // edge rather than trailing whatever length the label happened to
            // be -- the times of one route line up under the times of the
            // next. A long station name loses its tail rather than pushing
            // the counts off the card.
            Text(
                row.text,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
        } else {
            // Nothing to label them with, but the values still belong in the
            // same column as every other row's.
            Spacer(Modifier.weight(1f))
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
