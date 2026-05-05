package app.apeassist.android.data

import android.util.Base64
import org.json.JSONObject

class PairingInviteException(message: String) : Exception(message)

object PairingInviteParser {
    const val CLEAR_PREFIX = "APEASSIST-INVITE-v1:"
    const val ENCRYPTED_PREFIX = "APEASSIST-INVITE-ENC-v1:"

    fun decode(input: String): PairingInvite {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) throw PairingInviteException("Paste a pairing invite first.")
        if (trimmed.startsWith(ENCRYPTED_PREFIX)) {
            throw PairingInviteException("Encrypted invites are recognized but not decrypted in the Android MVP yet. Use a clear v1 invite for now.")
        }

        val jsonText = when {
            trimmed.startsWith("{") -> trimmed
            trimmed.startsWith(CLEAR_PREFIX) -> decodeBase64(trimmed.removePrefix(CLEAR_PREFIX))
            else -> decodeBase64(trimmed)
        }
        return parseJson(jsonText).also { validate(it) }
    }

    private fun decodeBase64(payload: String): String {
        return try {
            val normalized = payload.replace("\n", "").replace(" ", "")
            String(Base64.decode(normalized, Base64.DEFAULT), Charsets.UTF_8)
        } catch (_: IllegalArgumentException) {
            throw PairingInviteException("The pairing invite payload is not valid base64.")
        }
    }

    private fun parseJson(json: String): PairingInvite {
        return try {
            val obj = JSONObject(json)
            PairingInvite(
                version = obj.optInt("version", 1),
                endpoint = obj.getString("endpoint"),
                token = obj.getString("token"),
                session = obj.optString("session").takeIf { it.isNotBlank() },
                agentTarget = obj.optString("agentTarget").takeIf { it.isNotBlank() },
                label = obj.optString("label").takeIf { it.isNotBlank() },
                createdAt = obj.optString("createdAt").takeIf { it.isNotBlank() },
            )
        } catch (_: Exception) {
            throw PairingInviteException("The pairing invite JSON could not be decoded.")
        }
    }

    private fun validate(invite: PairingInvite) {
        if (invite.version != 1) throw PairingInviteException("Unsupported pairing invite version: ${invite.version}.")
        val endpoint = invite.endpoint.trim()
        if (!(endpoint.startsWith("http://") || endpoint.startsWith("https://"))) {
            throw PairingInviteException("The pairing invite endpoint is invalid.")
        }
        if (invite.token.trim().isEmpty()) throw PairingInviteException("The pairing invite is missing a Gateway token.")
    }
}
