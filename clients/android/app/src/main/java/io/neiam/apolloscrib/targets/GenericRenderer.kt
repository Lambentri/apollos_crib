package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Whatever the publisher sent.
 *
 * Cronos, Packages and Const are passthroughs: the condenser does not
 * normalise them and the crate types them as raw JSON, so there is no shape
 * here to render against. Rather than leave them off the board, this reads the
 * top level of each record -- field and value, in the order they arrived.
 *
 * Deliberately shallow. Anything nested is reported as what it is rather than
 * flattened into an unreadable line, because a card that says "3 items" is
 * more use than one that says "[object Object]".
 */
class GenericRenderer(
    override val type: SourceType,
    override val iconRes: Int,
    override val label: String,
    override val description: String
) : SourceRenderer {

    override fun preview(entry: VisionEntry): List<Preview> {
        val records = when (val data = entry.data) {
            is JsonArray -> data
            is JsonObject -> listOf(data)
            else -> emptyList()
        }

        val rows = records.flatMap { record ->
            when (record) {
                is JsonObject -> record.map { (key, value) ->
                    Row(
                        iconRes = R.drawable.fa_list,
                        text = key.humanise(),
                        stamps = listOf(Stamp(R.drawable.fa_circle_info, value.brief()))
                    )
                }
                // A bare value in a list has no field to name it.
                else -> listOf(Row(R.drawable.fa_list, record.brief()))
            }
        }

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = rows.firstOrNull()?.let { "${it.text} ${it.stamps.firstOrNull()?.text.orEmpty()}".trim() },
                iconRes = iconRes,
                rows = rows,
                empty = "Nothing published"
            )
        )
    }

    private fun kotlinx.serialization.json.JsonElement.brief(): String = when (this) {
        is JsonNull -> "—"
        is JsonPrimitive -> content
        is JsonArray -> "${size} item${if (size == 1) "" else "s"}"
        is JsonObject -> "${size} field${if (size == 1) "" else "s"}"
    }

    private fun String.humanise(): String =
        replace('_', ' ').replaceFirstChar { it.uppercase() }
}
