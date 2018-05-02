package com.rowlindsay.naughtify;

import android.annotation.TargetApi;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

@TargetApi(22)
public class AndroidNotificationEncoder {

    private JSONArray notificationHistory;
    private JSONArray currentMuteSession;

    public AndroidNotificationEncoder() {
        notificationHistory = new JSONArray();
    }

    // no-op if not in a session
    public void encode(StatusBarNotification sbn) {
        if (inSession()) {
            JSONObject info = new JSONObject();
            try {
                info.put("timecode", sbn.getPostTime());
                info.put("packagename", sbn.getPackageName());
            } catch (JSONException jse) {
                Log.d("android encode", "error enncoding to json");
            }
            currentMuteSession.put(info);
        }
    }

    // returns a string that is encoded json - all notifications
    // received in this lifetime
    public String getHistory() {
        return notificationHistory.toString();
    }

    public void startSession() {
        if (!inSession()) {
            currentMuteSession = new JSONArray();
        }
    }

    public void endSession() {
        if (inSession()) {
            JSONObject session = new JSONObject();
            try {
                session.put("notifications", currentMuteSession);
            } catch (JSONException jse) {
                Log.d("android encode", "error enncoding to json");
            }
            notificationHistory.put(session);
            currentMuteSession = null;
        }
    }

    public boolean inSession() {
        return currentMuteSession != null;
    }

}