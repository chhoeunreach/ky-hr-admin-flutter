package com.kneayerng.hrms.security

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Thin Flutter bridge that routes calls to focused Android security services. */
internal class KySecurityMethodChannels(context: Context) {
    private val appIdentity = AndroidAppIdentity(context)
    private val deviceKeys = AndroidDeviceKeyStore(context)
    private val riskSignals = AndroidRuntimeRiskSignals(context)
    private val leases = AndroidAuthorizationLeaseStore(context)

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "identity" -> result.success(appIdentity.read())
                        "riskSignals" -> result.success(riskSignals.collect())
                        "storeAuthorizationLease" -> {
                            val payload = call.argument<String>("payload")
                                ?: throw IllegalArgumentException("payload is required")
                            val signature = call.argument<String>("signature")
                                ?: throw IllegalArgumentException("signature is required")
                            val keyId = call.argument<String>("keyId")
                                ?: throw IllegalArgumentException("keyId is required")
                            val leaseSeconds = call.argument<Int>("leaseSeconds")
                                ?: throw IllegalArgumentException("leaseSeconds is required")
                            result.success(leases.store(payload, signature, keyId, leaseSeconds))
                        }
                        "readAuthorizationLease" -> result.success(leases.read())
                        "clearAuthorizationLease" -> {
                            leases.clear()
                            result.success(true)
                        }
                        "selectKeyAlias" -> {
                            val preferred = call.argument<String>("preferredAlias")
                                ?: throw IllegalArgumentException("preferredAlias is required")
                            val fingerprint = call.argument<String>("publicKeyFingerprint")
                                ?: throw IllegalArgumentException("publicKeyFingerprint is required")
                            require(Regex("^kneayerng_device_key_u[0-9]+$").matches(preferred))
                            result.success(deviceKeys.selectAlias(preferred, fingerprint))
                        }
                        "installationIdentity" -> {
                            val keyAlias = call.argument<String>("keyAlias")
                                ?: throw IllegalArgumentException("keyAlias is required")
                            deviceKeys.requireSecurityAlias(keyAlias)
                            result.success(deviceKeys.installationIdentity(
                                call.argument<String>("legacyUuid"), keyAlias,
                            ))
                        }
                        "rotateInstallationIdentity" -> result.success(deviceKeys.rotateInstallationIdentity())
                        "ensureKey" -> {
                            val keyAlias = call.argument<String>("keyAlias")
                                ?: throw IllegalArgumentException("keyAlias is required")
                            deviceKeys.requireSecurityAlias(keyAlias)
                            result.success(deviceKeys.ensureKey(
                                call.argument<ByteArray>("attestationChallenge"),
                                call.argument<Boolean>("forceNew") ?: false,
                                keyAlias,
                            ))
                        }
                        "sign" -> {
                            val payload = call.argument<ByteArray>("payload")
                                ?: throw IllegalArgumentException("payload is required")
                            val keyAlias = call.argument<String>("keyAlias")
                                ?: throw IllegalArgumentException("keyAlias is required")
                            deviceKeys.requireSecurityAlias(keyAlias)
                            result.success(deviceKeys.sign(payload, keyAlias))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("KY_SECURITY", error.message ?: "Security operation failed", null)
                }
            }

        MethodChannel(engine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "verify" -> result.success(appIdentity.verifyInstalledPackage())
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val SECURITY_CHANNEL = "kneayerng/ky_security"
        private const val INTEGRITY_CHANNEL = "cnattendance/app_integrity"
    }
}
