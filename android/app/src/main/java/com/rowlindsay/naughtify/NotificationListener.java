package com.rowlindsay.naughtify;

import android.annotation.TargetApi;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

@TargetApi(25)
public class NotificationListener extends NotificationListenerService {

    @Override
    public void onCreate() {
        super.onCreate();
        UIActionReceiver actionReceiver = new UIActionReceiver();
        IntentFilter filter = new IntentFilter();
        filter.addAction("com.rowlindsay.UI");
        registerReceiver(actionReceiver,filter);
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        Intent i = new Intent("com.rowlindsay.NOTIFICATION_LISTEN");
        i.putExtra("notification event","notification added");
        sendBroadcast(i);

        Intent notificationSend = new Intent("com.rowlindsay.NOTIFICATION_LISTEN");
        notificationSend.putExtra("notification info",sbn);
        sendBroadcast(notificationSend);

        NotificationListener.this.cancelAllNotifications();
        //TODO: remove vibration and sound
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        Intent i = new Intent("com.rowlindsay.NOTIFICATION_LISTEN");
        i.putExtra("notification event","notification removed");
        sendBroadcast(i);
    }

    class UIActionReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getStringExtra("uicommand").equals("clearNotifications")) {
                NotificationListener.this.cancelAllNotifications();
            }
        }
    }
}
