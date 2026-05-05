package app.apeassist.android.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.apeassist.android.data.ApeAssistConfig
import app.apeassist.android.data.ChatMessage
import app.apeassist.android.data.DEFAULT_ENDPOINT
import app.apeassist.android.data.PairingInviteParser
import app.apeassist.android.data.SecureTokenStore
import app.apeassist.android.network.OpenClawClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ApeAssistUiState(
    val config: ApeAssistConfig = ApeAssistConfig(),
    val inviteText: String = "",
    val endpointDraft: String = DEFAULT_ENDPOINT,
    val setupStatus: String = "Paste Ken's ApeAssist invite or use the default Tailscale endpoint.",
    val chatInput: String = "",
    val messages: List<ChatMessage> = listOf(ChatMessage(ChatMessage.Role.System, "Pair with Pinchy/OpenClaw, then send a message.")),
    val busy: Boolean = false,
    val currentScreen: Screen = Screen.Pairing,
)

enum class Screen { Pairing, Chat, Settings }

class ApeAssistViewModel(application: Application) : AndroidViewModel(application) {
    private val store = SecureTokenStore(application)
    private val _state = MutableStateFlow(ApeAssistUiState(config = store.loadConfig(), endpointDraft = store.loadConfig().endpoint))
    val state: StateFlow<ApeAssistUiState> = _state.asStateFlow()

    fun select(screen: Screen) = _state.update { it.copy(currentScreen = screen) }
    fun updateInvite(text: String) = _state.update { it.copy(inviteText = text) }
    fun updateEndpoint(text: String) = _state.update { it.copy(endpointDraft = text) }
    fun updateChatInput(text: String) = _state.update { it.copy(chatInput = text) }

    fun saveEndpoint() {
        store.saveEndpoint(state.value.endpointDraft)
        refreshConfig("Endpoint saved.")
    }

    fun clearToken() {
        store.clearToken()
        refreshConfig("Token cleared.")
    }

    fun importInvite() {
        try {
            val invite = PairingInviteParser.decode(state.value.inviteText)
            store.saveInvite(invite)
            refreshConfig("Pairing invite imported for ${invite.endpoint}.")
            _state.update { it.copy(endpointDraft = invite.endpoint, currentScreen = Screen.Chat) }
        } catch (e: Exception) {
            _state.update { it.copy(setupStatus = e.message ?: "Could not import invite.") }
        }
    }

    fun checkGateway() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, setupStatus = "Checking Gateway...") }
            val result = runCatching { client().checkGateway() }.getOrElse { "Gateway check failed: ${it.message}" }
            _state.update { it.copy(busy = false, setupStatus = result) }
        }
    }

    fun sendChat() {
        val text = state.value.chatInput.trim()
        if (text.isEmpty()) return
        viewModelScope.launch {
            _state.update {
                it.copy(
                    busy = true,
                    chatInput = "",
                    messages = it.messages + ChatMessage(ChatMessage.Role.User, text),
                )
            }
            val reply = runCatching { client().sendMessage(text) }.getOrElse { "Error: ${it.message}" }
            _state.update {
                it.copy(
                    busy = false,
                    messages = it.messages + ChatMessage(ChatMessage.Role.Assistant, reply),
                )
            }
        }
    }

    private fun client(): OpenClawClient = OpenClawClient(state.value.config) { store.loadToken() }

    private fun refreshConfig(status: String) {
        val loaded = store.loadConfig()
        _state.update { it.copy(config = loaded, endpointDraft = loaded.endpoint, setupStatus = status) }
    }
}
