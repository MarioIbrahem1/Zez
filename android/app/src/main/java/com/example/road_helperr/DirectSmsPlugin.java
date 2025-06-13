package com.example.road_helperr;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.Looper;
import android.telephony.SmsManager;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class DirectSmsPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static final String TAG = "DirectSmsPlugin";
    private static final String CHANNEL_NAME = "com.example.road_helperr/direct_sms";
    private static final String STATUS_CHANNEL_NAME = "com.example.road_helperr/sms_status";
    private static final String ACTION_SMS_SENT = "com.example.road_helper.SMS_SENT";

    // Constants for SMS retry mechanism
    private static final String EXTRA_RETRY_PHONE_NUMBER = "retry_phone_number";
    private static final String EXTRA_RETRY_MESSAGE = "retry_message";
    private static final String EXTRA_RETRY_ATTEMPT = "retry_attempt";
    private static final String EXTRA_ORIGINAL_SIM_ID = "original_sim_id";

    // Flag to track if we're currently in a retry operation
    private static AtomicBoolean isRetrying = new AtomicBoolean(false);

    private MethodChannel channel;
    private MethodChannel statusChannel; // Channel for sending SMS status updates to Flutter
    private Context context;
    private Activity activity;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        // Main channel for method calls
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);

        // Status channel for sending SMS status updates to Flutter
        statusChannel = new MethodChannel(binding.getBinaryMessenger(), STATUS_CHANNEL_NAME);

        context = binding.getApplicationContext();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        // Unregister SMS receiver
        unregisterSmsReceiver();

        channel.setMethodCallHandler(null);
        channel = null;
        statusChannel = null;
        context = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    // Broadcast receivers to handle SMS sent status and retry requests
    private BroadcastReceiver smsSentReceiver;
    private BroadcastReceiver smsRetryReceiver;

    private void registerSmsReceiver() {
        // Register SMS sent receiver if not already registered
        if (smsSentReceiver == null) {
            smsSentReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (ACTION_SMS_SENT.equals(intent.getAction())) {
                        // Get subscription ID and other info from the intent
                        int subscriptionId = intent.getIntExtra("subscription_id", -1);
                        boolean isDefaultManager = intent.getBooleanExtra("default_manager", false);
                        String phoneNumber = intent.getStringExtra(EXTRA_RETRY_PHONE_NUMBER);
                        String message = intent.getStringExtra(EXTRA_RETRY_MESSAGE);
                        int retryAttempt = intent.getIntExtra(EXTRA_RETRY_ATTEMPT, 0);
                        int originalSimId = intent.getIntExtra(EXTRA_ORIGINAL_SIM_ID, -1);

                        // Get SIM info for logging
                        String simInfo = getSimInfo(context, subscriptionId, isDefaultManager);

                        switch (getResultCode()) {
                            case Activity.RESULT_OK:
                                Log.d(TAG, "SMS sent successfully" + simInfo);

                                // Notify Flutter about successful SMS
                                if (statusChannel != null) {
                                    try {
                                        final HashMap<String, Object> statusData = new HashMap<>();
                                        statusData.put("success", true);
                                        statusData.put("phoneNumber", phoneNumber);
                                        statusData.put("simId", subscriptionId);
                                        statusData.put("isRetry", retryAttempt > 0);

                                        // Run on UI thread to avoid "Methods marked with @UiThread must be executed on
                                        // the UI thread" error
                                        new Handler(Looper.getMainLooper()).post(new Runnable() {
                                            @Override
                                            public void run() {
                                                statusChannel.invokeMethod("onSmsSentStatus", statusData);
                                            }
                                        });
                                    } catch (Exception e) {
                                        Log.e(TAG, "Error sending success status to Flutter: " + e.getMessage());
                                    }
                                }

                                // Reset retry flag if we were in a retry operation
                                if (retryAttempt > 0) {
                                    isRetrying.set(false);
                                }
                                break;

                            case SmsManager.RESULT_ERROR_GENERIC_FAILURE:
                            case SmsManager.RESULT_ERROR_NO_SERVICE:
                            case SmsManager.RESULT_ERROR_NULL_PDU:
                            case SmsManager.RESULT_ERROR_RADIO_OFF:
                            default:
                                // Log the error
                                String errorMsg = "SMS sending failed";
                                String errorReason = "";
                                switch (getResultCode()) {
                                    case SmsManager.RESULT_ERROR_GENERIC_FAILURE:
                                        errorReason = "Generic failure";
                                        errorMsg += ": " + errorReason;
                                        break;
                                    case SmsManager.RESULT_ERROR_NO_SERVICE:
                                        errorReason = "No service";
                                        errorMsg += ": " + errorReason;
                                        break;
                                    case SmsManager.RESULT_ERROR_NULL_PDU:
                                        errorReason = "Null PDU";
                                        errorMsg += ": " + errorReason;
                                        break;
                                    case SmsManager.RESULT_ERROR_RADIO_OFF:
                                        errorReason = "Radio off";
                                        errorMsg += ": " + errorReason;
                                        break;
                                    default:
                                        errorReason = "Unknown error code: " + getResultCode();
                                        errorMsg += " with " + errorReason;
                                        break;
                                }
                                Log.e(TAG, errorMsg + simInfo);

                                // Notify Flutter about SMS failure
                                if (statusChannel != null) {
                                    try {
                                        final HashMap<String, Object> statusData = new HashMap<>();
                                        statusData.put("success", false);
                                        statusData.put("phoneNumber", phoneNumber);
                                        statusData.put("simId", subscriptionId);
                                        statusData.put("errorReason", errorReason);
                                        statusData.put("isRetry", retryAttempt > 0);

                                        // Run on UI thread
                                        new Handler(Looper.getMainLooper()).post(new Runnable() {
                                            @Override
                                            public void run() {
                                                statusChannel.invokeMethod("onSmsSentStatus", statusData);
                                            }
                                        });
                                    } catch (Exception e) {
                                        Log.e(TAG, "Error sending failure status to Flutter: " + e.getMessage());
                                    }
                                }

                                // Only attempt retry if we have the necessary info and we're not already
                                // retrying
                                if (phoneNumber != null && message != null && !isRetrying.get()) {
                                    // If this was the first SIM and we have a second SIM, try with the second SIM
                                    if (retryAttempt == 0) {
                                        List<Integer> subscriptionIds = getActiveSubscriptionIds();

                                        // Find the alternative SIM (not the one that just failed)
                                        Integer alternativeSimId = null;
                                        for (Integer simId : subscriptionIds) {
                                            if (simId != subscriptionId && simId != originalSimId) {
                                                alternativeSimId = simId;
                                                break;
                                            }
                                        }

                                        // If we found an alternative SIM, try sending with it
                                        if (alternativeSimId != null) {
                                            Log.d(TAG, "Retrying SMS with alternative SIM ID: " + alternativeSimId);
                                            isRetrying.set(true);
                                            sendSmsWithSubscription(phoneNumber, message, alternativeSimId, 1,
                                                    subscriptionId);
                                        } else {
                                            Log.e(TAG, "No alternative SIM available for retry");
                                            isRetrying.set(false);
                                        }
                                    } else {
                                        // If this was already a retry attempt, don't try again
                                        Log.e(TAG, "SMS sending failed on retry attempt. Giving up.");
                                        isRetrying.set(false);
                                    }
                                }
                                break;
                        }
                    }
                }
            };

            // Register the receiver
            IntentFilter filter = new IntentFilter(ACTION_SMS_SENT);
            context.registerReceiver(smsSentReceiver, filter, null, new Handler(Looper.getMainLooper()));
            Log.d(TAG, "SMS broadcast receiver registered with action: " + ACTION_SMS_SENT);
        }
    }

    // Helper method to get SIM info for logging
    private String getSimInfo(Context context, int subscriptionId, boolean isDefaultManager) {
        String simInfo = "";
        if (subscriptionId != -1) {
            simInfo = " (SIM ID: " + subscriptionId + ")";
            // Try to get more info about the SIM
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                try {
                    SubscriptionManager subscriptionManager = (SubscriptionManager) context
                            .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                    if (subscriptionManager != null) {
                        SubscriptionInfo info = subscriptionManager.getActiveSubscriptionInfo(subscriptionId);
                        if (info != null) {
                            simInfo = " (SIM " + info.getSimSlotIndex() + ", ID: " + subscriptionId + ")";
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error getting SIM info: " + e.getMessage());
                }
            }
        } else if (isDefaultManager) {
            simInfo = " (Default SmsManager)";
        }
        return simInfo;
    }

    private void unregisterSmsReceiver() {
        // Unregister SMS sent receiver
        if (smsSentReceiver != null) {
            try {
                context.unregisterReceiver(smsSentReceiver);
                smsSentReceiver = null;
                Log.d(TAG, "SMS broadcast receiver unregistered");
            } catch (Exception e) {
                Log.e(TAG, "Error unregistering SMS receiver: " + e.getMessage());
            }
        }

        // Reset retry flag
        isRetrying.set(false);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            if (call.method.equals("sendDirectSms")) {
                String phoneNumber = call.argument("phoneNumber");
                String message = call.argument("message");

                Log.d(TAG, "DirectSmsPlugin.sendDirectSms called with phone: " + phoneNumber);

                if (phoneNumber == null || message == null) {
                    result.error("INVALID_ARGUMENTS", "Phone number or message is null", null);
                    return;
                }

                // Register SMS broadcast receiver
                registerSmsReceiver();

                // Try to send SMS with all available SIM cards
                Log.d(TAG, "Attempting to send SMS with all available SIMs");
                boolean success = sendSmsWithAllSims(phoneNumber, message);
                Log.d(TAG, "SMS send attempt result: " + (success ? "SUCCESS" : "FAILURE"));
                result.success(success);
            } else {
                result.notImplemented();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in DirectSmsPlugin: " + e.getMessage());
            e.printStackTrace();
            result.error("SMS_ERROR", e.getMessage(), null);
        }
    }

    private boolean sendSmsWithAllSims(String phoneNumber, String message) {
        try {
            // Reset retry flag at the start of a new send operation
            isRetrying.set(false);

            // Get all active SIM subscriptions
            List<Integer> subscriptionIds = getActiveSubscriptionIds();

            Log.d(TAG, "Found " + subscriptionIds.size() + " active SIM subscriptions");

            if (subscriptionIds.isEmpty()) {
                Log.d(TAG, "No SIM subscriptions found, trying with default SmsManager");
                // If no subscriptions found, try with default SmsManager
                return sendSmsWithDefaultManager(phoneNumber, message);
            }

            boolean anySent = false;

            // Try with all available SIMs to ensure message delivery
            // For Android 14, we need to be more aggressive with sending through all SIMs

            // First try with SIM 1
            if (subscriptionIds.size() >= 1) {
                Integer sim1Id = subscriptionIds.get(0);
                Log.d(TAG, "Attempting to send SMS with primary SIM (ID: " + sim1Id + ")");
                try {
                    boolean sent1 = sendSmsWithSubscription(phoneNumber, message, sim1Id);
                    if (sent1) {
                        Log.d(TAG, "SMS command executed with primary SIM");
                        anySent = true;
                    } else {
                        Log.d(TAG, "Failed to execute SMS command with primary SIM");
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error sending SMS with primary SIM: " + e.getMessage());
                }
            }

            // Then try with SIM 2 regardless of SIM 1 result
            if (subscriptionIds.size() >= 2) {
                Integer sim2Id = subscriptionIds.get(1);
                Log.d(TAG, "Also attempting to send SMS with secondary SIM (ID: " + sim2Id + ")");
                try {
                    // Increase wait time between sending messages to avoid network congestion
                    try {
                        Thread.sleep(8000); // Increase wait to 8 seconds to give more time for the network
                    } catch (InterruptedException ie) {
                        // Ignore
                    }

                    boolean sent2 = sendSmsWithSubscription(phoneNumber, message, sim2Id);
                    if (sent2) {
                        Log.d(TAG, "SMS command executed with secondary SIM");
                        anySent = true;
                    } else {
                        Log.d(TAG, "Failed to execute SMS command with secondary SIM");
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error sending SMS with secondary SIM: " + e.getMessage());
                }
            }

            // If both SIM attempts failed immediately, try with default manager as last
            // resort
            if (!anySent) {
                Log.d(TAG, "All SIM attempts failed immediately, trying with default SmsManager");
                anySent = sendSmsWithDefaultManager(phoneNumber, message);
            }

            return anySent;
        } catch (Exception e) {
            Log.e(TAG, "Error sending SMS with all SIMs: " + e.getMessage());
            return false;
        }
    }

    private List<Integer> getActiveSubscriptionIds() {
        List<Integer> subscriptionIds = new ArrayList<>();

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                SubscriptionManager subscriptionManager = (SubscriptionManager) context
                        .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                if (subscriptionManager != null) {
                    List<SubscriptionInfo> subscriptionInfos = subscriptionManager.getActiveSubscriptionInfoList();
                    if (subscriptionInfos != null) {
                        for (SubscriptionInfo info : subscriptionInfos) {
                            subscriptionIds.add(info.getSubscriptionId());
                            Log.d(TAG, "Found active subscription: ID=" + info.getSubscriptionId() +
                                    ", Slot=" + info.getSimSlotIndex() +
                                    ", Carrier=" + info.getCarrierName());
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting active subscription IDs: " + e.getMessage());
        }

        return subscriptionIds;
    }

    private boolean sendSmsWithSubscription(String phoneNumber, String message, int subscriptionId) {
        return sendSmsWithSubscription(phoneNumber, message, subscriptionId, 0, -1);
    }

    private boolean sendSmsWithSubscription(String phoneNumber, String message, int subscriptionId, int retryAttempt,
            int originalSimId) {
        try {
            SmsManager smsManager;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                smsManager = SmsManager.getSmsManagerForSubscriptionId(subscriptionId);
            } else {
                smsManager = SmsManager.getDefault();
            }

            // Create pending intent for SMS sent status
            Intent sentIntent = new Intent(ACTION_SMS_SENT);
            sentIntent.putExtra("subscription_id", subscriptionId);
            sentIntent.putExtra("default_manager", false);
            sentIntent.putExtra(EXTRA_RETRY_PHONE_NUMBER, phoneNumber);
            sentIntent.putExtra(EXTRA_RETRY_MESSAGE, message);
            sentIntent.putExtra(EXTRA_RETRY_ATTEMPT, retryAttempt);
            sentIntent.putExtra(EXTRA_ORIGINAL_SIM_ID, originalSimId);

            PendingIntent sentPendingIntent = PendingIntent.getBroadcast(
                    context,
                    (int) System.currentTimeMillis(), // Use timestamp as request code to make it unique
                    sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

            // Split message if it's too long
            ArrayList<String> messageParts = smsManager.divideMessage(message);
            if (messageParts.size() > 1) {
                // Multi-part message
                ArrayList<PendingIntent> sentIntents = new ArrayList<>();
                for (int i = 0; i < messageParts.size(); i++) {
                    sentIntents.add(sentPendingIntent);
                }
                smsManager.sendMultipartTextMessage(phoneNumber, null, messageParts, sentIntents, null);
            } else {
                // Single message
                smsManager.sendTextMessage(phoneNumber, null, message, sentPendingIntent, null);
            }

            Log.d(TAG, "SMS send command executed for subscription ID: " + subscriptionId);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error sending SMS with subscription ID " + subscriptionId + ": " + e.getMessage());
            return false;
        }
    }

    private boolean sendSmsWithDefaultManager(String phoneNumber, String message) {
        try {
            SmsManager smsManager = SmsManager.getDefault();

            // Create pending intent for SMS sent status
            Intent sentIntent = new Intent(ACTION_SMS_SENT);
            sentIntent.putExtra("subscription_id", -1);
            sentIntent.putExtra("default_manager", true);
            sentIntent.putExtra(EXTRA_RETRY_PHONE_NUMBER, phoneNumber);
            sentIntent.putExtra(EXTRA_RETRY_MESSAGE, message);
            sentIntent.putExtra(EXTRA_RETRY_ATTEMPT, 0);
            sentIntent.putExtra(EXTRA_ORIGINAL_SIM_ID, -1);

            PendingIntent sentPendingIntent = PendingIntent.getBroadcast(
                    context,
                    (int) System.currentTimeMillis(),
                    sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

            // Split message if it's too long
            ArrayList<String> messageParts = smsManager.divideMessage(message);
            if (messageParts.size() > 1) {
                // Multi-part message
                ArrayList<PendingIntent> sentIntents = new ArrayList<>();
                for (int i = 0; i < messageParts.size(); i++) {
                    sentIntents.add(sentPendingIntent);
                }
                smsManager.sendMultipartTextMessage(phoneNumber, null, messageParts, sentIntents, null);
            } else {
                // Single message
                smsManager.sendTextMessage(phoneNumber, null, message, sentPendingIntent, null);
            }

            Log.d(TAG, "SMS send command executed with default SmsManager");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error sending SMS with default SmsManager: " + e.getMessage());
            return false;
        }
    }
}
