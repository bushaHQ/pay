package co.busha.pay.internal

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.net.InetSocketAddress

class MerchantApiTest {

    private fun withServer(
        respond: (HttpExchange) -> Unit,
        block: (baseUrl: String) -> Unit,
    ) {
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange -> respond(exchange) }
        server.start()
        try {
            block("http://127.0.0.1:${server.address.port}")
        } finally {
            server.stop(0)
        }
    }

    private fun HttpExchange.reply(status: Int, body: String) {
        val bytes = body.toByteArray()
        sendResponseHeaders(status, bytes.size.toLong())
        responseBody.use { it.write(bytes) }
    }

    @Test
    fun fetchMerchantName_returnsUsernameOn200_andSendsKeyHeader() {
        var capturedPath: String? = null
        var capturedKey: String? = null
        withServer(
            respond = { ex ->
                capturedPath = ex.requestURI.path
                capturedKey = ex.requestHeaders.getFirst("X-BU-PUBLIC-KEY")
                ex.reply(200, """{"data":{"username":"Pushup Design Agency"}}""")
            },
        ) { baseUrl ->
            assertEquals("Pushup Design Agency", fetchMerchantName("pub_test", baseUrl))
        }
        assertEquals("/v1/merchants", capturedPath)
        assertEquals("pub_test", capturedKey)
    }

    @Test
    fun fetchMerchantName_returnsNullOnNon2xx() {
        withServer(respond = { it.reply(404, """{"error":"nope"}""") }) { baseUrl ->
            assertNull(fetchMerchantName("pub_test", baseUrl))
        }
    }

    @Test
    fun fetchMerchantName_returnsNullOnNonJsonBody() {
        withServer(respond = { it.reply(200, "<html>oops</html>") }) { baseUrl ->
            assertNull(fetchMerchantName("pub_test", baseUrl))
        }
    }

    @Test
    fun fetchMerchantName_returnsNullWhenUsernameMissing() {
        withServer(respond = { it.reply(200, """{"data":{"logo":"x.png"}}""") }) { baseUrl ->
            assertNull(fetchMerchantName("pub_test", baseUrl))
        }
    }

    @Test
    fun fetchMerchantName_returnsNullWhenUsernameEmpty() {
        withServer(respond = { it.reply(200, """{"data":{"username":""}}""") }) { baseUrl ->
            assertNull(fetchMerchantName("pub_test", baseUrl))
        }
    }

    @Test
    fun fetchMerchantName_returnsNullWhenDataMissing() {
        withServer(respond = { it.reply(200, """{"username":"x"}""") }) { baseUrl ->
            assertNull(fetchMerchantName("pub_test", baseUrl))
        }
    }

    @Test
    fun fetchMerchantName_returnsNullWhenServerUnreachable() {
        assertNull(fetchMerchantName("pub_test", "http://127.0.0.1:1"))
    }
}
