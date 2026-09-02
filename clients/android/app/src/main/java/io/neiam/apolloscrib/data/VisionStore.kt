package io.neiam.apolloscrib.data

import android.content.Context
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry
import io.neiam.apolloscrib.types.Wire
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/**
 * The last payload Ankyra published, on disk.
 *
 * It has to be on disk rather than in memory: a Target provider is a
 * ContentProvider that Smartspacer calls into a process which may have been
 * started for that call alone, with no MQTT connection behind it and no
 * message due for another tick. What the phone last heard is the answer to
 * "what is at this stop", so it is what gets drawn, with its age shown when
 * it has gone stale.
 */
class VisionStore(context: Context) {

    private val file = File(context.applicationContext.filesDir, FILE_NAME)

    fun save(payload: String) {
        // Written whole then moved, so a provider reading mid-write sees the
        // previous payload rather than half of this one.
        val temp = File(file.parentFile, "$FILE_NAME.tmp")
        temp.writeText(payload)
        temp.renameTo(file)
        // The Targets re-read on every call, so they need no telling. The
        // settings screen is the one reader that stays on screen across a
        // tick, and it has to be told the file underneath it has moved.
        revision.value = revision.value + 1
    }

    fun entries(): List<VisionEntry> {
        val payload = runCatching { file.readText() }.getOrNull() ?: return emptyList()
        return runCatching { Wire.parse(payload) }.getOrDefault(emptyList())
    }

    fun entries(type: SourceType): List<VisionEntry> = entries().filter { it.type == type }

    fun entry(key: String): VisionEntry? = entries().firstOrNull { it.key == key }

    /** When the stored payload last arrived, or null if nothing ever has. */
    fun lastUpdated(): Long? = file.takeIf { it.exists() }?.lastModified()

    /**
     * Whether what is on disk is old enough to be worth saying so. A Pythiae
     * ticks every ten seconds and only publishes on change, so a few minutes
     * of quiet is normal and half an hour is not.
     */
    fun isStale(): Boolean {
        val at = lastUpdated() ?: return true
        return System.currentTimeMillis() - at > STALE_AFTER_MS
    }

    companion object {
        /**
         * Bumped on every board that lands, for anything holding a composition
         * open over one. Process-local, which is all that is needed: the
         * service that writes and the screen that watches are the same process.
         */
        val revision = MutableStateFlow(0L)
        val boards: StateFlow<Long> get() = revision

        private const val FILE_NAME = "vision.json"
        private const val STALE_AFTER_MS = 30 * 60 * 1000L
    }
}
