package io.neiam.apolloscrib.mqtt

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Which board a message is, from the topic it arrived on.
 *
 * The separator changes in flight: a Pythiae publishes to the AMQP routing key
 * `<topic>.plus`, and RabbitMQ's MQTT plugin hands it to a subscriber as
 * `<topic>/plus`. Both spellings have to read as the same thing.
 */
class TopicTest {

    @Test
    fun `the plus board as RabbitMQ delivers it`() {
        assertTrue(AnkyraClient.isPlusTopic("Iodized-Nutritious-Xenoposeidon/plus"))
    }

    @Test
    fun `the plus board as it is subscribed to`() {
        assertTrue(AnkyraClient.isPlusTopic("Iodized-Nutritious-Xenoposeidon.plus"))
    }

    @Test
    fun `the ordinary board is not the plus one`() {
        assertFalse(AnkyraClient.isPlusTopic("Iodized-Nutritious-Xenoposeidon"))
    }

    @Test
    fun `a topic that merely mentions plus is not the plus board`() {
        assertFalse(AnkyraClient.isPlusTopic("Plus-Nutritious-Xenoposeidon"))
    }

    @Test
    fun `an uplink is not a board at all`() {
        assertFalse(AnkyraClient.isPlusTopic("Iodized-Nutritious-Xenoposeidon/up/loc"))
    }
}
