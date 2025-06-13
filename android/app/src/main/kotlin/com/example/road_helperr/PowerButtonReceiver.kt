package com.example.road_helperr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class PowerButtonReceiver(
    private val context: Context,
    private val methodChannel: MethodChannel
) : BroadcastReceiver() {

    companion object {
        private const val TAG = "PowerButtonReceiver"
        private const val RESET_TIMEOUT = 5000L // 5 seconds - more time for emergency situations
        private const val QUICK_PRESS_TIMEOUT = 1000L // 1 second between presses for quick sequence
    }

    private var pressCount = 0
    private val handler = Handler(Looper.getMainLooper())
    private var resetRunnable: Runnable? = null
    private var lastPressTime = 0L

    fun register() {
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }
            context.registerReceiver(this, filter)
            Log.d(TAG, "PowerButtonReceiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering PowerButtonReceiver: ${e.message}")
        }
    }

    fun unregister() {
        try {
            context.unregisterReceiver(this)
            resetRunnable?.let { handler.removeCallbacks(it) }
            Log.d(TAG, "PowerButtonReceiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering PowerButtonReceiver: ${e.message}")
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SCREEN_OFF -> {
                handleScreenStateChange(false)
            }
            Intent.ACTION_SCREEN_ON -> {
                handleScreenStateChange(true)
            }
        }
    }

    private fun handleScreenStateChange(isScreenOn: Boolean) {
        val currentTime = System.currentTimeMillis()
        Log.d(TAG, "Screen state changed: $isScreenOn")

        // Check if this press is within reasonable time from last press
        val timeSinceLastPress = currentTime - lastPressTime

        if (timeSinceLastPress > RESET_TIMEOUT) {
            // Too much time passed, reset count
            pressCount = 0
            Log.d(TAG, "Press count reset due to timeout (${timeSinceLastPress}ms)")
        }

        // Only count if it's a screen OFF event (actual power button press)
        if (!isScreenOn) {
            pressCount++
            lastPressTime = currentTime

            Log.d(TAG, "Power button press count: $pressCount (time since last: ${timeSinceLastPress}ms)")

            // Cancel previous reset timer
            resetRunnable?.let { handler.removeCallbacks(it) }

            // Set new reset timer - longer timeout for emergency situations
            resetRunnable = Runnable {
                Log.d(TAG, "Press count reset after timeout")
                pressCount = 0
            }
            handler.postDelayed(resetRunnable!!, RESET_TIMEOUT)

            // Check for triple press
            if (pressCount >= 3) {
                Log.d(TAG, "🚨 EMERGENCY: Triple power button press detected!")
                pressCount = 0
                resetRunnable?.let { handler.removeCallbacks(it) }

                // Notify Flutter with specific triple press method
                try {
                    Log.d(TAG, "🚨 Sending EMERGENCY signal to Flutter...")
                    methodChannel.invokeMethod("onTriplePowerPress", true)
                    Log.d(TAG, "✅ Emergency signal sent successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error sending emergency signal: ${e.message}")
                }
                return // Don't send regular screen state change for emergency
            }
        }

        // Send regular screen state change for counting (only if not emergency)
        try {
            methodChannel.invokeMethod("onScreenStateChanged", isScreenOn)
        } catch (e: Exception) {
            Log.e(TAG, "Error invoking Flutter screen state method: ${e.message}")
        }
    }
}
