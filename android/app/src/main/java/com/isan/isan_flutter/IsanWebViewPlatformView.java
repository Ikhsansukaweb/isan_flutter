package com.isan.isan_flutter;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.pm.ActivityInfo;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

/**
 * PlatformView yang isinya BackgroundWebView (lihat BackgroundWebView.java).
 * Dipakai dari Dart lewat AndroidView(viewType: "isan_background_webview").
 * Tiap instance punya MethodChannel sendiri (isan_background_webview_{id})
 * buat loadUrl / runJs / goBack dari Dart, dan ngirim balik event
 * "pageStarted"/"pageFinished" ke Dart.
 *
 * ── AD/POPUP BLOCKING ────────────────────────────────────────────────────
 * Beberapa provider player pihak ketiga (misal Abyss/Hydrax) nyisipin
 * overlay yang manggil window.open(url) atau bikin <a target="_blank"> lalu
 * .click() secara programatik buat munculin iklan di tab/window baru. Itu
 * SEMUA jalan di dalam iframe cross-origin, jadi TIDAK BISA di-block lewat
 * JS injection dari halaman parent (same-origin policy) -- makanya blocking
 * ini WAJIB terjadi di level native, ada 2 layer:
 *
 *  1) onCreateWindow (WebChromeClient) -> SELALU return false. Ini nge-block
 *     window.open() dan target="_blank" (Android WebView gak bakal bikin
 *     window/tab baru sama sekali). Ini aman diterapkan universal karena
 *     video/audio player normal gak pernah butuh buka window baru.
 *
 *  2) shouldOverrideUrlLoading (WebViewClient) -> begitu WebView ini pertama
 *     kali di-load-in (baik dari creationParams.url ATAUPUN loadUrl() yang
 *     dipanggil eksplisit dari Dart), host dari URL itu "dikunci"
 *     (lockedHost). Kalau SETELAH itu ada percobaan navigasi main-frame ke
 *     host lain (biasanya dipicu skrip iklan lewat location.href/location.
 *     replace, atau frame-busting check semacam
 *     "if(top.location==self.location) location='https://abyss.to'"),
 *     navigasi itu DIBLOK (return true = "sudah di-handle, jangan
 *     dijalankan"). Begitu Dart manggil loadUrl() lagi secara eksplisit
 *     (misal ganti server player), lockedHost di-reset ke host yang baru --
 *     jadi ini gak ganggu alur normal ganti-server, cuma nge-block redirect
 *     yang KEJADIAN SENDIRI dari dalam halaman tanpa diminta.
 */
public class IsanWebViewPlatformView implements PlatformView, MethodChannel.MethodCallHandler {

    private final Context context;
    private final BackgroundWebView webView;
    private final MethodChannel channel;
    private String baseUrl = "https://www.youtube.com";
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // Host yang lagi "dikunci" -- diisi tiap kali WebView di-load ke URL baru
    // (baik dari creationParams awal maupun loadUrl() dari Dart). Navigasi
    // main-frame otomatis (bukan dipicu loadUrl() dari Dart) ke host LAIN
    // akan diblok. null berarti belum ada yang perlu dikunci (misal baru
    // load dari html string, bukan url).
    private volatile String lockedHost = null;

    // ── State fullscreen (HTML5 Fullscreen API / native <video> fullscreen) ──
    // Chromium (basis WebView Android sejak API 21) manggil
    // onShowCustomView/onHideCustomView tiap kali halaman minta fullscreen --
    // baik lewat tombol fullscreen native <video> ATAUPUN element.
    // requestFullscreen() custom (yang dipakai JWPlayer/Abyss buat tombol
    // fullscreen mereka sendiri). Sebelumnya kedua method ini gak di-override
    // sama sekali, jadi request fullscreen selalu diam-diam diabaikan.
    private View customFullscreenView;
    private WebChromeClient.CustomViewCallback customViewCallback;
    private FrameLayout fullscreenContainer;
    private int savedOrientation;
    private int savedSystemUiVisibility;

