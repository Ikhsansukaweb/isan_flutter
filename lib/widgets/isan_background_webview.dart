import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pemutar_linux.dart' as linux;

/// Wrapper Dart untuk PlatformView native "isan_background_webview"
/// (lihat android/app/src/main/java/.../IsanWebViewPlatformView.java).
///
/// WebView ini beda dari WebViewWidget biasa (webview_flutter): dia pakai
/// BackgroundWebView.java yang sengaja nge-block sinyal
/// onWindowVisibilityChanged() ke Chromium saat window jadi invisible
/// (app diminimize). Efeknya, audio/video yang lagi dimainkan di
/// dalamnya TIDAK auto-pause begitu user keluar/minimize app -- beda
/// dengan WebView Android biasa yang otomatis pause media saat dianggap
/// "hidden" demi hemat baterai.
///
/// PENTING: baseUrl HARUS domain yang valid (misal https://isanim.web.id),
/// BUKAN https://www.youtube.com -- kalau base URL-nya domain youtube.com
/// itu sendiri, YouTube IFrame API nolak origin-nya (error 152).
class IsanBackgroundWebView extends StatefulWidget {
  final String? html;
  final String? url;
  final String baseUrl;
  final String? userAgent;
  final IsanWebViewController controller;
  final void Function(String url)? onPageFinished;

  const IsanBackgroundWebView({
    super.key,
    this.html,
    this.url,
    this.baseUrl = 'https://isanim.web.id',
    this.userAgent,
    required this.controller,
    this.onPageFinished,
  }) : assert(html != null || url != null, 'html atau url harus diisi salah satu');

  @override
  State<IsanBackgroundWebView> createState() => _IsanBackgroundWebViewState();
}

class _IsanBackgroundWebViewState extends State<IsanBackgroundWebView> {
  /// Khusus Linux: controller CEF (dibuat sekali, dipakai ulang).
  linux.IsanWebViewControllerLinux? _linuxCtrl;

  @override
  Widget build(BuildContext context) {
    // ══════════════════════════════════════════════════════════════
    //  CABANG LINUX  ←  KHUSUS DESKTOP
    //  --------------------------------
    //  Android TIDAK melewati cabang ini. Kode Android di bawah
    //  (AndroidView + viewType 'isan_background_webview') tetap
    //  dijalankan PERSIS seperti sebelumnya di perangkat Android.
    //
    //  Di Linux, PlatformView native tidak tersedia (Flutter tidak
    //  punya platform view untuk Linux), jadi dipakai CEF/Chromium
    //  lewat paket webview_cef — mesin yang sama dengan Android.
    // ══════════════════════════════════════════════════════════════
    if (Platform.isLinux) {
      _linuxCtrl ??= linux.IsanWebViewControllerLinux()
        ..onError = widget.controller.onError
        ..onEnded = widget.controller.onEnded
        ..onLog = widget.controller.onLog
        ..onPopupBlocked = widget.controller.onPopupBlocked
        ..onRedirectBlocked = widget.controller.onRedirectBlocked
        ..pageFinished = widget.onPageFinished;

      return linux.PemutarLinux(
        key: ValueKey<String>(
            'isan-linux-view-${widget.url ?? widget.html?.hashCode ?? ''}'),
        url: widget.url,
        html: widget.html,
        userAgent: widget.userAgent,
        controller: _linuxCtrl!,
      );
    }

    final creationParams = <String, dynamic>{
      if (widget.html != null) 'html': widget.html,
      if (widget.url != null) 'url': widget.url,
      'baseUrl': widget.baseUrl,
      if (widget.userAgent != null) 'userAgent': widget.userAgent,
    };

    return AndroidView(
      // ── KEY STABIL: JANGAN DIHAPUS ────────────────────────────────
      //
      // Wajib ada. Tanpa key, setiap kali pohon widget dibangun ulang
      // Flutter membuat PlatformView BARU sehingga WebView di-load
      // ulang dari nol. Pembangunan ulang itu PASTI terjadi saat layar
      // berputar (mis. saat masuk/keluar fullscreen, karena orientasi
      // dikunci ke lanskap), dan akibatnya pemutar terlihat kembali ke
      // awal / layar kosong.
      //
      // Key ini HANYA berubah kalau URL-nya benar-benar ganti (ganti
      // film atau ganti episode) — dan itu memang harus memuat ulang.
      key: ValueKey<String>('isan-bg-view-${widget.url ?? widget.html?.hashCode ?? ''}'),
      viewType: 'isan_background_webview',
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        widget.controller._attach(id, widget.onPageFinished);
      },
    );
  }
}

/// Controller buat manggil method native (loadUrl/loadHtml/runJs/goBack/
/// reload) dan dengerin event pageFinished/ended/error dari WebView
/// native-nya (lihat IsanBridge JavascriptInterface di
/// IsanWebViewPlatformView.java).
class IsanWebViewController {
  MethodChannel? _channel;
  void Function(String code)? onError;
  VoidCallback? onEnded;
  void Function(String message)? onLog;

  /// Dipanggil tiap kali WebView native berhasil nge-block popup/window baru
  /// (window.open() atau <a target="_blank">.click()) -- lihat onCreateWindow
  /// di IsanWebViewPlatformView.java.
  VoidCallback? onPopupBlocked;

  /// Dipanggil tiap kali WebView native nge-block percobaan redirect
  /// otomatis ke host lain (bukan hasil loadUrl() eksplisit dari Dart) --
  /// biasanya pola iklan/frame-busting. [host] adalah domain tujuan yang
  /// diblokir.
  void Function(String host)? onRedirectBlocked;

  void _attach(int viewId, void Function(String url)? onPageFinished) {
    final channel = MethodChannel('isan_background_webview_$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pageFinished':
          onPageFinished?.call(call.arguments as String? ?? '');
          break;
        case 'ended':
          onEnded?.call();
          break;
        case 'error':
          onError?.call(call.arguments as String? ?? '');
          break;
        case 'log':
          onLog?.call(call.arguments as String? ?? '');
          break;
        case 'popupBlocked':
          onPopupBlocked?.call();
          break;
        case 'redirectBlocked':
          onRedirectBlocked?.call(call.arguments as String? ?? '');
          break;
      }
    });
  }

  Future<void> loadUrl(String url) async {
    await _channel?.invokeMethod('loadUrl', url);
  }

  Future<void> loadHtml(String html) async {
    await _channel?.invokeMethod('loadHtml', html);
  }

  Future<void> runJs(String js) async {
    await _channel?.invokeMethod('runJs', js);
  }

  Future<void> goBack() async {
    await _channel?.invokeMethod('goBack');
  }

  Future<void> reload() async {
    await _channel?.invokeMethod('reload');
  }
}
