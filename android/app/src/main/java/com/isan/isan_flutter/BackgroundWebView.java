package com.isan.isan_flutter;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.webkit.WebView;

/**
 * WebView bawaan Android otomatis ngasih tau engine Chromium di dalemnya
 * begitu window-nya jadi invisible (misal user pencet Home / pindah app
 * lain) lewat onWindowVisibilityChanged(). Begitu Chromium tau halamannya
 * "hidden", dia otomatis pause semua audio/video buat hemat baterai --
 * ini kejadian otomatis di level WebView, BUKAN karena kita manggil
 * webView.onPause()/pauseTimers() manual.
 *
 * Class ini cuma nge-block sinyal itu KETIKA window jadi invisible.
 * Sinyal pas window jadi visible (misal pertama kali app dibuka) tetap
 * diteruskan seperti biasa -- soalnya itu yang dipakai WebView buat tau
 * "saya sekarang kelihatan, mulai render". Kalau ini juga diblokir,
 * WebView gak akan pernah mulai render apa-apa (layar jadi hitam).
 */
public class BackgroundWebView extends WebView {

    public BackgroundWebView(Context context) {
        super(context);
    }

    public BackgroundWebView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public BackgroundWebView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    public void onWindowVisibilityChanged(int visibility) {
        if (visibility == View.VISIBLE) {
            super.onWindowVisibilityChanged(visibility);
        }
        // kalau jadi GONE/INVISIBLE (app diminimize), sengaja gak diteruskan
    }

    @Override
    public void dispatchWindowVisibilityChanged(int visibility) {
        // dispatchWindowVisibilityChanged() ini method internal View yang
        // MENDAHULUI onWindowVisibilityChanged() di call chain Android --
        // beberapa versi WebView/Chromium ada yang hook ke titik ini juga.
        // Block di sini juga supaya gak ada celah sinyal "hidden" yang
        // kelolos lewat jalur lain.
        if (visibility == View.VISIBLE) {
            super.dispatchWindowVisibilityChanged(visibility);
        }
    }

    @Override
    protected void onVisibilityChanged(View changedView, int visibility) {
        if (visibility == View.VISIBLE) {
            super.onVisibilityChanged(changedView, visibility);
        }
    }

    @Override
    protected void dispatchVisibilityChanged(View changedView, int visibility) {
        // Sama seperti di atas, tapi untuk jalur onVisibilityChanged().
        if (visibility == View.VISIBLE) {
            super.dispatchVisibilityChanged(changedView, visibility);
        }
    }
}