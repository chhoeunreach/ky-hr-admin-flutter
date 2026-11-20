package com.kneayerng.hrms.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.InvalidKeyException
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.UnrecoverableKeyException

/** Android Keystore operations for account-bound device keys and per-install identity. */
internal class AndroidDeviceKeyStore(private val context: Context) {
    fun requireSecurityAlias(alias: String) {
        require(alias == LEGACY_ALIAS || USER_ALIAS.matches(alias))
    }

    fun selectAlias(preferredAlias: String, expectedFingerprint: String): String? {
        val store = keyStore()
        for (alias in listOf(preferredAlias, LEGACY_ALIAS)) {
            if (!store.containsAlias(alias)) continue
            val certificate = store.getCertificate(alias) ?: continue
            val actual = MessageDigest.getInstance("SHA-256").digest(certificate.publicKey.encoded)
                .joinToString("") { "%02X".format(it) }
            if (!actual.equals(expectedFingerprint, ignoreCase = true)) continue
            val privateKey = try {
                store.getKey(alias, null) as? java.security.PrivateKey
            } catch (_: UnrecoverableKeyException) {
                null
            } ?: continue
            try {
                // Detect aliases whose public certificate remains after private-key invalidation.
                Signature.getInstance("SHA256withECDSA").initSign(privateKey)
            } catch (_: InvalidKeyException) {
                continue
            }
            return alias
        }
        return null
    }

    fun installationIdentity(legacyUuid: String?, keyAlias: String): String {
        requireSecurityAlias(keyAlias)
        val preferences = context.getSharedPreferences(INSTALL_PREFS, Context.MODE_PRIVATE)
        preferences.getString(INSTALL_UUID, null)?.let { existing ->
            if (isValidUuid(existing)) return existing
        }

        // Preserve an existing server-bound ID only when the local Keystore proves
        // this is an app upgrade, not a reinstall with restored Flutter preferences.
        val store = keyStore()
        val hasExistingDeviceKey = store.containsAlias(keyAlias) || store.containsAlias(LEGACY_ALIAS)
        val migrated = legacyUuid?.takeIf { hasExistingDeviceKey && isValidUuid(it) }
        val identity = migrated ?: java.util.UUID.randomUUID().toString()
        check(preferences.edit().putString(INSTALL_UUID, identity).commit()) {
            "Installation identity could not be persisted"
        }
        return identity
    }

    fun rotateInstallationIdentity(): String {
        val identity = java.util.UUID.randomUUID().toString()
        val preferences = context.getSharedPreferences(INSTALL_PREFS, Context.MODE_PRIVATE)
        check(preferences.edit().putString(INSTALL_UUID, identity).commit()) {
            "New installation identity could not be persisted"
        }
        return identity
    }

    fun ensureKey(
        attestationChallenge: ByteArray?,
        forceNew: Boolean,
        keyAlias: String,
    ): Map<String, Any?> {
        requireSecurityAlias(keyAlias)
        val store = keyStore()
        if (forceNew && store.containsAlias(keyAlias)) store.deleteEntry(keyAlias)
        if (!store.containsAlias(keyAlias)) generateKey(store, keyAlias, attestationChallenge)
        val certificateChain = store.getCertificateChain(keyAlias)
            ?.map { Base64.encodeToString(it.encoded, Base64.NO_WRAP) } ?: emptyList()
        val publicKey = store.getCertificate(keyAlias)?.publicKey
            ?: throw IllegalStateException("Device public key is unavailable")
        return mapOf(
            "publicKey" to Base64.encodeToString(publicKey.encoded, Base64.NO_WRAP),
            "attestationChain" to certificateChain,
            "attestationSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && certificateChain.size > 1),
        )
    }

    fun sign(payload: ByteArray, keyAlias: String): String {
        requireSecurityAlias(keyAlias)
        val privateKey = keyStore().getKey(keyAlias, null) as? java.security.PrivateKey
            ?: throw IllegalStateException("Device key has not been created")
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey)
        signer.update(payload)
        return Base64.encodeToString(signer.sign(), Base64.NO_WRAP)
    }

    private fun generateKey(store: KeyStore, alias: String, challenge: ByteArray?) {
        try {
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
                .apply {
                    initialize(keySpec(
                        alias,
                        challenge,
                        preferStrongBox = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P,
                    ))
                }.generateKeyPair()
        } catch (strongBoxError: Exception) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) throw strongBoxError
            if (store.containsAlias(alias)) store.deleteEntry(alias)
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
                .apply { initialize(keySpec(alias, challenge, preferStrongBox = false)) }.generateKeyPair()
        }
    }

    private fun keySpec(alias: String, challenge: ByteArray?, preferStrongBox: Boolean) =
        KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        ).setAlgorithmParameterSpec(java.security.spec.ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && challenge != null) {
                    setAttestationChallenge(challenge)
                }
                if (preferStrongBox) setIsStrongBoxBacked(true)
            }
            .build()

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun isValidUuid(value: String): Boolean = try {
        java.util.UUID.fromString(value).toString().equals(value, ignoreCase = true)
    } catch (_: IllegalArgumentException) {
        false
    }

    companion object {
        private const val LEGACY_ALIAS = "kneayerng_device_key_v1"
        private val USER_ALIAS = Regex("^kneayerng_device_key_u[0-9]+$")
        private const val INSTALL_PREFS = "ky_install_identity"
        private const val INSTALL_UUID = "installation_uuid"
    }
}
