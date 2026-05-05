package app.apeassist.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.apeassist.android.data.ChatMessage
import app.apeassist.android.ui.ApeAssistUiState
import app.apeassist.android.ui.ApeAssistViewModel
import app.apeassist.android.ui.Screen

class MainActivity : ComponentActivity() {
    private val viewModel: ApeAssistViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ApeAssistApp(viewModel) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ApeAssistApp(viewModel: ApeAssistViewModel) {
    val state by viewModel.state.collectAsState()
    MaterialTheme {
        Scaffold(
            topBar = { TopAppBar(title = { Text("ApeAssist") }) },
            bottomBar = {
                NavigationBar {
                    NavigationBarItem(selected = state.currentScreen == Screen.Pairing, onClick = { viewModel.select(Screen.Pairing) }, label = { Text("Pair") }, icon = {})
                    NavigationBarItem(selected = state.currentScreen == Screen.Chat, onClick = { viewModel.select(Screen.Chat) }, label = { Text("Chat") }, icon = {})
                    NavigationBarItem(selected = state.currentScreen == Screen.Settings, onClick = { viewModel.select(Screen.Settings) }, label = { Text("Settings") }, icon = {})
                }
            }
        ) { padding ->
            Surface(modifier = Modifier.fillMaxSize().padding(padding), color = Color(0xFFFFF8F2)) {
                when (state.currentScreen) {
                    Screen.Pairing -> PairingScreen(state, viewModel)
                    Screen.Chat -> ChatScreen(state, viewModel)
                    Screen.Settings -> SettingsScreen(state, viewModel)
                }
            }
        }
    }
}

@Composable
private fun PairingScreen(state: ApeAssistUiState, viewModel: ApeAssistViewModel) {
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Pair with Pinchy", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("Default endpoint: ${state.config.endpoint}")
        TokenStatus(state.config.tokenPresent)
        OutlinedTextField(
            value = state.inviteText,
            onValueChange = viewModel::updateInvite,
            modifier = Modifier.fillMaxWidth().height(150.dp),
            label = { Text("ApeAssist invite") },
            placeholder = { Text("APEASSIST-INVITE-v1:...") },
            supportingText = { Text("Clear v1 invites are supported. Encrypted invites are detected and left as a TODO for the MVP.") }
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = viewModel::importInvite, enabled = !state.busy) { Text("Import invite") }
            OutlinedButton(onClick = viewModel::checkGateway, enabled = !state.busy) { Text("Check Gateway") }
        }
        StatusCard(state.setupStatus)
    }
}

@Composable
private fun ChatScreen(state: ApeAssistUiState, viewModel: ApeAssistViewModel) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("OpenClaw chat", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(12.dp))
            TokenStatus(state.config.tokenPresent)
        }
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(state.messages) { MessageBubble(it) }
        }
        OutlinedTextField(
            value = state.chatInput,
            onValueChange = viewModel::updateChatInput,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Message") },
            enabled = !state.busy,
        )
        Button(onClick = viewModel::sendChat, enabled = !state.busy && state.chatInput.isNotBlank(), modifier = Modifier.fillMaxWidth()) {
            Text(if (state.busy) "Sending..." else "Send to /v1/responses")
        }
    }
}

@Composable
private fun SettingsScreen(state: ApeAssistUiState, viewModel: ApeAssistViewModel) {
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Settings", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        OutlinedTextField(
            value = state.endpointDraft,
            onValueChange = viewModel::updateEndpoint,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Gateway endpoint") },
            singleLine = true,
        )
        Text("Model: ${state.config.model}")
        Text("Session: ${state.config.session}")
        TokenStatus(state.config.tokenPresent)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = viewModel::saveEndpoint, enabled = !state.busy) { Text("Save endpoint") }
            OutlinedButton(onClick = viewModel::checkGateway, enabled = !state.busy) { Text("Check Gateway") }
        }
        OutlinedButton(onClick = viewModel::clearToken, enabled = !state.busy) { Text("Clear token") }
        StatusCard(state.setupStatus)
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    val bg = when (message.role) {
        ChatMessage.Role.User -> Color(0xFF2F5D50)
        ChatMessage.Role.Assistant -> Color.White
        ChatMessage.Role.System -> Color(0xFFFFE8CC)
    }
    val fg = if (message.role == ChatMessage.Role.User) Color.White else Color(0xFF1B1410)
    Card(
        colors = CardDefaults.cardColors(containerColor = bg),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(message.role.name, color = fg, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text(message.text, color = fg)
        }
    }
}

@Composable
private fun TokenStatus(present: Boolean) {
    val color = if (present) Color(0xFF1F7A4D) else Color(0xFF8A4B00)
    Text(
        text = if (present) "Token stored" else "No token stored",
        color = Color.White,
        modifier = Modifier.background(color, RoundedCornerShape(999.dp)).padding(horizontal = 10.dp, vertical = 5.dp),
        style = MaterialTheme.typography.labelMedium,
    )
}

@Composable
private fun StatusCard(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFE8CC)), modifier = Modifier.fillMaxWidth()) {
        Text(text, modifier = Modifier.padding(14.dp))
    }
}
