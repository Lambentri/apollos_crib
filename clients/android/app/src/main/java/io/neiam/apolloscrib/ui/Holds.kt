package io.neiam.apolloscrib.ui

/**
 * When each card last said something new.
 *
 * The board as a whole has an age -- the file's mtime -- but a Pythiae
 * republishes every query whenever any one of them changes, so a fresh board
 * can still carry a weather reading nobody has touched in an hour. What a
 * card's age means is when *its* content last changed, which only comparing
 * it against what it said before can tell.
 *
 * @property fingerprint a digest of what the card said last time
 * @property changedAt when that last differed from the time before
 */
data class Seen(val fingerprint: Int, val changedAt: Long)

object Freshness {
    /**
     * A card that has said the same thing for this long is drawn dimmed.
     *
     * A Pythiae ticks every ten seconds and publishes on change, so a quarter
     * of an hour of the same answer means the source behind it has gone
     * quiet, not that nothing happened.
     */
    const val STALE_AFTER_MS = 15 * 60 * 1000L

    /**
     * Fold what is on the board now into what was seen before.
     *
     * A card whose fingerprint moved is fresh as of [now]; one that did not
     * keeps its old time. A card no longer on the board is forgotten, so that
     * when it comes back it comes back new -- which is what reappearing is.
     */
    fun observe(previous: Map<String, Seen>, now: Map<String, Int>, at: Long): Map<String, Seen> =
        now.mapValues { (key, fingerprint) ->
            val before = previous[key]
            if (before != null && before.fingerprint == fingerprint) before else Seen(fingerprint, at)
        }

    fun isStale(seen: Seen?, at: Long): Boolean =
        seen != null && at - seen.changedAt > STALE_AFTER_MS

    /** One line per card: `key \t fingerprint \t changedAt`. */
    fun encode(seen: Map<String, Seen>): String =
        seen.entries.joinToString("\n") { (k, v) -> "$k\t${v.fingerprint}\t${v.changedAt}" }

    fun decode(text: String): Map<String, Seen> =
        text.lineSequence()
            .mapNotNull { line ->
                val parts = line.split('\t')
                if (parts.size != 3) return@mapNotNull null
                val fp = parts[1].toIntOrNull() ?: return@mapNotNull null
                val at = parts[2].toLongOrNull() ?: return@mapNotNull null
                parts[0] to Seen(fp, at)
            }
            .toMap()
}

/**
 * Cards held in the rotation.
 *
 * A held card sits above the turning ones and does not turn. One that goes
 * quiet is dimmed, and after [DROP_AFTER] turns of being quiet it drops out
 * -- [dormant], still held but not drawn. The next time it updates it comes
 * back at the top, held again, which is where somebody who held it wants to
 * see it news from.
 *
 * Immutable: every change is a new value, so the screen can compare and
 * persist without tracking what moved.
 *
 * @property order held cards, top first
 * @property dormant held cards that dropped out, waiting for an update
 * @property quietTurns turns each drawn held card has spent stale
 */
data class Holds(
    val order: List<String> = emptyList(),
    val dormant: Set<String> = emptySet(),
    val quietTurns: Map<String, Int> = emptyMap()
) {
    /** The held cards to draw, top first. */
    val shown: List<String> get() = order.filter { it !in dormant }

    fun isHeld(key: String): Boolean = key in order

    /** Hold a card at the top, or release one already held. */
    fun toggle(key: String): Holds =
        if (isHeld(key)) {
            Holds(order - key, dormant - key, quietTurns - key)
        } else {
            copy(order = listOf(key) + order)
        }

    /**
     * Bring the holds up to date with the board, between turns.
     *
     * A dormant card that is back and fresh wakes, and moves to the top. A
     * drawn one that has left the board altogether goes dormant at once:
     * there is nothing to draw, and waiting out the turns would only leave a
     * gap where it was.
     */
    fun settle(present: Set<String>, stale: Set<String>): Holds {
        val waking = order.filter { it in dormant && it in present && it !in stale }
        val leaving = order.filter { it !in dormant && it !in present }
        if (waking.isEmpty() && leaving.isEmpty()) return this

        return Holds(
            order = waking + (order - waking.toSet()),
            dormant = dormant - waking.toSet() + leaving,
            quietTurns = quietTurns - waking.toSet() - leaving.toSet()
        )
    }

    /**
     * One turn of the rotation has passed. Each drawn held card that is stale
     * counts it; one that is fresh starts counting again from nothing.
     */
    fun turned(present: Set<String>, stale: Set<String>): Holds {
        val settled = settle(present, stale)
        val counts = HashMap<String, Int>()
        val dropping = mutableSetOf<String>()

        for (key in settled.shown) {
            if (key !in stale) continue
            val n = (settled.quietTurns[key] ?: 0) + 1
            if (n >= DROP_AFTER) dropping += key else counts[key] = n
        }

        return settled.copy(
            dormant = settled.dormant + dropping,
            quietTurns = counts
        )
    }

    companion object {
        /** Turns a stale held card is shown dimmed before it drops out. */
        const val DROP_AFTER = 3
    }
}

/**
 * The static board's order: pinned cards first, in the order they were
 * pinned (newest on top), then everything else as the board gave it.
 */
fun <T> pinnedFirst(items: List<T>, pinned: List<String>, key: (T) -> String): List<T> {
    val byKey = items.associateBy(key)
    val top = pinned.mapNotNull { byKey[it] }
    val pins = pinned.toSet()
    return top + items.filter { key(it) !in pins }
}

/** Pin a card to the top, or unpin it. */
fun togglePin(pinned: List<String>, key: String): List<String> =
    if (key in pinned) pinned - key else listOf(key) + pinned
