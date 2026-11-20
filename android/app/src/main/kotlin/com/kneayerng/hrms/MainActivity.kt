package com.kneayerng.hrms

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.kneayerng.hrms.security.KySecurityMethodChannels

/** Flutter activity and platform lifecycle wiring; security work lives in services. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        KySecurityMethodChannels(applicationContext).attach(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CLOCK_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openDateTimeSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        NfcAdapter.getDefaultAdapter(this)?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onPause() {
        super.onPause()
        NfcAdapter.getDefaultAdapter(this)?.disableForegroundDispatch(this)
    }

    companion object {
        private const val DEVICE_CLOCK_CHANNEL = "cnattendance/device_clock"
    }
}
