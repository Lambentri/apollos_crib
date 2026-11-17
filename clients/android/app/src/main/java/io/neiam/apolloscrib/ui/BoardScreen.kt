package io.neiam.apolloscrib.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.material3.CardDefaults
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import io.neiam.apolloscrib.data.CardAges
import io.neiam.apolloscrib.types.GtfsPlusCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
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
    onEditConnection: (() -> Unit)?,
    /** The theme in use, and how to change it. Null where it cannot be. */
    themeKey: String? = null,
    onPickTheme: ((String) -> Unit)? = null
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

    // Held here rather than in the header, because the header only offers the
    // gesture -- what changes is the whole board below it.
    val settings = remember { Settings(context) }
    var richCards by remember { mutableStateOf(settings.richCards) }
    var rotationMs by remember { mutableStateOf(settings.rotationMs) }
    var staticLarge by remember { mutableStateOf(settings.staticLarge) }
    var pinned by remember { mutableStateOf(settings.pinned) }

    // Read whatever the mode: a card's age is kept by comparing it with what
    // it said last time, and a card not looked at is a card forgotten -- so
    // the detailed reading has to be watched even while the compact board is
    // the one on screen, or every switch would make it all new again.
    val plus = remember(boards) { store.plusEntries() }

    // A clock for anything that goes stale by the minute rather than by the
    // board: a card's age, and a compact row's "in 4 min".
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(30_000)
            now = System.currentTimeMillis()
        }
    }
    LaunchedEffect(boards) { now = System.currentTimeMillis() }

    // The compact board, one card per preview, each with a key a pin can
    // hold onto.
    val compact: List<CompactItem> = remember(entries, now) {
        entries.flatMap { entry -> Targets.preview(entry).map { CompactItem(entry, it) } }
    }

    // Everything the board has, as cards of one weight, in one order.
    //
    // Transit first and soonest first within it, because a departure is the
    // only thing here that expires -- the weather is as true in ten minutes as
    // it is now, and a bus is not. Everything else follows in the order the
    // board gave it.
    val cards: List<RichItem> = remember(plus) {
        val routes = plus
            .flatMap { entry ->
                entry.decode<List<GtfsPlusCondensed>>().orEmpty().map { entry to it }
            }
            .sortedBy { (_, route) ->
                route.arrivals.firstNotNullOfOrNull { it.best() } ?: "99:99:99"
            }
            .map { (entry, route) -> RichItem.Transit(entry, route) }

        val others = plus
            .filter { it.type != SourceType.GtfsPlus }
            .mapNotNull { entry -> factsFor(entry)?.let { RichItem.Facts(entry, it) } }

        routes + others
    }

    // How old each card is: what it says now against what it said before.
    // Fingerprinted from the data rather than from what is drawn, because a
    // drawn "in 4 min" changes every minute without anything having been
    // heard.
    val ages = remember { CardAges(context) }
    var seen by remember { mutableStateOf(ages.load()) }
    val fingerprints: Map<String, Int> = remember(compact, cards) {
        compact.associate { it.key to it.entry.data.toString().hashCode() } +
            cards.associate { card ->
                card.key to when (card) {
                    is RichItem.Transit -> card.route.toString().hashCode()
                    is RichItem.Facts -> card.entry.data.toString().hashCode()
                }
            }
    }
    LaunchedEffect(fingerprints) {
        val next = Freshness.observe(seen, fingerprints, System.currentTimeMillis())
        if (next != seen) {
            seen = next
            ages.save(next)
        }
    }
    val quiet: Set<String> = remember(seen, now) {
        seen.filterValues { Freshness.isStale(it, now) }.keys
    }

    // Cards held in the rotation. They sit above it and do not turn; the
    // rest turn underneath them in whatever room is left.
    var holds by remember { mutableStateOf(Holds(settings.held, settings.dormant)) }
    fun keepHolds(next: Holds) {
        if (next == holds) return
        holds = next
        settings.held = next.order
        settings.dormant = next.dormant
    }
    val cardKeys = remember(cards) { cards.map { it.key }.toSet() }

    // A dormant card that has updated wakes now rather than on the next turn:
    // it is news, and news should not wait twelve seconds.
    LaunchedEffect(cardKeys, quiet) { keepHolds(holds.settle(cardKeys, quiet)) }

    val byKey = remember(cards) { cards.associateBy { it.key } }
    val heldCards = if (richCards > 0) holds.shown.mapNotNull { byKey[it] } else emptyList()
    // Dormant ones are left out too: dropping off means gone, not back in
    // with the others.
    val turning = remember(cards, holds) { cards.filter { !holds.isHeld(it.key) } }

    // At least one slot keeps turning, however many are held. Holding every
    // slot would stop the rotation for good, and then nothing new could come
    // round to be held in its turn.
    val slots = if (heldCards.isEmpty()) richCards else maxOf(1, richCards - heldCards.size)

    // Rotated only when there is more than fits. Turning a list that is
    // already whole would take cards away and give them back for nothing.
    val rotating = richCards > 0 && turning.size > slots
    val turn = rememberRotation(turning.size, slots, rotationMs)
    val advance = turn.advance

    // A held card counts its quiet turns even when nothing is turning -- one
    // held card and nothing else would otherwise never drop off. The interval
    // stands in for the turn it would have been.
    var idleTurns by remember { mutableIntStateOf(0) }
    LaunchedEffect(richCards, rotating, rotationMs) {
        if (richCards == 0 || rotating) return@LaunchedEffect
        while (true) {
            kotlinx.coroutines.delay(rotationMs.toLong())
            idleTurns += 1
        }
    }
    val turnsTaken = turn.turns + idleTurns
    var lastTurns by remember { mutableIntStateOf(turnsTaken) }
    LaunchedEffect(turnsTaken) {
        if (turnsTaken != lastTurns) {
            lastTurns = turnsTaken
            if (richCards > 0) keepHolds(holds.turned(cardKeys, quiet))
        }
    }

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

    Box(modifier.fillMaxSize()) {
    Column(modifier = Modifier.fillMaxSize().then(sideSwipeModifier)) {
        // Outside the list rather than its first row: what the connection is
        // doing should not scroll away, since it is the thing that tells you
        // whether the board under it is worth reading.
        StatusHeader(
            state = state,
            lastUpdated = lastUpdated,
            stale = stale,
            richCards = richCards,
            rotation = turn.progress,
            rotationMs = rotationMs,
            rotating = rotating,
            staticLarge = staticLarge,
            onCycleSpeed = {
                val choices = Settings.ROTATION_CHOICES
                rotationMs = choices[(choices.indexOf(rotationMs) + 1) % choices.size]
                settings.rotationMs = rotationMs
            },
            onToggleStaticSize = {
                staticLarge = !staticLarge
                settings.staticLarge = staticLarge
            },
            onToggleRich = {
                // One more each time, and off the end back to the compact
                // board -- so the gesture always has somewhere to go and never
                // needs a second one to undo it.
                richCards = (richCards + 1) % (Settings.MAX_RICH_CARDS + 1)
                settings.richCards = richCards
            },
            onEditConnection = onEditConnection,
            themeKey = themeKey,
            onPickTheme = onPickTheme,
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

        // What a long press on a card does, and what that card looks like for
        // it: held in the rotation, pinned on the static board.
        val marking: (String) -> CardMark = if (richCards > 0) {
            { key ->
                CardMark(
                    marked = holds.isHeld(key),
                    stale = key in quiet,
                    label = if (holds.isHeld(key)) "Release this card" else "Hold this card",
                    toggle = { keepHolds(holds.toggle(key)) }
                )
            }
        } else {
            { key ->
                CardMark(
                    marked = key in pinned,
                    stale = key in quiet,
                    label = if (key in pinned) "Unpin this card" else "Pin this card to the top",
                    toggle = {
                        pinned = togglePin(pinned, key)
                        settings.pinned = pinned
                    }
                )
            }
        }

        if ((richCards > 0 || staticLarge) && entries.isNotEmpty() && cards.isEmpty()) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(
                        Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            "No detailed board yet",
                            style = MaterialTheme.typography.titleMedium
                        )
                        Text(
                            "The extended reading is published separately, and only " +
                                "when the Pythiae is asked for it. " +
                                if (richCards > 0) "Hold the compass again to go back."
                                else "Tap the compass to go back to the compact cards.",
                            style = MaterialTheme.typography.bodySmall,
                            color = LocalAppTheme.current.dim
                        )
                    }
                }
            }
        }

        if (richCards > 0) {

            // Held cards first, above the turn and out of it.
            items(heldCards, key = { "held-${it.key}" }) { card ->
                RichItemCard(
                    card,
                    marking(card.key),
                    Modifier.animateItem(
                        fadeInSpec = tween(220),
                        placementSpec = spring(stiffness = Spring.StiffnessMediumLow),
                        fadeOutSpec = tween(160)
                    )
                )
            }

            // One card is a different animation from three.
            //
            // With a stack, a turn moves two cards and replaces one, and the
            // movement is the story -- `animateItem` shows what stayed. With a
            // single card nothing stays, so there is nothing to move and a
            // fade is all a list animation can offer. That reads as a stutter
            // rather than a turn.
            //
            // So it gets its own: the old card leaves upward and the new one
            // arrives from below, which is the direction a flick pushes it.
            // The gesture and the animation then agree about which way the
            // board runs, and the timer's turn looks like the one you make.
            //
            // Only while nothing is held: with a held card above it there are
            // two cards on screen, and the stack's animation is the right one.
            if (richCards == 1 && heldCards.isEmpty() && turn.window.isNotEmpty()) {
                item(key = "single") {
                    val card = turning[turn.window.first()]

                    AnimatedContent(
                        targetState = card,
                        transitionSpec = {
                            (slideInVertically(tween(320)) { height -> height } +
                                fadeIn(tween(220)))
                                .togetherWith(
                                    slideOutVertically(tween(320)) { height -> -height } +
                                        fadeOut(tween(180))
                                )
                        },
                        label = "card"
                    ) { shown -> RichItemCard(shown, marking(shown.key)) }
                }
            } else {
            items(turn.window.map { turning[it] }, key = { it.key }) { card ->
                // Keyed, so the list knows the two cards that stayed are the
                // same two cards. Without that every turn is three removals
                // and three insertions, and nothing can be animated because
                // nothing persisted.
                val slide = Modifier.animateItem(
                    fadeInSpec = tween(220),
                    placementSpec = spring(stiffness = Spring.StiffnessMediumLow),
                    fadeOutSpec = tween(160)
                )

                RichItemCard(card, marking(card.key), slide)
            }
            }
        } else if (staticLarge) {
            // Every detailed card at once, pinned ones first. Animated so a
            // pin is seen to rise rather than the list just being different.
            items(pinnedFirst(cards, pinned) { it.key }, key = { it.key }) { card ->
                RichItemCard(card, marking(card.key), Modifier.animateItem())
            }
        } else {
            // No preview means the renderer had nothing worth a card -- a
            // stop with nothing due says so by not being there.
            items(pinnedFirst(compact, pinned) { it.key }, key = { it.key }) { item ->
                PreviewCard(item.preview, marking(item.key), Modifier.animateItem())
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

    // A strip along the bottom edge, and only while something is turning.
    //
    // The board scrolls, so a drag anywhere in it belongs to the list -- this
    // takes the last few millimetres, which is where a flick up from off the
    // screen starts and where no card is expecting to be read. Absent when
    // there is nothing to advance, so it never takes a touch it has no use
    // for.
    if (rotating) {
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(28.dp)
                .pointerInput(Unit) {
                    var travelled = 0f

                    detectVerticalDragGestures(
                        onDragStart = { travelled = 0f },
                        onDragEnd = {
                            // Upward is negative. A flick rather than a nudge:
                            // far enough that resting a thumb on the edge does
                            // not turn the card you were reading.
                            if (travelled < -40.dp.toPx()) advance()
                        }
                    ) { _, amount -> travelled += amount }
                }
        )
    }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun StatusHeader(
    state: AnkyraClient.State,
    lastUpdated: Long?,
    stale: Boolean,
    richCards: Int,
    /** How far through the card rotation, or null when nothing is rotating. */
    rotation: Float?,
    rotationMs: Int,
    rotating: Boolean,
    staticLarge: Boolean,
    onCycleSpeed: () -> Unit,
    onToggleStaticSize: () -> Unit,
    onToggleRich: () -> Unit,
    onEditConnection: (() -> Unit)?,
    themeKey: String?,
    onPickTheme: ((String) -> Unit)?,
    modifier: Modifier = Modifier
) {
    val palette = LocalAppTheme.current
    val heading by rememberHeading()
    var themeMenu by remember { mutableStateOf(false) }
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top
    ) {
        // The name, and when the board it is showing arrived. What the screen
        // is, on the left, where reading starts.
        Column(Modifier.weight(1f)) {
            // The name is the way into the theme: the board has no toolbar
            // to put a palette button in, and the name is the one thing in
            // the header that is not a readout.
            Box {
                Text(
                    "Apollo's",
                    style = MaterialTheme.typography.headlineSmall,
                    color = palette.accent,
                    modifier = if (onPickTheme != null) {
                        Modifier.clickable(onClickLabel = "Theme and background") {
                            themeMenu = true
                        }
                    } else {
                        Modifier
                    }
                )
                if (onPickTheme != null && themeKey != null) {
                    ThemeMenu(
                        expanded = themeMenu,
                        onDismiss = { themeMenu = false },
                        themeKey = themeKey,
                        onPick = onPickTheme
                    )
                }
            }
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
        // Between the two, because it belongs to neither: the cards say a stop
        // is NE of you and this says which way NE is. Nothing to read without
        // both, which is why it sits where the eye crosses from one to the
        // other.
        Compass(
            heading,
            rotation = rotation,
            modifier = Modifier
                .padding(horizontal = 12.dp)
                // A long press rather than a tap: the compass is a readout,
                // and something you read should not change the screen when
                // your thumb brushes it. Nothing is bound to the short press,
                // so a stray tap does nothing at all.
                .combinedClickable(
                    // While something is turning, how fast. On the static
                    // board, which size of card it draws -- the one setting
                    // there is to see the effect of. In a detailed mode with
                    // nothing to turn it does nothing: a tap that silently
                    // changes a setting you cannot see is worse than none.
                    onClick = {
                        when {
                            rotating -> onCycleSpeed()
                            richCards == 0 -> onToggleStaticSize()
                        }
                    },
                    onClickLabel = when {
                        rotating -> "Change how long each card stays"
                        richCards == 0 && staticLarge -> "Show compact cards"
                        richCards == 0 -> "Show detailed cards"
                        else -> null
                    },
                    onLongClick = onToggleRich,
                    onLongClickLabel =
                        if (richCards == Settings.MAX_RICH_CARDS) {
                            "Show every card"
                        } else {
                            "Show ${richCards + 1} detailed card" +
                                if (richCards == 0) "" else "s"
                        }
                )
        )

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
private fun PreviewCard(preview: Preview, mark: CardMark, modifier: Modifier = Modifier) {
    val palette = LocalAppTheme.current
    Card(modifier.marked(mark).fillMaxWidth()) {
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

/**
 * What a long press does to a card, and how the card shows it.
 *
 * @property marked held in the rotation, or pinned on the static board --
 *   drawn with an accent edge either way, since it is the same promise:
 *   this one stays where you put it
 * @property stale has said the same thing for long enough to be suspect
 */
class CardMark(
    val marked: Boolean,
    val stale: Boolean,
    val label: String,
    val toggle: () -> Unit
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Modifier.marked(mark: CardMark): Modifier {
    // Faded rather than greyed: still readable, plainly not current. Eased,
    // so a card going quiet mid-read does not blink.
    val alpha by animateFloatAsState(if (mark.stale) 0.4f else 1f, tween(600), label = "stale")
    val edge = if (mark.marked) {
        Modifier.border(2.dp, LocalAppTheme.current.accent, CardDefaults.shape)
    } else {
        Modifier
    }
    return this
        .graphicsLayer { this.alpha = alpha }
        .then(edge)
        .clip(CardDefaults.shape)
        // Long press only. A tap on a card is somebody reading it, and should
        // not move it anywhere.
        .combinedClickable(
            onClick = {},
            onLongClick = mark.toggle,
            onLongClickLabel = mark.label
        )
}

@Composable
private fun RichItemCard(card: RichItem, mark: CardMark, modifier: Modifier = Modifier) {
    val m = modifier.marked(mark)
    when (card) {
        is RichItem.Transit -> RichCard(card.entry, card.route, m)
        is RichItem.Facts -> RichFactsCard(card.facts, m)
    }
}

/** One compact card, and the key a pin holds it by. */
data class CompactItem(val entry: VisionEntry, val preview: Preview) {
    val key: String get() = "${entry.key}-${preview.id}"
}

/**
 * One card in the detailed rotation.
 *
 * Transit keeps its own shape because it has genuinely more to say -- a list
 * of departures, each with its own delay and crowding -- where everything else
 * is a headline and some named facts. Both are cards of the same weight, which
 * is what lets them share one turn.
 */
sealed interface RichItem {
    val key: String

    data class Transit(
        val entry: VisionEntry,
        val route: io.neiam.apolloscrib.types.GtfsPlusCondensed
    ) : RichItem {
        override val key = "${entry.key}-${route.route}-${route.dest}"
    }

    data class Facts(val entry: VisionEntry, val facts: RichFacts) : RichItem {
        override val key = entry.key
    }
}
