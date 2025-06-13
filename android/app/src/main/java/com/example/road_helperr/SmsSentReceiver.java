package com.example.road_helperr;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telephony.SmsManager;
import android.util.Log;

public class SmsSentReceiver extends BroadcastReceiver {
    private static final String TAG = "SmsSentReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.d(TAG, "Received broadcast with action: " + action);

        if ("com.example.road_helper.SMS_SENT".equals(action)) {
            int resultCode = getResultCode();
            String phoneNumber = intent.getStringExtra("retry_phone_number");
            int subscriptionId = intent.getIntExtra("subscription_id", -1);
            boolean isDefaultManager = intent.getBooleanExtra("default_manager", false);

            String simInfo = "";
            if (subscriptionId != -1) {
                simInfo = " (SIM ID: " + subscriptionId + ")";
            } else if (isDefaultManager) {
                simInfo = " (Default SmsManager)";
            }

            switch (resultCode) {
                case Activity.RESULT_OK:
                    Log.d(TAG, "SMS sent successfully to " + phoneNumber + simInfo);
                    break;
                case SmsManager.RESULT_ERROR_GENERIC_FAILURE:
                    Log.e(TAG, "SMS failed: Generic failure to " + phoneNumber + simInfo);
                    break;
                case SmsManager.RESULT_ERROR_NO_SERVICE:
                    Log.e(TAG, "SMS failed: No service to " + phoneNumber + simInfo);
                    break;
                case SmsManager.RESULT_ERROR_NULL_PDU:
                    Log.e(TAG, "SMS failed: Null PDU to " + phoneNumber + simInfo);
                    break;
                case SmsManager.RESULT_ERROR_RADIO_OFF:
                    Log.e(TAG, "SMS failed: Radio off to " + phoneNumber + simInfo);
                    break;
                default:
                    Log.e(TAG, "SMS failed: Unknown error code " + resultCode + " to " + phoneNumber + simInfo);
                    break;
            }
        }
    }
}
