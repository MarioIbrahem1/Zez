package com.example.road_helperr;

import android.content.Context;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.telephony.TelephonyManager;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class SimServicePlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "SimServicePlugin";
    private static final String CHANNEL_NAME = "com.example.road_helperr/sim_service";

    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        context = binding.getApplicationContext();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            switch (call.method) {
                case "hasDualSim":
                    result.success(hasDualSim());
                    break;
                case "getSimInfo":
                    result.success(getSimInfo());
                    break;
                case "getActiveSimCount":
                    result.success(getActiveSimCount());
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in SimServicePlugin: " + e.getMessage());
            result.error("SIM_ERROR", e.getMessage(), null);
        }
    }

    private boolean hasDualSim() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                SubscriptionManager subscriptionManager = (SubscriptionManager) context
                        .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                if (subscriptionManager != null) {
                    List<SubscriptionInfo> subscriptionInfos = subscriptionManager.getActiveSubscriptionInfoList();
                    if (subscriptionInfos != null) {
                        boolean hasDual = subscriptionInfos.size() >= 2;
                        Log.d(TAG, "Dual SIM check: " + hasDual + " (found " + subscriptionInfos.size()
                                + " active subscriptions)");
                        return hasDual;
                    }
                }
            }

            // Fallback method for older Android versions
            TelephonyManager telephonyManager = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (telephonyManager != null) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    int phoneCount = telephonyManager.getPhoneCount();
                    boolean hasDual = phoneCount >= 2;
                    Log.d(TAG, "Dual SIM check (fallback): " + hasDual + " (phone count: " + phoneCount + ")");
                    return hasDual;
                }
            }

            Log.d(TAG, "Dual SIM check: false (unable to determine)");
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Error checking dual SIM: " + e.getMessage());
            return false;
        }
    }

    private List<Map<String, Object>> getSimInfo() {
        List<Map<String, Object>> simInfoList = new ArrayList<>();

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                SubscriptionManager subscriptionManager = (SubscriptionManager) context
                        .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                if (subscriptionManager != null) {
                    List<SubscriptionInfo> subscriptionInfos = subscriptionManager.getActiveSubscriptionInfoList();
                    if (subscriptionInfos != null) {
                        for (SubscriptionInfo info : subscriptionInfos) {
                            Map<String, Object> simInfo = new HashMap<>();
                            simInfo.put("subscriptionId", info.getSubscriptionId());
                            simInfo.put("simSlotIndex", info.getSimSlotIndex());
                            simInfo.put("carrierName",
                                    info.getCarrierName() != null ? info.getCarrierName().toString() : "Unknown");
                            simInfo.put("displayName", info.getDisplayName() != null ? info.getDisplayName().toString()
                                    : "SIM " + (info.getSimSlotIndex() + 1));
                            simInfo.put("phoneNumber", info.getNumber() != null ? info.getNumber() : "Unknown");
                            simInfo.put("countryIso", info.getCountryIso() != null ? info.getCountryIso() : "Unknown");

                            simInfoList.add(simInfo);

                            Log.d(TAG, "SIM Info: ID=" + info.getSubscriptionId() +
                                    ", Slot=" + info.getSimSlotIndex() +
                                    ", Carrier=" + info.getCarrierName() +
                                    ", Display=" + info.getDisplayName());
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting SIM info: " + e.getMessage());
        }

        Log.d(TAG, "Found " + simInfoList.size() + " SIM cards");
        return simInfoList;
    }

    private int getActiveSimCount() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                SubscriptionManager subscriptionManager = (SubscriptionManager) context
                        .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                if (subscriptionManager != null) {
                    List<SubscriptionInfo> subscriptionInfos = subscriptionManager.getActiveSubscriptionInfoList();
                    if (subscriptionInfos != null) {
                        int count = subscriptionInfos.size();
                        Log.d(TAG, "Active SIM count: " + count);
                        return count;
                    }
                }
            }

            // Fallback method for older Android versions
            TelephonyManager telephonyManager = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (telephonyManager != null) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    int phoneCount = telephonyManager.getPhoneCount();
                    Log.d(TAG, "Active SIM count (fallback): " + phoneCount);
                    return phoneCount;
                }
            }

            Log.d(TAG, "Active SIM count: 0 (unable to determine)");
            return 0;
        } catch (Exception e) {
            Log.e(TAG, "Error getting active SIM count: " + e.getMessage());
            return 0;
        }
    }
}