    @SuppressWarnings("SetJavaScriptEnabled")
    IsanWebViewPlatformView(Context context, BinaryMessenger messenger, int viewId, @Nullable Map<String, Object> creationParams) {
        this.context = context;
        webView = new BackgroundWebView(context);
        channel = new MethodChannel(messenger, "isan_background_webview_" + viewId);
        channel.setMethodCallHandler(this);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        // PENTING: JANGAN pernah setSupportMultipleWindows(true) di sini --
        // itu prasyarat supaya onCreateWindow() beneran efektif nge-block
        // window baru (kalau di-set true, sebagian versi WebView bisa tetap
        // bikin window baru di luar kendali onCreateWindow kita).

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, Message resultMsg) {
                // Selalu tolak permintaan window/tab baru (popup iklan dari
                // window.open() ATAU <a target="_blank">.click()). return
                // false = "gak bikin apa-apa", user tetap di halaman yang
                // sama, gak ada tab/window nyempil.
                // (Catatan: setSupportMultipleWindows sengaja TIDAK diaktifkan,
                //  jadi window.open biasanya sudah diblokir Android sendiri.)
                mainHandler.post(() -> channel.invokeMethod("popupBlocked", null));
                return false;
            }

            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                if (customFullscreenView != null) {
                    // Udah ada custom view aktif (jarang kejadian, tapi jaga-jaga)
                    callback.onCustomViewHidden();
                    return;
                }
                Activity activity = getActivity(context);
                if (activity == null) {
                    // Gak ada Activity buat nempelin overlay fullscreen -- gak bisa
                    // diproses, tolak biar WebView gak nge-hang nunggu callback.
                    callback.onCustomViewHidden();
                    return;
                }
                customFullscreenView = view;
                customViewCallback = callback;

                FrameLayout decor = (FrameLayout) activity.getWindow().getDecorView();

