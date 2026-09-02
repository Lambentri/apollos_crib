package io.neiam.apolloscrib.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.compose.foundation.text.KeyboardOptions
import io.neiam.apolloscrib.data.Pairing
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.ui.theme.ALL_THEMES
import io.neiam.apolloscrib.ui.theme.CribTheme
import io.neiam.apolloscrib.ui.theme.LocalAppTheme
import io.neiam.apolloscrib.ui.theme.appThemeByKey
import io.neiam.apolloscrib.data.VisionStore
import android.content.Intent
import android.widget.Toast
import io.neiam.apolloscrib.mqtt.AnkyraClient
import io.neiam.apolloscrib.mqtt.AnkyraService
import java.text.DateFormat
import java.util.Date

/**
 * The connection, and what has arrived over it.
 *
 * Deliberately one screen: the app itself is plumbing for the Targets, and
 * everything the user configures per Target is configured from Smartspacer.
 */
class MainActivity : ComponentActivity() {

    /**
     * Bumped when a pairing link lands, so the fields below re-read what it
     * wrote rather than keeping what the user was looking at.
     */
    private val paired = mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val settings = Settings(this)
        val store = VisionStore(this)

        pair(intent, settings)

        setContent {
            var themeKey by remember { mutableStateOf(settings.themeKey) }
            CribTheme(theme = appThemeByKey(themeKey)) {
                Scaffold { padding ->
                    ConnectionScreen(
                        modifier = Modifier.fillMaxSize().padding(padding),
                        settings = settings,
                        store = store,
                        pairingKey = paired.value,
                        themeKey = themeKey,
                        onThemeChange = {
                            settings.themeKey = it
                            themeKey = it
                        },
                        onConnect = {
                            AnkyraService.start(this)
                        },
                        onDisconnect = { AnkyraService.stop(this) }
                    )
                }
            }
        }
    }

    // singleTop, so a scan while the app is already open arrives here rather
    // than as a second copy of the activity.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pair(intent, Settings(this))
    }

    /**
     * Take a pairing link, if this intent is one, and connect on it. Said out
     * loud: a scan that silently rewrote the connection would be indistinguishable
     * from one that did nothing.
     */
    private fun pair(intent: Intent?, settings: Settings) {
        val pairing = Pairing.from(intent?.data) ?: return
        pairing.applyTo(settings)
        paired.value = paired.value + 1
        AnkyraService.start(this)
        Toast.makeText(this, "Paired with ${pairing.topic}", Toast.LENGTH_LONG).show()
    }
}

@Composable
private fun ConnectionScreen(
    modifier: Modifier = Modifier,
    settings: Settings,
    store: VisionStore,
    pairingKey: Int,
    themeKey: String,
    onThemeChange: (String) -> Unit,
    onConnect: () -> Unit,
    onDisconnect: () -> Unit
) {
    var host by remember(pairingKey) { mutableStateOf(settings.host) }
    var port by remember(pairingKey) { mutableStateOf(settings.port.toString()) }
    var username by remember(pairingKey) { mutableStateOf(settings.username) }
    var password by remember(pairingKey) { mutableStateOf(settings.password) }
    var topic by remember(pairingKey) { mutableStateOf(settings.topic) }
    var tls by remember(pairingKey) { mutableStateOf(settings.useTls) }

    val state by AnkyraService.connectionState.collectAsState()
    val boards by VisionStore.boards.collectAsState()

    // Android 13+ will not show the service's notification without this, and
    // the service is the connection -- so it is asked for here rather than
    // being allowed to fail quietly later.
    val notifications = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    Column(
        modifier = modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Ankyra", style = MaterialTheme.typography.headlineSmall)
        Text(
            "The rabbit user your Pythiae publishes to. Find these under " +
                "cfg/ankyra in Apollo's Crib -- the client id below must be " +
                "registered there, or auto-registration left on.",
            style = MaterialTheme.typography.bodySmall
        )

        OutlinedTextField(
            value = host,
            onValueChange = { host = it },
            label = { Text("Broker host") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = port,
            onValueChange = { port = it.filter(Char::isDigit) },
            label = { Text("Port") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Username") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = topic,
            onValueChange = { topic = it },
            label = { Text("Topic") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Column {
            Text("TLS", style = MaterialTheme.typography.bodyLarge)
            Switch(checked = tls, onCheckedChange = { tls = it })
        }

        Text("Client id: ${settings.clientId}", style = MaterialTheme.typography.bodySmall)

        Button(
            onClick = {
                settings.host = host
                settings.port = port.toIntOrNull() ?: 1883
                settings.username = username
                settings.password = password
                settings.topic = topic
                settings.useTls = tls
                notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                onConnect()
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Save and connect")
        }
        OutlinedButton(onClick = onDisconnect, modifier = Modifier.fillMaxWidth()) {
            Text("Disconnect")
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                val palette = LocalAppTheme.current
                Text(
                    when (state) {
                        AnkyraClient.State.Connected -> "Connected"
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
                // Keyed on the board count so a new payload redraws this card.
                val last = remember(boards) { store.lastUpdated() }
                Text(
                    if (last == null) "No board received yet"
                    else "Last board ${DateFormat.getTimeInstance().format(Date(last))}",
                    style = MaterialTheme.typography.bodySmall
                )
                val entries = remember(boards) { store.entries() }
                if (entries.isNotEmpty()) {
                    Text(
                        "${entries.size} queries: " +
                            entries.joinToString(", ") { it.label() },
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        Text("Theme", style = MaterialTheme.typography.titleMedium)
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ALL_THEMES.forEach { theme ->
                AssistChip(
                    onClick = { onThemeChange(theme.key) },
                    label = { Text(theme.name) },
                    colors = if (theme.key == themeKey) {
                        AssistChipDefaults.assistChipColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            labelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    } else {
                        AssistChipDefaults.assistChipColors()
                    }
                )
            }
        }

        Text(
            "Add the Targets from Smartspacer's own settings -- Targets, then " +
                "Apollo's Crib. Each one asks which query it should show.",
            style = MaterialTheme.typography.bodySmall
        )
    }
}
