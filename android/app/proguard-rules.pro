# ══════════════════════════════════════════════════════════════════
#  ATURAN PROGUARD / R8 — ISAN FLUTTER
# ══════════════════════════════════════════════════════════════════
#
#  Dipakai saat build release dengan minifyEnabled + obfuscate.
#  Tanpa berkas ini, R8 bisa "membuang" atau "menyamarkan" kelas
#  yang sebenarnya dibutuhkan saat aplikasi berjalan — akibatnya
#  aplikasi mogok (crash) walaupun build-nya berhasil.
#
#  Aturan di bawah MENJAGA kelas-kelas yang dipanggil dari luar
#  Java (native / Flutter / WebView), karena ProGuard tidak bisa
#  melihat pemanggil dari sana.

# ──────────────────────────────────────────────────────────────────
#  1. FLUTTER ENGINE
# ──────────────────────────────────────────────────────────────────
#  Mesin Flutter memanggil kelas JNI ini lewat nama, jadi nama
#  kelas & metodenya TIDAK BOLEH disamarkan.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ──────────────────────────────────────────────────────────────────
#  2. WEBVIEW & JEMBATAN JAVASCRIPT (paling mudah rusak)
# ──────────────────────────────────────────────────────────────────
#  Kode di dalam WebView memanggil jembatan Javascript lewat nama
#  metode. Kalau disamarkan, pengambilan video DARI webview akan
#  gagal total — pemutar & pengunduh tidak jalan.
#
#  ⚠️ Ini yang menjaga lapisan blokir iklan & pemeriksa video
#     di BackgroundWebView.java / IsanWebViewPlatformView.java.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ──────────────────────────────────────────────────────────────────
#  3. KELAS APLIKASI ISAN (yang dipanggil dari Platform Channel)
# ──────────────────────────────────────────────────────────────────
#  Kelas-kelas ini dipanggil oleh Dart lewat nama kanal / nama
#  kelas. Menyembunyikannya bisa memutus komunikasi Dart ↔ Android.
-keep class com.isan.isan_flutter.** { *; }
-keep class com.isan.** { *; }

#  Berkas .java milik proyek yang memakai kata kunci "native",
#  "JavascriptInterface", atau dipanggil dari refleksi.
-keepclasseswithmembers class * {
    native <methods>;
}

# ──────────────────────────────────────────────────────────────────
#  4. FIREBASE / GOOGLE PLAY SERVICE
# ──────────────────────────────────────────────────────────────────
#  Firebase memakai refleksi untuk membuat kelasnya sendiri.
#  Tanpa aturan ini, notifikasi (FCM) bisa gagal saat rilis.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ──────────────────────────────────────────────────────────────────
#  5. AUDIO LATAR (PlaybackService)
# ──────────────────────────────────────────────────────────────────
#  Layanan ini bisa dimatikan/dinyalakan sistem lewat nama kelas.
-keep class * extends android.app.Service { *; }
-keep class * extends android.content.BroadcastReceiver { *; }

# ──────────────────────────────────────────────────────────────────
#  6. KOTLIN & KORONELIN (dipakai plugin modern)
# ──────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ──────────────────────────────────────────────────────────────────
#  7. PAKET FLUTTER YANG MEMAKAI REFLEKSI
# ──────────────────────────────────────────────────────────────────
#  video_player, shared_preferences, flutter_secure_storage,
#  path_provider, webview_cef (desktop), dll.
-keep class androidx.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.**
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.github.ponnamkarthik.toast.fluttertoast.** { *; }
-dontwarn org.chromium.**

# ──────────────────────────────────────────────────────────────────
#  8. UMUM — jangan berlebihan membuang
# ──────────────────────────────────────────────────────────────────
#  Pertahankan kelas yang punya konstruktor tanpa argumen karena
#  sering dibuat lewat refleksi.
-keepclasseswithmembers,allowshrinking class * {
    public <init>();
}

#  Jangan tampilkan peringatan untuk kelas opsional yang memang
#  tidak dipakai di perangkat tertentu.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
