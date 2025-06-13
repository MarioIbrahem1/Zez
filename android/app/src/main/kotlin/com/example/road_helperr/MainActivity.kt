package com.example.road_helperr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.road_helperr/signing_info"
    private val POWER_BUTTON_CHANNEL = "com.example.road_helperr/power_button"
    private val ACCESSIBILITY_CHANNEL = "com.example.road_helperr/accessibility"
    private var powerButtonReceiver: PowerButtonReceiver? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Original signing info channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSigningInfo") {
                result.success(getSigningInfo())
            } else {
                result.notImplemented()
            }
        }

        // SOS Power button channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_BUTTON_CHANNEL)

        // Register power button receiver for SOS
        powerButtonReceiver = PowerButtonReceiver(this, methodChannel!!)
        powerButtonReceiver?.register()

        // Accessibility Service Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled()
                    result.success(isEnabled)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success("Accessibility settings opened")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register SOS plugins
        flutterEngine.plugins.add(SimServicePlugin())
        flutterEngine.plugins.add(DirectSmsPlugin())
    }

    override fun onDestroy() {
        super.onDestroy()
        powerButtonReceiver?.unregister()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "road_helper_notifications"
            val channelName = "Road Helper Notifications"
            val channelDescription = "Push notifications for Road Helper app including help requests, chat messages, and app updates"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            // Create SOS notification channel
            val sosChannelId = "sos_channel"
            val sosChannelName = "SOS Alerts"
            val sosChannelDescription = "Important SOS emergency alerts"
            val sosChannel = NotificationChannel(sosChannelId, sosChannelName, NotificationManager.IMPORTANCE_HIGH).apply {
                description = sosChannelDescription
                enableLights(true)
                enableVibration(false) // Disabled for stealth mode
                setShowBadge(true)
            }

            // Create background service notification channel
            val backgroundChannelId = "sos_background_service"
            val backgroundChannelName = "SOS Background Service"
            val backgroundChannelDescription = "SOS emergency background service"
            val backgroundChannel = NotificationChannel(backgroundChannelId, backgroundChannelName, NotificationManager.IMPORTANCE_LOW).apply {
                description = backgroundChannelDescription
                enableLights(false)
                enableVibration(false)
                setShowBadge(false)
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            notificationManager.createNotificationChannel(sosChannel)
            notificationManager.createNotificationChannel(backgroundChannel)

            Log.d("MainActivity", "Notification channels created: $channelId, $sosChannelId, $backgroundChannelId")
        }
    }

    private fun getSigningInfo(): String {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            val signatures = packageInfo.signatures
            val sb = StringBuilder()

            for (signature in signatures) {
                val md = MessageDigest.getInstance("SHA-1")
                md.update(signature.toByteArray())
                val sha1 = bytesToHex(md.digest())
                sb.append("SHA-1: $sha1\n")

                // Also get SHA-256 for future reference
                val md256 = MessageDigest.getInstance("SHA-256")
                md256.update(signature.toByteArray())
                val sha256 = bytesToHex(md256.digest())
                sb.append("SHA-256: $sha256\n")
            }

            return sb.toString()
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e("MainActivity", "Package name not found", e)
            return "Error: Package name not found"
        } catch (e: NoSuchAlgorithmException) {
            Log.e("MainActivity", "No such algorithm", e)
            return "Error: No such algorithm"
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting signing info", e)
            return "Error: ${e.message}"
        }
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = "0123456789ABCDEF".toCharArray()
        val hexString = StringBuilder(bytes.size * 2)

        for (byte in bytes) {
            val i = byte.toInt() and 0xff
            hexString.append(hexChars[i shr 4])
            hexString.append(hexChars[i and 0x0f])
        }

        return hexString.toString()
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0
        )

        if (accessibilityEnabled == 1) {
            val services = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )

            if (!TextUtils.isEmpty(services)) {
                val serviceName = "com.example.road_helperr/com.example.road_helperr.SOSAccessibilityService"
                Log.d("MainActivity", "Checking accessibility service: $serviceName")
                Log.d("MainActivity", "Enabled services: $services")
                return services.contains(serviceName)
            }
        }
        return false
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            Log.d("MainActivity", "Accessibility settings opened")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error opening accessibility settings", e)
        }
    }
}
