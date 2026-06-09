package com.deadswitch.deadswitch_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL = "com.deadswitch.deadswitch_app/sms"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return

        // v6: default sound so Samsung One UI shows a heads-up banner on trigger.
        // Delete + recreate if the channel exists with sound suppressed (from an older install).
        // onlyAlertOnce on each notification post prevents the sound from repeating.
        val existingV6 = nm.getNotificationChannel("deadswitch_countdown_v6")
        if (existingV6 == null || existingV6.sound == null) {
            if (existingV6 != null) nm.deleteNotificationChannel("deadswitch_countdown_v6")
            val ch = NotificationChannel(
                "deadswitch_countdown_v6",
                "Dead Switch Countdown",
                NotificationManager.IMPORTANCE_HIGH
            )
            ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            ch.setShowBadge(true)
            ch.enableVibration(false)
            nm.createNotificationChannel(ch)
        }

        // Foreground service keeper — hidden on lock screen
        if (nm.getNotificationChannel("deadswitch_trigger_v4") == null) {
            val ch = NotificationChannel(
                "deadswitch_trigger_v4",
                "Dead Switch Active",
                NotificationManager.IMPORTANCE_LOW
            )
            ch.lockscreenVisibility = Notification.VISIBILITY_SECRET
            ch.setShowBadge(false)
            ch.enableVibration(false)
            ch.setSound(null, null)
            nm.createNotificationChannel(ch)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val to      = call.argument<String>("to")      ?: ""
                        val message = call.argument<String>("message") ?: ""
                        try {
                            sendSmsNative(to, message)
                            result.success("sent")
                        } catch (e: Exception) {
                            result.error("SMS_SEND_FAILED", e.message ?: "Unknown error", null)
                        }
                    }
                    "sendGroupSms" -> {
                        val recipients = call.argument<List<String>>("recipients") ?: emptyList()
                        val message    = call.argument<String>("message") ?: ""
                        try {
                            sendGroupMms(recipients, message)
                            result.success("sent")
                        } catch (e: Exception) {
                            result.error("MMS_SEND_FAILED", e.message ?: "Unknown error", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getSmsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
                ?: throw Exception("SmsManager unavailable")
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

    private fun sendSmsNative(to: String, message: String) {
        val smsManager = getSmsManager()
        val parts = smsManager.divideMessage(message)
        if (parts.size == 1) {
            smsManager.sendTextMessage(to, null, message, null, null)
        } else {
            smsManager.sendMultipartTextMessage(to, null, parts, null, null)
        }
    }

    private fun sendGroupMms(recipients: List<String>, message: String) {
        val pduBytes = MmsPduBuilder.buildGroupText(recipients, message)

        val mmsDir = File(cacheDir, "mms")
        mmsDir.mkdirs()
        val mmsFile = File(mmsDir, "group_${System.currentTimeMillis()}.mms")
        mmsFile.writeBytes(pduBytes)

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", mmsFile)

        getSmsManager().sendMultimediaMessage(applicationContext, uri, null, null, null)

        Handler(Looper.getMainLooper()).postDelayed({ mmsFile.delete() }, 30_000)
    }
}
