package io.neiam.apolloscrib.data

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.junit.runner.RunWith

/**
 * The link the Ankyra page's QR carries. `Uri` is an Android class, so this
 * needs a runtime for it -- the parsing itself has no other Android in it.
 *
 * Pinned to 35 because Robolectric has no 36 image yet, and `Uri.parse` is not
 * the part of Android that changes between them.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PairingTest {

    @Test
    fun `reads what the ankyra page writes`() {
        val uri = Uri.parse(
            "apolloscrib://ankyra?host=ac.neiam.org&port=1883&user=dff93bf2&pass=hunter2" +
                "&topic=Iodized-Nutritious-Xenoposeidon&tls=0"
        )
        val pairing = Pairing.from(uri)!!
        assertEquals("ac.neiam.org", pairing.host)
        assertEquals(1883, pairing.port)
        assertEquals("Iodized-Nutritious-Xenoposeidon", pairing.topic)
        assertEquals(false, pairing.useTls)
    }

    @Test
    fun `an unauthenticated broker on the default port is a real setup`() {
        val pairing = Pairing.from(Uri.parse("apolloscrib://ankyra?host=broker&topic=t"))!!
        assertEquals(1883, pairing.port)
        assertEquals("", pairing.username)
    }

    @Test
    fun `anything without a host or a topic is not a pairing`() {
        assertNull(Pairing.from(Uri.parse("apolloscrib://ankyra?host=broker")))
        assertNull(Pairing.from(Uri.parse("apolloscrib://ankyra?topic=t")))
        assertNull(Pairing.from(Uri.parse("https://example.com/?host=h&topic=t")))
        assertNull(Pairing.from(null))
    }
}
