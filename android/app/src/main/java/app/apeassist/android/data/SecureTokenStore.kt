package app.apeassist.android.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureTokenStore(context: Context) {
    private val appContext = context.applicationContext
    private val prefs by lazy {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            appContext,
            "apeassist_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun loadConfig(): ApeAssistConfig = ApeAssistConfig(
        endpoint = prefs.getString(KEY_ENDPOINT, DEFAULT_ENDPOINT) ?: DEFAULT_ENDPOINT,
        tokenPresent = !prefs.getString(KEY_TOKEN, null).isNullOrBlank(),
        session = prefs.getString(KEY_SESSION, DEFAULT_SESSION) ?: DEFAULT_SESSION,
        model = prefs.getString(KEY_MODEL, DEFAULT_MODEL) ?: DEFAULT_MODEL,
    )

    fun loadToken(): String? = prefs.getString(KEY_TOKEN, null)?.takeIf { it.isNotBlank() }

    fun saveEndpoint(endpoint: String) {
        prefs.edit().putString(KEY_ENDPOINT, endpoint.trim().ifBlank { DEFAULT_ENDPOINT }).apply()
    }

    fun saveInvite(invite: PairingInvite) {
        prefs.edit()
            .putString(KEY_ENDPOINT, invite.endpoint.trim())
            .putString(KEY_TOKEN, invite.token.trim())
            .putString(KEY_SESSION, invite.session?.trim()?.ifBlank { null } ?: DEFAULT_SESSION)
            .putString(KEY_MODEL, invite.agentTarget?.trim()?.ifBlank { null } ?: DEFAULT_MODEL)
            .apply()
    }

    fun clearToken() {
        prefs.edit().remove(KEY_TOKEN).apply()
    }

    companion object {
        private const val KEY_ENDPOINT = "endpoint"
        private const val KEY_TOKEN = "gateway_token"
        private const val KEY_SESSION = "session"
        private const val KEY_MODEL = "model"
    }
}
