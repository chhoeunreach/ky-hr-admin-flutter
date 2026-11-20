package com.kneayerng.hrms.security

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Debug
import com.kneayerng.hrms.BuildConfig

/** Collects low-confidence indicators for server-side review; it never authorizes or blocks. */
internal class AndroidRuntimeRiskSignals(private val context: Context) {
    fun collect(): List<String> {
        val signals = mutableListOf<String>()
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val capabilities = connectivity?.getNetworkCapabilities(connectivity.activeNetwork)
        if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
            signals.add("vpn_detected")
        }
        if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) signals.add("network_transport_wifi")
        if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true) signals.add("network_transport_cellular")
        if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true) signals.add("network_transport_ethernet")
        if (BuildConfig.DEBUG) signals.add("debug_build")
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) signals.add("debugger_attached")

        val rootPaths = listOf(
            "/system/app/Superuser.apk", "/system/bin/su", "/system/xbin/su",
            "/sbin/su", "/data/adb/magisk", "/sbin/.magisk",
        )
        if (Build.TAGS?.contains("test-keys") == true || rootPaths.any { java.io.File(it).exists() }) {
            signals.add("root_detected")
        }

        val fingerprint = Build.FINGERPRINT.orEmpty().lowercase()
        val model = Build.MODEL.orEmpty().lowercase()
        val hardware = Build.HARDWARE.orEmpty().lowercase()
        val product = Build.PRODUCT.orEmpty().lowercase()
        if (fingerprint.startsWith("generic") || model.contains("sdk_gphone") || model.contains("emulator")
            || hardware in setOf("goldfish", "ranchu") || product.contains("sdk_gphone")) {
            signals.add("emulator_detected")
        }

        val processMaps = runCatching { java.io.File("/proc/self/maps").readText() }
            .getOrDefault("").lowercase()
        if (listOf("frida", "xposed", "substrate", "zygisk").any(processMaps::contains)) {
            signals.add("instrumentation_detected")
        }
        val hookClasses = listOf(
            "de.robv.android.xposed.XposedBridge",
            "com.saurik.substrate.MS\$2",
            "re.frida.Server",
        )
        if (hookClasses.any { className -> runCatching { Class.forName(className) }.isSuccess }) {
            signals.add("hooking_detected")
        }
        return signals
    }
}
