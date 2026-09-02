package io.neiam.apolloscrib.ui

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kieronquinn.app.smartspacer.sdk.SmartspacerConstants
import com.kieronquinn.app.smartspacer.sdk.provider.SmartspacerTargetProvider
import io.neiam.apolloscrib.data.Settings
import io.neiam.apolloscrib.ui.theme.CribTheme
import io.neiam.apolloscrib.data.VisionStore
import io.neiam.apolloscrib.targets.Targets
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Which query a Target instance shows.
 *
 * Smartspacer opens this twice over a Target's life: once as the setup
 * activity when it is added, where finishing with anything but `RESULT_OK`
 * cancels the add, and later as the config activity from its settings. The
 * same screen serves both -- the choice is the whole of the configuration.
 */
class ConfigurationActivity : ComponentActivity() {

    private lateinit var settings: Settings
    private lateinit var store: VisionStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        settings = Settings(this)
        store = VisionStore(this)

        val smartspacerId = intent.getStringExtra(SmartspacerConstants.EXTRA_SMARTSPACER_ID)
            ?: intent.getStringExtra(EXTRA_SMARTSPACER_ID)
        val type = intent.getStringExtra(EXTRA_SOURCE_TYPE)?.let { SourceType.of(it) }

        if (smartspacerId == null) {
            // Nothing to bind. Not an error worth a dialog -- Smartspacer only
            // omits the id when it is asking for a generic config.
            setResult(Activity.RESULT_CANCELED)
            finish()
            return
        }

        val candidates = type?.let { store.entries(it) } ?: store.entries()

        setContent {
            CribTheme {
                Scaffold { padding ->
                    QueryPicker(
                        modifier = Modifier.fillMaxSize().padding(padding),
                        candidates = candidates,
                        selected = settings.boundKey(smartspacerId),
                        onPick = { entry -> bind(smartspacerId, entry) }
                    )
                }
            }
        }
    }

    private fun bind(smartspacerId: String, entry: VisionEntry) {
        settings.bind(smartspacerId, entry.key)
        Targets.notifyAll(this)
        // RESULT_OK is what tells Smartspacer the add succeeded; without it a
        // newly added Target is silently dropped.
        setResult(Activity.RESULT_OK)
        finish()
    }

    companion object {
        const val EXTRA_SMARTSPACER_ID = SmartspacerConstants.EXTRA_SMARTSPACER_ID
        const val EXTRA_SOURCE_TYPE = "io.neiam.apolloscrib.SOURCE_TYPE"
    }
}

@Composable
private fun QueryPicker(
    modifier: Modifier = Modifier,
    candidates: List<VisionEntry>,
    selected: String?,
    onPick: (VisionEntry) -> Unit
) {
    if (candidates.isEmpty()) {
        Column(modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Nothing to show yet", style = MaterialTheme.typography.titleLarge)
            Text(
                "Open Apollo's Crib, connect to your Ankyra, and wait for a board " +
                    "to arrive. Queries of this kind will be listed here once one has.",
                style = MaterialTheme.typography.bodyMedium
            )
        }
        return
    }

    LazyColumn(
        modifier = modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(candidates, key = { it.key }) { entry ->
            Card(
                modifier = Modifier.fillMaxWidth().clickable { onPick(entry) }
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text(entry.label(), style = MaterialTheme.typography.titleMedium)
                    Text(
                        if (entry.key == selected) "${entry.key} · showing now" else entry.key,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
    }
}
