package app.apeassist.android.network

import app.apeassist.android.data.ApeAssistConfig
import org.json.JSONArray
import org.json.JSONObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

class OpenClawClient(private val config: ApeAssistConfig, private val tokenProvider: () -> String?) {
    suspend fun sendMessage(text: String): String = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("model", config.model)
            .put("input", text)
            .put("stream", false)
            .put("user", config.session)
            .toString()

        val response = request("v1/responses", "POST", body)
        if (response.status !in 200..299) throw IOException("OpenClaw Gateway returned HTTP ${response.status}: ${response.body.take(800)}")
        parseAssistantText(response.body).ifBlank { throw IOException("OpenClaw response did not include assistant text.") }
    }

    suspend fun checkGateway(): String = withContext(Dispatchers.IO) {
        val response = request("v1/models", "GET", null)
        when (response.status) {
            in 200..299 -> "Gateway reachable; auth OK."
            401, 403 -> "Gateway reachable, but auth failed. Pair or update the token."
            else -> "Gateway returned HTTP ${response.status}: ${response.body.take(300)}"
        }
    }

    private fun request(path: String, method: String, body: String?): HttpResponse {
        val base = config.endpoint.trim().trimEnd('/')
        val connection = (URL("$base/$path").openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 90_000
            setRequestProperty("Accept", "application/json")
            setRequestProperty("x-openclaw-session-key", config.session)
            tokenProvider()?.takeIf { it.isNotBlank() }?.let { setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
        }

        val status = connection.responseCode
        val stream = if (status in 200..399) connection.inputStream else connection.errorStream
        val responseBody = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        connection.disconnect()
        return HttpResponse(status, responseBody)
    }

    private fun parseAssistantText(json: String): String {
        val root = JSONObject(json)
        root.optString("output_text").takeIf { it.isNotBlank() }?.let { return it.trim() }

        val output = root.optJSONArray("output") ?: JSONArray()
        val chunks = mutableListOf<String>()
        for (i in 0 until output.length()) {
            val item = output.optJSONObject(i) ?: continue
            item.optString("text").takeIf { it.isNotBlank() }?.let { chunks += it }
            val content = item.optJSONArray("content") ?: continue
            for (j in 0 until content.length()) {
                content.optJSONObject(j)?.optString("text")?.takeIf { it.isNotBlank() }?.let { chunks += it }
            }
        }
        if (chunks.isNotEmpty()) return chunks.joinToString(separator = "").trim()

        val choices = root.optJSONArray("choices") ?: JSONArray()
        val choiceChunks = mutableListOf<String>()
        for (i in 0 until choices.length()) {
            choices.optJSONObject(i)?.optJSONObject("message")?.optString("content")?.takeIf { it.isNotBlank() }?.let { choiceChunks += it }
        }
        return choiceChunks.joinToString(separator = "\n").trim()
    }

    private data class HttpResponse(val status: Int, val body: String)
}

fun androidSessionId(): String = "agent:main:apeassist:android:${UUID.randomUUID()}"
