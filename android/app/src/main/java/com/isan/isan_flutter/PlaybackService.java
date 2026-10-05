package com.isan.isan_flutter;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import java.io.InputStream;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Foreground service ini gak mutar audio sendiri — audio/musik tetap
 * jalan dari dalam WebView (HTML5 audio/video player di web isanim.web.id).
 * Tugas service ini cuma satu: bikin sistem Android anggap proses app ini
 * "penting" lewat notifikasi persistent, jadi gak gampang dibunuh saat
 * app diminimize. Efeknya, WebView & javascript di dalamnya (termasuk
 * audio yang sedang dimainkan) tetap jalan di background.
 *
 * Judul/subjudul notifikasi bisa di-update on-the-fly lewat
 * ACTION_UPDATE biar nampilin judul lagu/film yang lagi diputer
 * (dipanggil dari MainActivity via MethodChannel "isan/playback").
 *
 * Album art (EXTRA_ARTWORK_URL) cuma diambil & ditampilkan kalau ini lagu
 * musik (bukan film/series) — biar notifikasi musik mirip player musik
 * pada umumnya, MediaStyle + largeIcon thumbnail.
 */
public class PlaybackService extends Service {

    private static final String CHANNEL_ID = "isan_playback_channel";
    private static final int NOTIF_ID = 1;

    public static final String ACTION_UPDATE = "com.isan.isan_flutter.UPDATE_NOTIF";
    public static final String ACTION_PREV = "com.isan.isan_flutter.ACTION_PREV";
    public static final String ACTION_PLAY_PAUSE = "com.isan.isan_flutter.ACTION_PLAY_PAUSE";
    public static final String ACTION_NEXT = "com.isan.isan_flutter.ACTION_NEXT";
    public static final String EXTRA_TITLE = "extra_title";
    public static final String EXTRA_SUBTITLE = "extra_subtitle";
    public static final String EXTRA_IS_PLAYING = "extra_is_playing";
    public static final String EXTRA_ARTWORK_URL = "extra_artwork_url";

    private String title = "ISAN";
    private String subtitle = "Sedang berjalan di background";
    private boolean isPlaying = true;
    private String artworkUrl = null;
    private Bitmap artworkBitmap = null;

    private final ExecutorService artworkExecutor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        startForeground(NOTIF_ID, buildNotification());
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;
        String action = intent.getAction();
        Log.d("ISAN_NOTIF", "onStartCommand action=" + action);
        if (ACTION_UPDATE.equals(action)) {
            String t = intent.getStringExtra(EXTRA_TITLE);
            String s = intent.getStringExtra(EXTRA_SUBTITLE);
            String artUrl = intent.getStringExtra(EXTRA_ARTWORK_URL);
            if (t != null) title = t;
            if (s != null) subtitle = s;
            isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, isPlaying);

            if (artUrl != null && !artUrl.equals(artworkUrl)) {
                // Thumbnail baru -> reset bitmap lama, tampilkan notif tanpa
                // largeIcon dulu, lalu load gambar baru di background thread.
                artworkUrl = artUrl;
                artworkBitmap = null;
                refreshNotification();
                loadArtwork(artUrl);
            } else if (artUrl == null && artworkUrl != null) {
                // Film/series (gak ada artwork) -> bersihkan largeIcon lama.
                artworkUrl = null;
                artworkBitmap = null;
                refreshNotification();
            } else {
                refreshNotification();
            }
        } else if (ACTION_PREV.equals(action)) {
            Log.d("ISAN_NOTIF", "dispatching prev");
            PlaybackBridge.dispatch("prev");
        } else if (ACTION_PLAY_PAUSE.equals(action)) {
            Log.d("ISAN_NOTIF", "dispatching toggle");
            PlaybackBridge.dispatch("toggle");
        } else if (ACTION_NEXT.equals(action)) {
            Log.d("ISAN_NOTIF", "dispatching next");
            PlaybackBridge.dispatch("next");
        }
        return START_STICKY;
    }

    private void loadArtwork(String url) {
        artworkExecutor.execute(() -> {
            try {
                InputStream in = new URL(url).openStream();
                Bitmap bmp = BitmapFactory.decodeStream(in);
                in.close();
                if (bmp != null && url.equals(artworkUrl)) {
                    artworkBitmap = bmp;
                    mainHandler.post(this::refreshNotification);
                }
            } catch (Exception ignored) {
                // Gagal load artwork bukan fatal -- notifikasi tetap tampil tanpa largeIcon.
            }
        });
    }

    private void refreshNotification() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify(NOTIF_ID, buildNotification());
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, "ISAN Playback", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("Menjaga ISAN tetap berjalan di background saat musik/video diputar");
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private Notification buildNotification() {
        Intent openAppIntent = new Intent(this, MainActivity.class);
        openAppIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, openAppIntent, flags);
        PendingIntent prevPi = actionPendingIntent(ACTION_PREV, 1, flags);
        PendingIntent playPausePi = actionPendingIntent(ACTION_PLAY_PAUSE, 2, flags);
        PendingIntent nextPi = actionPendingIntent(ACTION_NEXT, 3, flags);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setSmallIcon(R.drawable.ic_notif_small)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .addAction(R.drawable.ic_media_previous, "Sebelumnya", prevPi)
                .addAction(
                        isPlaying ? R.drawable.ic_media_pause : R.drawable.ic_media_play,
                        isPlaying ? "Jeda" : "Putar",
                        playPausePi)
                .addAction(R.drawable.ic_media_next, "Selanjutnya", nextPi)
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setShowActionsInCompactView(0, 1, 2));

        // Album art lagu (cuma ada kalau ACTION_UPDATE ngirim extra_artwork_url,
        // yaitu pas musik diputer -- film/series gak ngirim ini).
        if (artworkBitmap != null) {
            builder.setLargeIcon(artworkBitmap);
        }

        return builder.build();
    }

    private PendingIntent actionPendingIntent(String action, int requestCode, int flags) {
        Intent intent = new Intent(this, PlaybackService.class);
        intent.setAction(action);
        return PendingIntent.getService(this, requestCode, intent, flags);
    }

    @Override
    public void onDestroy() {
        artworkExecutor.shutdown();
        super.onDestroy();
    }
}
