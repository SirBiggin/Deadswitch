package com.deadswitch.deadswitch_app

import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.deadswitch/sms")
            .setMethodCallHandler { call, result ->
                if (call.method != "sendSms") { result.notImplemented(); return@setMethodCallHandler }
                val to      = call.argument<String>("to")      ?: ""
                val message = call.argument<String>("message") ?: ""
                try {
                    val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }
                    val parts = smsManager.divideMessage(message)
                    if (parts.size == 1) {
                        smsManager.sendTextMessage(to, null, message, null, null)
                    } else {
                        smsManager.sendMultipartTextMessage(to, null, parts, null, null)
                    }
                    result.success(mapOf("status" to "success"))
                } catch (e: Exception) {
                    result.error("SMS_ERROR", e.message, null)
                }
            }
    }
}
