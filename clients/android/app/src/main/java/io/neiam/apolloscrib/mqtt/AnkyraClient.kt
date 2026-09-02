package io.neiam.apolloscrib.mqtt

import android.util.Log
import com.hivemq.client.mqtt.MqttClient
import com.hivemq.client.mqtt.datatypes.MqttQos
import com.hivemq.client.mqtt.mqtt3.Mqtt3AsyncClient
import io.neiam.apolloscrib.data.Settings
import java.nio.charset.StandardCharsets

/**
 * A subscription to one Ankyra topic.
 *
 * RabbitMQ's MQTT plugin is what is on the other end: the Pythiae publishes to
 * the `amq.topic` exchange with the rabbit user's topic as the routing key,
 * and the plugin hands it to whoever subscribed to that topic. Which is to say
 * the topic string goes over the wire verbatim -- the same one in the LilyGo
 * client's config.
 *
 * MQTT 3.1.1 rather than 5: that is what the plugin speaks by default, and the
 * broker's client-id-shaped queue naming is what Ankyra counts consumers with.
 */
class AnkyraClient(
    private val settings: Settings,
    private val onMessage: (String) -> Unit,
    private val onState: (State) -> Unit
) {

    enum class State { Disconnected, Connecting, Connected, Failed }

    private var client: Mqtt3AsyncClient? = null

    /**
     * Which connection attempt is the live one.
     *
     * A replaced client goes on firing its listeners: HiveMQ reconnects on its
     * own, and tearing one down produces a disconnect event that arrives after
     * its replacement has already connected. Both write the same state, so the
     * late one wins and the screen sits on "Connecting" while payloads arrive.
     * Every listener checks it still belongs to the current attempt.
     *
     * Written from the main thread, read from HiveMQ's -- hence volatile.
     */
    @Volatile
    private var generation = 0

    fun connect() {
        if (!settings.isConfigured) {
            onState(State.Failed)
            return
        }
        disconnect()
        onState(State.Connecting)

        val attempt = ++generation

        val built = MqttClient.builder()
            .useMqttVersion3()
            .identifier(settings.clientId)
            .serverHost(settings.host)
            .serverPort(settings.port)
            .automaticReconnectWithDefaultConfig()
            // The connection outlives the call that opened it: HiveMQ
            // reconnects on its own, and a state read only from the callbacks
            // below would still be saying "not connected" while payloads
            // arrived. These follow the connection itself.
            .addConnectedListener {
                // Subscribing again on every connect rather than trusting the
                // reconnect to carry the old one. A repeat subscription to the
                // same filter replaces it at the broker, so this costs nothing
                // and removes the case where we are connected and deaf.
                if (attempt == generation) client?.let { subscribe(it, attempt) }
            }
            .addDisconnectedListener { context ->
                if (attempt == generation) {
                    onState(
                        if (context.reconnector.isReconnect) State.Connecting
                        else State.Disconnected
                    )
                }
            }
            .apply { if (settings.useTls) sslWithDefaultConfig() }
            .buildAsync()
        client = built

        built.connectWith()
            // The board is a snapshot, not a log: on reconnect we want what is
            // true now, and the retained message plus the next tick give that.
            .cleanSession(true)
            // Long enough that a dozing phone is not churning the connection,
            // short enough that the broker notices a dead one.
            .keepAlive(60)
            .apply {
                if (settings.username.isNotEmpty()) {
                    simpleAuth()
                        .username(settings.username)
                        .password(settings.password.toByteArray(StandardCharsets.UTF_8))
                        .applySimpleAuth()
                }
            }
            .send()
            .whenComplete { _, error ->
                if (error != null && attempt == generation) {
                    // Not fatal: the reconnector keeps trying, and the
                    // listeners above will say so when one lands.
                    Log.w(TAG, "connect failed", error)
                    onState(State.Failed)
                }
                // The success path is the connected listener's -- it also runs
                // for every reconnect after this one.
            }
    }

    private fun subscribe(client: Mqtt3AsyncClient, attempt: Int) {
        client.subscribeWith()
            .topicFilter(settings.topic)
            // QoS 0, matching the queue name Ankyra looks for when it counts
            // who is listening -- `mqtt-subscription-<client_id>qos0`.
            .qos(MqttQos.AT_MOST_ONCE)
            .callback { publish ->
                val payload = String(publish.payloadAsBytes, StandardCharsets.UTF_8)
                onMessage(payload)
            }
            .send()
            .whenComplete { _, error ->
                if (attempt != generation) return@whenComplete
                if (error != null) {
                    Log.w(TAG, "subscribe failed", error)
                    onState(State.Failed)
                } else {
                    onState(State.Connected)
                }
            }
    }

    fun disconnect() {
        // Retires the current attempt, so whatever the old client says on its
        // way out lands after its own generation has passed and is ignored.
        generation++
        client?.let { existing ->
            runCatching { existing.disconnect() }
        }
        client = null
        onState(State.Disconnected)
    }

    companion object {
        private const val TAG = "AnkyraClient"
    }
}