                fullscreenContainer = new FrameLayout(activity);
                fullscreenContainer.setLayoutParams(new FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
                fullscreenContainer.addView(view, new FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
                decor.addView(fullscreenContainer);

                // Request focus agar input touch/click dapat diterima dengan baik oleh player controls
                view.setFocusable(true);
                view.setFocusableInTouchMode(true);
                view.requestFocus();

                fullscreenContainer.setFocusable(true);
                fullscreenContainer.setFocusableInTouchMode(true);
                fullscreenContainer.requestFocus();

                // Simpan keadaan UI SEBELUM diubah, supaya bisa dikembalikan
                // dengan benar saat keluar dari layar penuh.
                savedSystemUiVisibility = decor.getSystemUiVisibility();
                savedOrientation = activity.getRequestedOrientation();

                // WebView asli tetap dibiarkan VISIBLE agar engine render web (seperti custom player controls)
                // tidak freeze/nonaktif, sehingga tombol kecilkan kembali di controls tetap bisa diklik.
                // customFullscreenView dipasang di atas decor view activity jadi otomatis menutupi webView di bawahnya.

                decor.setSystemUiVisibility(
                        View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                );

                // Video biasanya lebih enak ditonton landscape -- kunci
                // sementara selama fullscreen, dikembaliin pas exit.
                //
                // PENTING: HANYA ubah kalau orientasinya memang berbeda.
                // Meminta orientasi yang SAMA dengan yang sedang berlaku
                // tetap membuat Android memicu perubahan konfigurasi --
                // dan perubahan itu membuat Flutter membangun ulang pohon
                // widget, WebView ikut di-load ulang, pemutar kembali ke
                // awal, dan tampak seperti "keluar fullscreen lalu ngulang".
                if (savedOrientation != ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                        && savedOrientation != ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
                    activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
                }
            }

            @Override
            public void onHideCustomView() {
                Activity activity = getActivity(context);

                // Kalau tidak ada custom view yang aktif, JANGAN langsung
                // pulang -- Chromium tetap perlu diberi tahu lewat
                // callback.onCustomViewHidden(), kalau tidak dia menganggap
                // fullscreen masih menyala dan terus mencoba membukanya
                // lagi. Itu salah satu sebab tampilan "keluar fullscreen
                // lalu mengulang".
                if (customFullscreenView == null) {
                    if (customViewCallback != null) {
                        customViewCallback.onCustomViewHidden();
                        customViewCallback = null;
                    }
                    return;
                }
                if (activity == null) return;

                FrameLayout decor = (FrameLayout) activity.getWindow().getDecorView();

                if (fullscreenContainer != null) {
                    decor.removeView(fullscreenContainer);
                }
                fullscreenContainer = null;
                customFullscreenView = null;

                decor.setSystemUiVisibility(savedSystemUiVisibility);

                // Sama seperti saat masuk: hanya ubah orientasi kalau
                // memang berbeda, supaya tidak memicu perubahan
                // konfigurasi yang membangun ulang WebView.
                int sekarang = activity.getRequestedOrientation();
                if (sekarang != savedOrientation) {
                    activity.setRequestedOrientation(savedOrientation);
                }

                // Kembalikan focus ke webView setelah keluar dari fullscreen
                webView.requestFocus();

                if (customViewCallback != null) {
                    customViewCallback.onCustomViewHidden();
                    customViewCallback = null;
                }
            }
        });

        webView.setWebViewClient(new android.webkit.WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (!request.isForMainFrame()) return false; // biarin navigasi di dalam iframe/subframe apa adanya
                String url = request.getUrl().toString();
                String host = safeHost(url);
                if (host == null) return false;

                if (lockedHost == null) {
                    // Belum ada host terkunci (load pertama) -- izinkan, lalu kunci.
                    lockedHost = host;
                    return false;
                }
                if (host.equalsIgnoreCase(lockedHost)) {
                    return false; // masih di host yang sama, aman
                }

                // ── NAVIGASI MAIN-FRAME KE HOST LAIN: DIBLOK ───────────────
                //
                // ── INI CARA HYDRAX (lihat penjelasan panjang di atas kelas) ──
                //
                // Begitu video DIKLIK, halaman pemutar mencoba pindah ke host
                // lain (pola iklan: location.href/location.replace, atau
                // frame-busting "if(top.location==self.location)
                // location='https://...'"). Karena host-nya beda dari host
                // yang dikunci, navigasi itu DIBLOK.
                //
                // Kenapa aman sekarang (dan dulu kelihatan "bikin rusak"):
                //   - Dulu pemutar film pakai WebViewWidget biasa
                //     (webview_flutter) yang AUTO-PAUSE video. Yang bikin
                //     layar kosong ("logo Android") itu auto-pause-nya, BUKAN
                //     blokir ini. Sekarang pemutarnya IsanBackgroundWebView
                //     (WebView native) yang tidak auto-pause -> video tetap
                //     jalan walau navigasi iklan diblok.
                //   - Host sumber video (i-arch-400.mendx437sim.com) dimuat
                //     lewat <video src>, bukan navigasi main-frame, jadi
                //     tidak ikut diblok.
                mainHandler.post(() -> channel.invokeMethod("redirectBlocked", host));
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                // onPageFinished sebenarnya sudah di main thread (dipanggil
                // dari WebViewClient), tapi tetap dibungkus mainHandler.post
                // untuk konsistensi dan jaga-jaga.
                mainHandler.post(() -> channel.invokeMethod("pageFinished", url));
            }
        });

        // Jembatan JS -> Dart. Dipanggil dari halaman HTML lewat
        // window.IsanBridge.onEnded() / .onError(code) -- dikirim balik ke
        // Dart sebagai method call di channel yang sama dengan pageFinished.
        //
        // PENTING: method @JavascriptInterface dieksekusi di thread WebView
        // sendiri ("JavaBridge"), BUKAN main/UI thread. MethodChannel.
        // invokeMethod() WAJIB dipanggil dari main thread -- kalau dipanggil
        // dari thread lain, dia throw RuntimeException ("Methods marked with
        // @UiThread must be executed on the main thread") yang ke-catch diam-
        // diam di level WebView (cuma muncul sebagai console error di JS,
        // app gak crash), dan invokeMethod-nya GAK PERNAH benar-benar
        // terkirim ke Dart. Itu sebabnya onEnded() (buat auto-next lagu)
        // gak pernah nyampe ke Dart sama sekali sebelum fix ini.
        webView.addJavascriptInterface(new Object() {
            @JavascriptInterface
            public void onEnded() {
                mainHandler.post(() -> channel.invokeMethod("ended", null));
            }

            @JavascriptInterface
            public void onError(String code) {
                mainHandler.post(() -> channel.invokeMethod("error", code));
            }

            @JavascriptInterface
            public void log(String msg) {
                mainHandler.post(() -> channel.invokeMethod("log", msg));
            }
        }, "IsanBridge");

        if (creationParams != null && creationParams.get("baseUrl") instanceof String) {
            baseUrl = (String) creationParams.get("baseUrl");
        }
        // User-Agent desktop opsional dari Dart -- dipakai buat bypass sebagian
        // pembatasan mobile embedding (misal YouTube IFrame API).
        if (creationParams != null && creationParams.get("userAgent") instanceof String) {
            settings.setUserAgentString((String) creationParams.get("userAgent"));
        }

        if (creationParams != null && creationParams.get("html") instanceof String) {
            webView.loadDataWithBaseURL(baseUrl, (String) creationParams.get("html"),
                    "text/html", "UTF-8", null);
        } else if (creationParams != null && creationParams.get("url") instanceof String) {
            String initialUrl = (String) creationParams.get("url");
            lockedHost = safeHost(initialUrl); // kunci host awal dari sini juga
            webView.loadUrl(initialUrl);
        }
    }


    @Nullable
    private static String safeHost(String url) {
        try {
            String host = Uri.parse(url).getHost();
            return host == null ? null : host.toLowerCase();
        } catch (Exception e) {
            return null;
        }
    }

    @NonNull
    @Override
    public View getView() {
        return webView;
    }

    @Override
    public void dispose() {
        // Kalau screen ini di-dispose (misal user pencet back) SELAGI lagi
        // fullscreen, fullscreenContainer yang udah ditempel ke decor view
        // Activity harus dicabut manual -- kalau enggak, dia jadi orphan
        // view yang nutupin layar terus meskipun WebView-nya sendiri udah
        // dihancurkan.
        Activity activity = getActivity(context);
        if (customFullscreenView != null && activity != null) {
            FrameLayout decor = (FrameLayout) activity.getWindow().getDecorView();
            decor.removeView(fullscreenContainer);
            decor.setSystemUiVisibility(savedSystemUiVisibility);
            activity.setRequestedOrientation(savedOrientation);
            customFullscreenView = null;
            fullscreenContainer = null;
            customViewCallback = null;
        }
        channel.setMethodCallHandler(null);
        webView.destroy();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "loadUrl":
                String url = (String) call.arguments;
                lockedHost = safeHost(url); // navigasi eksplisit dari Dart -> reset kunci host
                webView.loadUrl(url);
                result.success(null);
                break;
            case "loadHtml":
                webView.loadDataWithBaseURL(baseUrl, (String) call.arguments,
                        "text/html", "UTF-8", null);
                result.success(null);
                break;
            case "runJs":
                webView.evaluateJavascript((String) call.arguments, null);
                result.success(null);
                break;
            case "goBack":
                if (webView.canGoBack()) webView.goBack();
                result.success(null);
                break;
            case "reload":
                webView.reload();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    @Nullable
    private static Activity getActivity(Context context) {
        if (context == null) return null;
        if (context instanceof Activity) {
            return (Activity) context;
        }
        if (context instanceof ContextWrapper) {
            return getActivity(((ContextWrapper) context).getBaseContext());
        }
        return null;
    }
}