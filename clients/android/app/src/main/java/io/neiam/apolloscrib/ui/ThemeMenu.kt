package io.neiam.apolloscrib.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.neiam.apolloscrib.ui.shader.LocalBackgrounds
import io.neiam.apolloscrib.ui.shader.Patterns
import io.neiam.apolloscrib.ui.shader.ShaderSettings
import io.neiam.apolloscrib.ui.theme.ALL_THEMES
import io.neiam.apolloscrib.ui.theme.SYSTEM_THEME_KEY

/**
 * party²'s theme picker: System, then each palette; then the background
 * patterns, and the way into their effects.
 *
 * A bare dropdown rather than party²'s palette button, because this app has
 * no icon set to draw one from -- whoever shows it puts it in a Box beside
 * the thing that opens it.
 */
@Composable
fun ThemeMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    themeKey: String,
    onPick: (String) -> Unit
) {
    val backgrounds = LocalBackgrounds.current
    val mine = backgrounds.mine
    var effects by remember { mutableStateOf(false) }
    fun ticked(on: Boolean, label: String) = if (on) "• $label" else label

    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        DropdownMenuItem(
            text = { Text(ticked(themeKey == SYSTEM_THEME_KEY, "System")) },
            onClick = { onDismiss(); onPick(SYSTEM_THEME_KEY) },
        )
        ALL_THEMES.forEach { theme ->
            DropdownMenuItem(
                text = { Text(ticked(theme.key == themeKey, theme.name)) },
                onClick = { onDismiss(); onPick(theme.key) },
            )
        }
        HorizontalDivider()
        Text(
            "Background",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        )
        DropdownMenuItem(
            text = { Text(ticked(mine.pattern == Patterns.OFF, "Off")) },
            onClick = { onDismiss(); backgrounds.update(mine.copy(pattern = Patterns.OFF)) },
        )
        Patterns.all.forEach { pattern ->
            DropdownMenuItem(
                text = { Text(ticked(mine.pattern == pattern.key, pattern.label)) },
                onClick = { onDismiss(); backgrounds.update(mine.copy(pattern = pattern.key)) },
            )
        }
        DropdownMenuItem(
            text = { Text("Background effects…") },
            onClick = { onDismiss(); effects = true },
        )
    }

    if (effects) EffectsDialog(onDismiss = { effects = false })
}

/**
 * The same choices as [ThemeMenu]'s background half, laid out for the
 * connection screen: a row of patterns and a button into the effects.
 */
@Composable
fun BackgroundControls() {
    val backgrounds = LocalBackgrounds.current
    val mine = backgrounds.mine
    var effects by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Background", style = MaterialTheme.typography.titleMedium)
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            PickChip("Off", mine.pattern == Patterns.OFF) {
                backgrounds.update(mine.copy(pattern = Patterns.OFF))
            }
            Patterns.all.forEach { pattern ->
                PickChip(pattern.label, mine.pattern == pattern.key) {
                    backgrounds.update(mine.copy(pattern = pattern.key))
                }
            }
        }
        Patterns.all.firstOrNull { it.key == mine.pattern }?.let {
            Text(
                it.about,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        OutlinedButton(onClick = { effects = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Background effects…")
        }
    }

    if (effects) EffectsDialog(onDismiss = { effects = false })
}

/** A chip that shows whether it is the current pick, as the theme row does. */
@Composable
fun PickChip(label: String, selected: Boolean, onClick: () -> Unit) {
    AssistChip(
        onClick = onClick,
        label = { Text(label) },
        colors = if (selected) {
            AssistChipDefaults.assistChipColors(
                containerColor = MaterialTheme.colorScheme.primary,
                labelColor = MaterialTheme.colorScheme.onPrimary
            )
        } else {
            AssistChipDefaults.assistChipColors()
        }
    )
}

/** party²'s background effects, applied live behind the dialog. */
@Composable
private fun EffectsDialog(onDismiss: () -> Unit) {
    val backgrounds = LocalBackgrounds.current
    val s = backgrounds.mine
    fun set(next: ShaderSettings) = backgrounds.update(next)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Background effects") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Toggle("Glint", "a band of light sweeping across every minute and a half", s.glints) { set(s.copy(glints = it)) }
                Toggle("Breathing", "the pattern slowly swelling and easing", s.breathing) { set(s.copy(breathing = it)) }
                Toggle("Foreground discs", "large defocused discs drifting past now and then", s.foreground) { set(s.copy(foreground = it)) }
                Toggle("Film grain", "a fine moving noise", s.grain) { set(s.copy(grain = it)) }
                Toggle("Dither", "keeps slow gradients from banding", s.dither) { set(s.copy(dither = it)) }
                Text("Bokeh lights: ${s.lights}", style = MaterialTheme.typography.labelMedium)
                Slider(
                    value = s.lights.toFloat(),
                    onValueChange = { set(s.copy(lights = it.toInt())) },
                    valueRange = 4f..64f,
                    steps = 59,
                )
                Text("Speed: ${s.speed}×", style = MaterialTheme.typography.labelMedium)
                Slider(
                    value = s.speed.toFloat(),
                    onValueChange = { set(s.copy(speed = Math.round(it * 4) / 4.0)) },
                    valueRange = 0.25f..4f,
                    steps = 14,
                )
                Text(
                    "Colours follow the theme.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
    )
}

@Composable
private fun Toggle(name: String, about: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
    ) {
        Column(Modifier.weight(1f)) {
            Text(name)
            Text(
                about,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
