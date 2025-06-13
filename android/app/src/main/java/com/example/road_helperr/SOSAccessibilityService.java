package com.example.road_helperr;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;

public class SOSAccessibilityService extends AccessibilityService {
    private static final String TAG = "SOSAccessibilityService";
    private static final long TRIPLE_PRESS_TIMEOUT = 2000; // 2 seconds
    private static final String POWER_BUTTON_CHANNEL = "com.example.road_helperr/power_button";

    private int powerButtonPressCount = 0;
    private Handler handler = new Handler(Looper.getMainLooper());
    private Runnable resetCountRunnable;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // This service is primarily for power button detection
        // The actual power button detection is handled by PowerButtonReceiver
        // This service can be used for additional accessibility features if needed
    }

    @Override
    public void onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted");
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        Log.d(TAG, "SOS Accessibility Service connected");
    }

    @Override
    public boolean onUnbind(Intent intent) {
        Log.d(TAG, "SOS Accessibility Service unbound");
        return super.onUnbind(intent);
    }

    // This method can be called from native code if needed for power button
    // detection
    public void onPowerButtonPressed() {
        powerButtonPressCount++;

        // Cancel previous reset timer
        if (resetCountRunnable != null) {
            handler.removeCallbacks(resetCountRunnable);
        }

        // Set new reset timer
        resetCountRunnable = new Runnable() {
            @Override
            public void run() {
                powerButtonPressCount = 0;
            }
        };
        handler.postDelayed(resetCountRunnable, TRIPLE_PRESS_TIMEOUT);

        Log.d(TAG, "Power button press count: " + powerButtonPressCount);

        // Check for triple press
        if (powerButtonPressCount >= 3) {
            Log.d(TAG, "Triple power button press detected!");
            powerButtonPressCount = 0;

            // Cancel reset timer
            if (resetCountRunnable != null) {
                handler.removeCallbacks(resetCountRunnable);
            }

            // Trigger SOS alert
            triggerSOSAlert();
        }
    }

    private void triggerSOSAlert() {
        Log.d(TAG, "Triggering SOS alert from accessibility service");

        // Send broadcast to notify the app about triple press
        Intent intent = new Intent("com.example.road_helperr.TRIPLE_POWER_PRESS");
        sendBroadcast(intent);

        // You can also use other methods to communicate with the Flutter app
        // such as starting an activity or using a method channel if available
    }
}
