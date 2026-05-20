package co.busha.pay.internal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class MerchantApiTest {

    /** Minimal in-memory [HttpURLConnection] for driving fetchMerchantName. */
    private class FakeConnection(
        private val status: Int,
        private val body: String,
    ) : HttpURLConnection(URL("http://stub/")) {
        val requestProps = mutableMapOf<String, String>()
        override fun getResponseCode(): Int = status
        override fun getInputStream() = body.byteInputStream()
        override fun setRequestProperty(key: String, value: String) {
            requestProps[key] = value
        }
        override fun connect() {}
        override fun disconnect() {}
        override fun usingProxy() = false
    }

    @Test
    fun fetchMerchantName_returnsUsernameOn200_andSendsKeyHeaderToMerchantsPath() {
        var capturedUrl: String? = null
        val conn = FakeConnection(200, """{"data":{"username":"Pushup Design Agency"}}""")
        val name = fetchMerchantName("pub_test", "https://api.busha.io") { url ->
            capturedUrl = url
            conn
        }
        assertEquals("Pushup Design Agency", name)
        assertEquals("https://api.busha.io/v1/merchants", capturedUrl)
        assertEquals("pub_test", conn.requestProps["X-BU-PUBLIC-KEY"])
    }

    @Test
    fun fetchMerchantName_returnsNullOnNon2xx() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            FakeConnection(404, """{"error":"nope"}""")
        }
        assertNull(name)
    }

    @Test
    fun fetchMerchantName_returnsNullOnNonJsonBody() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            FakeConnection(200, "<html>oops</html>")
        }
        assertNull(name)
    }

    @Test
    fun fetchMerchantName_returnsNullWhenUsernameMissing() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            FakeConnection(200, """{"data":{"logo":"x.png"}}""")
        }
        assertNull(name)
    }

    @Test
    fun fetchMerchantName_returnsNullWhenUsernameEmpty() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            FakeConnection(200, """{"data":{"username":""}}""")
        }
        assertNull(name)
    }

    @Test
    fun fetchMerchantName_returnsNullWhenDataMissing() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            FakeConnection(200, """{"username":"x"}""")
        }
        assertNull(name)
    }

    @Test
    fun fetchMerchantName_returnsNullWhenConnectionThrows() {
        val name = fetchMerchantName("pub_test", "https://api.busha.io") {
            throw IOException("connection refused")
        }
        assertNull(name)
    }
}
