package io.neiam.apolloscrib.types

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject

/**
 * The Ankyra wire format.
 *
 * A Pythiae publishes one JSON object per tick, keyed `"<type>-<queryId>"`,
 * with either the wrapped shape (`{data, query}`) or, from a publisher that
 * could not resolve the query, the bare condensed list. Both are handled --
 * see `RoomSanctum.Worker.Pythiae.condense/2` in apollos-crib.
 *
 * These types mirror the `apollos-types` Rust crate, which is the source of
 * truth for the format. When a field is added there, add it here; anything
 * unknown is ignored rather than fatal, so a newer publisher does not break an
 * older phone.
 */
object Wire {
    val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
        coerceInputValues = true
    }

    /**
     * Parse a published payload into entries, dropping any the phone has no
     * renderer for. A single unparseable query does not take the rest of the
     * board down -- an Ankyra board is a dozen unrelated queries and one of
     * them being new or malformed is not a reason to show nothing.
     */
    fun parse(payload: String): List<VisionEntry> {
        val root = json.parseToJsonElement(payload).jsonObject
        return root.mapNotNull { (key, value) -> entry(key, value) }
    }

    /**
     * The source types in a payload that this build has no renderer for.
     *
     * Reported rather than swallowed: a vision of eight queries drawing five
     * cards is otherwise indistinguishable from three of them being broken.
     */
    fun unsupported(payload: String): List<String> {
        val root = runCatching { json.parseToJsonElement(payload).jsonObject }.getOrNull()
            ?: return emptyList()
        return root.keys
            .mapNotNull { key ->
                val dash = key.lastIndexOf('-')
                if (dash <= 0) null else key.substring(0, dash)
            }
            .filter { SourceType.of(it) == null }
            .distinct()
            .sorted()
    }

    private fun entry(key: String, value: JsonElement): VisionEntry? {
        // "gtfs-12" -- the id is everything after the last dash, since no
        // source type contains one but nothing guarantees that forever.
        val dash = key.lastIndexOf('-')
        if (dash <= 0) return null
        val type = SourceType.of(key.substring(0, dash)) ?: return null
        val id = key.substring(dash + 1)

        val obj = value as? JsonObject
        val wrapped = obj?.get("data")
        return if (wrapped != null) {
            val query = obj["query"]?.let {
                runCatching { json.decodeFromJsonElement(QueryInfo.serializer(), it) }.getOrNull()
            }
            VisionEntry(key, type, id, query?.name, query?.meta ?: emptyMap(), wrapped)
        } else {
            VisionEntry(key, type, id, null, emptyMap(), value)
        }
    }
}

/**
 * One query's answer, still undecoded. The concrete shape is decided by
 * [type], which comes from the key rather than from the body -- the publisher
 * sends no discriminator inside the data.
 */
data class VisionEntry(
    val key: String,
    val type: SourceType,
    val queryId: String,
    val queryName: String?,
    val meta: Map<String, JsonElement>,
    val data: JsonElement
) {
    /** What to call this on screen when the publisher named the query. */
    fun label(): String = queryName ?: "${type.label} $queryId"

    inline fun <reified T> decode(): T? =
        runCatching { Wire.json.decodeFromJsonElement<T>(data) }.getOrNull()
}

@Serializable
data class QueryInfo(
    val name: String,
    val meta: Map<String, JsonElement> = emptyMap()
)

/**
 * The source types apollos-crib publishes under. Only the ones with a renderer
 * are listed: [Wire.parse] drops the rest, so adding support for one is adding
 * it here plus a renderer.
 */
enum class SourceType(val wire: String, val label: String) {
    Gtfs("gtfs", "Transit"),
    Gbfs("gbfs", "Bikeshare"),
    Weather("weather", "Weather");

    companion object {
        fun of(wire: String): SourceType? = entries.firstOrNull { it.wire == wire }
    }
}
