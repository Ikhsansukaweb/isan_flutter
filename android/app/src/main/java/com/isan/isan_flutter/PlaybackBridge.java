package com.isan.isan_flutter;

import android.util.Log;

/**
 * Jembatan sederhana antara PlaybackService (notifikasi) dan MainActivity
 * (Flutter MethodChannel). Service & Activity jalan di proses yang sama
 * (gak ada android:process terpisah di manifest), jadi cukup pakai
 * static listener -- gak perlu AIDL/Messenger.
 */
public class PlaybackBridge {

    public interface ActionListener {
        void onAction(String action); // "next" | "prev" | "toggle"
    }

    private static ActionListener listener;

    public static void setListener(ActionListener l) {
        Log.d("ISAN_NOTIF", "setListener called, listener=" + (l != null ? "non-null" : "null"));
        listener = l;
    }

    public static void dispatch(String action) {
        Log.d("ISAN_NOTIF", "dispatch(" + action + ") listener=" + (listener != null ? "non-null" : "NULL"));
        if (listener != null) {
            listener.onAction(action);
        }
    }
}
