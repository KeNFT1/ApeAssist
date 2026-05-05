package app.apeassist.android.data

const val DEFAULT_ENDPOINT = "https://pinchys-mac-mini.taild71e14.ts.net/"
const val DEFAULT_MODEL = "openclaw/default"
const val DEFAULT_SESSION = "agent:main:apeassist:android"

data class PairingInvite(
    val version: Int = 1,
    val endpoint: String,
    val token: String,
    val session: String? = null,
    val agentTarget: String? = null,
    val label: String? = null,
    val createdAt: String? = null,
)

data class ApeAssistConfig(
    val endpoint: String = DEFAULT_ENDPOINT,
    val tokenPresent: Boolean = false,
    val session: String = DEFAULT_SESSION,
    val model: String = DEFAULT_MODEL,
)

data class ChatMessage(
    val role: Role,
    val text: String,
) {
    enum class Role { User, Assistant, System }
}
