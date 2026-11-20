package com.kneayerng.hrms.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.kneayerng.hrms.BuildConfig
import java.security.MessageDigest

/** Reads APK identity and checks it against the build-time package/signer policy. */
internal class AndroidAppIdentity(private val context: Context) {
    fun read(): Map<String, Any?> {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
        }
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        val signer = signatures?.firstOrNull()
            ?: throw IllegalStateException("Signing certificate unavailable")
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(signer.toByteArray())
            .joinToString("") { "%02X".format(it) }
        return mapOf(
            "packageName" to context.packageName,
            "signingSha256" to fingerprint,
            "versionName" to info.versionName,
            "versionCode" to appVersionCode(info),
            "androidSdk" to Build.VERSION.SDK_INT,
            "androidVersion" to Build.VERSION.RELEASE,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".take(191),
        )
    }

    fun verifyInstalledPackage(): Map<String, Any> {
        val actualPackage = context.packageName
        val actualCert = signingCertificateSha256()
        val trustedCerts = BuildConfig.EXPECTED_SIGNING_CERT_SHA256
            .split(',').map { it.trim() }.filter { it.isNotEmpty() }
        val packageOk = actualPackage == BuildConfig.EXPECTED_PACKAGE_NAME
        val certOk = actualCert != null && trustedCerts.any { actualCert.equals(it, ignoreCase = true) }
        return mapOf(
            "tampered" to (!packageOk || !certOk),
            "packageOk" to packageOk,
            "certOk" to certOk,
        )
    }

    @Suppress("DEPRECATION")
    private fun appVersionCode(info: android.content.pm.PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()

    private fun signingCertificateSha256(): String? = try {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
        }
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()
        } ?: return null
        MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
            .joinToString("") { "%02X".format(it) }
    } catch (_: Exception) {
        null
    }
}
