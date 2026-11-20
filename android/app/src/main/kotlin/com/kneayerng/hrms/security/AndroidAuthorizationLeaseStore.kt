package com.kneayerng.hrms.security

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.kneayerng.hrms.BuildConfig
import org.json.JSONObject
import java.security.KeyFactory
import java.security.KeyStore
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Stores server-signed offline leases encrypted with a local Android Keystore key. */
internal class AndroidAuthorizationLeaseStore(private val context: Context) {
    fun store(payload: String, signature: String, keyId: String, leaseSeconds: Int): Boolean {
        if (leaseSeconds !in 1..86400 || !verifySignature(payload, signature, keyId)) {
            clear()
            return false
        }
        val record = JSONObject()
            .put("payload", payload)
            .put("signature", signature)
            .put("key_id", keyId)
            .put("lease_seconds", leaseSeconds)
            .put("stored_elapsed_ms", SystemClock.elapsedRealtime())
            .put("boot_count", currentBootCount())
            .toString()
            .toByteArray(Charsets.UTF_8)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, encryptionKey())
        val packed = cipher.iv + cipher.doFinal(record)
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(ENCRYPTED_RECORD, Base64.encodeToString(packed, Base64.NO_WRAP)).commit()
    }

    fun read(): Map<String, String>? {
        return try {
        val encoded = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(ENCRYPTED_RECORD, null) ?: return null
        val packed = Base64.decode(encoded, Base64.DEFAULT)
        if (packed.size < 13) return null
        val iv = packed.copyOfRange(0, 12)
        val ciphertext = packed.copyOfRange(12, packed.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, encryptionKey(), GCMParameterSpec(128, iv))
        val record = JSONObject(String(cipher.doFinal(ciphertext), Charsets.UTF_8))
        val payload = record.getString("payload")
        val signature = record.getString("signature")
        val keyId = record.getString("key_id")
        val leaseSeconds = record.getInt("lease_seconds")
        val storedElapsed = record.getLong("stored_elapsed_ms")
        val currentElapsed = SystemClock.elapsedRealtime()
        if (leaseSeconds !in 1..86400 || record.getInt("boot_count") != currentBootCount()
            || currentElapsed < storedElapsed
            || currentElapsed - storedElapsed > leaseSeconds * 1000L
            || !verifySignature(payload, signature, keyId)) {
            clear()
            return null
        }
        mapOf("payload" to payload, "signature" to signature, "key_id" to keyId)
    } catch (_: Exception) {
        clear()
        null
        }
    }

    fun clear() {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().clear().commit()
        try {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
            // A missing key means the encrypted lease is already unusable.
        }
    }

    private fun verificationKey(keyId: String): java.security.PublicKey? {
        if (!Regex("^[A-Za-z0-9._-]{1,64}$").matches(keyId)) return null
        val encoded = BuildConfig.LEASE_VERIFYING_KEYS.split(',').firstNotNullOfOrNull { entry ->
            val separator = entry.indexOf('=')
            if (separator < 1 || entry.substring(0, separator) != keyId) null
            else entry.substring(separator + 1).takeIf { it.isNotBlank() }
        } ?: return null
        val der = Base64.decode(encoded, Base64.DEFAULT)
        return KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(der))
    }

    private fun verifySignature(payload: String, signature: String, keyId: String): Boolean {
        if (payload.length > 16384 || signature.length > 2048) return false
        val publicKey = verificationKey(keyId) ?: return false
        return try {
            val verifier = Signature.getInstance("SHA256withECDSA")
            verifier.initVerify(publicKey)
            verifier.update(Base64.decode(payload, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING))
            verifier.verify(Base64.decode(signature, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING))
        } catch (_: Exception) {
            false
        }
    }

    private fun encryptionKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun currentBootCount(): Int =
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)

    companion object {
        private const val KEY_ALIAS = "kneayerng_authorization_lease_v1"
        private const val PREFERENCES = "ky_security_authorization_lease"
        private const val ENCRYPTED_RECORD = "encrypted_record"
    }
}
