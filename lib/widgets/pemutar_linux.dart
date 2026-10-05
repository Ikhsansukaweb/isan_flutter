import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';
import 'pengaman_galat.dart';

/// ══════════════════════════════════════════════════════════════════
///  PEMUTAR LINUX (CEF / Chromium) — KHUSUS DESKTOP LINUX
/// ══════════════════════════════════════════════════════════════════
///
///  Berkas ini HANYA dipakai kalau Platform.isLinux.
///  Android TIDAK menyentuh berkas ini — Android tetap memakai
///  PlatformView native "isan_background_webview"
///  (BackgroundWebView.java + IsanWebViewPlatformView.java).
///
///  Mesin: CEF = Chromium Embedded Framework (Chromium 149)
///         → mesin yang SAMA dengan WebView Android
///
///  ⚠️ KETERBATASAN (sudah kuperiksa di kode sumber webview_cef 0.6.2):
///     paket ini TIDAK punya callback untuk menolak navigasi/popup
///     (tidak ada onCreateWindow / shouldOverrideUrlLoading).
///     Blokir iklan dilakukan dengan 3 lapis:
///
///     LAPIS 1 — UserScript LOAD_START : penghalang JS SEBELUM
///               halaman jalan (matikan window.open, target=_blank,
///               iframe/script jaringan iklan)
///     LAPIS 2 — JavascriptChannel "IsanBlokir" : JS lapor ke Dart
///     LAPIS 3 — onUrlChanged : kalau URL lari ke host di luar
///               whitelist → paksa kembali
///
///  API diambil dari CONTOH RESMI paket (example/lib/main.dart),
///  bukan tebakan.
/// ══════════════════════════════════════════════════════════════════

/// Host yang BOLEH dimuat. Selain ini = dicurigai iklan.
///
/// ⚠️ PELAJARAN PENTING (pernah salah):
///    versi pertama daftar ini TERLALU SEMPIT — hanya memuat isanim.web.id,
///    youtube, archive.org, dll. Padahal aplikasi memutar video lewat
///    vidsrc.sbs, tv4.nontondrama.my, dan cinesrc.st. Akibatnya penjaga
///    "jangan keluar dari host yang sah" malah MENOLAK halaman pemutar
///    yang asli → video tidak pernah terbuka.
///
///    Jadi daftar ini harus memuat SEMUA penyedia embed yang dipakai
///    aplikasi. Kalau nanti ada penyedia baru, tambahkan di sini.
const Set<String> hostDiizinkan = {
  // ── Situs aplikasi sendiri ──
  'isanim.web.id',
  'workers.dev', // worker TMDB milik sendiri

  // ── PENYEDIA EMBED VIDEO (dipakai aplikasi ini) ──
  'vidsrc.sbs',
  'vidsrc.net',
  'vidsrc.to',
  'vidsrc.xyz',
  'vidsrc.cc',
  'vidsrc.me',
  'cinesrc.st',
  'nontondrama.my', // termasuk tv4.nontondrama.my
  'tv4.nontondrama.my',
  'nontondrama',
  '2anime.xyz',
  'animeindo',
  'oploverz',
  'samehadaku',
  'otakudesu',
  'kuramanime',
  'anoboy',

  // ── Pemutar dari layanan besar ──
  'youtube.com',
  'youtu.be',
  'googlevideo.com',
  'ytimg.com',
  'ggpht.com',
  'googleusercontent.com',
  'gstatic.com',
  'googleapis.com',
  'blogger.com',
  'blogspot.com',
  'firebaseapp.com',
  'cloudflare.com',
  'cloudflarestream.com',
  'archive.org',
  'ok.ru',
  'vk.com',
  'vimeo.com',
  'dailymotion.com',
  'dmcdn.net',
  'streamable.com',
  'mega.nz',
  'drive.google.com',
  'doodstream.com',
  'dood.',
  'streamtape.com',
  'streamtape.to',
  'mixdrop.co',
  'mixdrop.to',
  'upstream.to',
  'voe.sx',
  'filemoon.sx',
  'filemoon.to',
  'vidhide.com',
  'vidhidepro.com',
  'acefile.co',
  'embedrise.com',
  'player4me',
  'mp4upload.com',
  'abyss.to',
  'jwpcdn.com', // pemutar JW Player
  'jwplayer.com',
  'jwplatform.com',
  'akamaihd.net',
  'fastly.net',
  'bunnycdn.com',
  'b-cdn.net',
  'cloudfront.net',
  'amazonaws.com',
  'digitaloceanspaces.com',
  'facebook.com',
  'fbcdn.net',
  'instagram.com',
  'cdninstagram.com',
  'twitter.com',
  'twimg.com',
  'tiktok.com',
  'tiktokcdn.com',
  'bilibili.com',
  'hianime.to',
  'zoro.to',
  'aniwatch.to',
};

/// Jaringan iklan — SELALU ditolak.
///
/// Hanya nama jaringan IKLAN yang masuk daftar ini. Jangan pernah
/// menaruh domain penyedia video di sini.
const List<String> jaringanIklan = [
  'doubleclick', 'googlesyndication', 'googleadservices', 'adservice',
  'adsystem', 'adnxs', 'taboola', 'outbrain', 'popads', 'propellerads',
  'exoclick', 'juicyads', 'trafficjunky', 'adsterra', 'hilltopads',
  'clickadu', 'onclickads', 'mgid', 'revcontent', 'popcash', 'adcash',
  'adf.ly', 'shorte.st', 'linkvertise',
];

/// Apakah host boleh dimuat?
///
/// ATURAN KESELAMATAN (pelajaran dari kesalahan sebelumnya):
///   Yang diblokir HANYA jaringan iklan yang namanya sudah dikenal.
///   Host yang tidak dikenal TIDAK diblokir — kalau diblokir, penyedia
///   video baru yang belum terdaftar akan ikut mati dan video tidak
///   bisa diputar sama sekali (ini pernah terjadi).
bool hostBoleh(String url) {
  try {
    final u = Uri.parse(url);
    if (!u.hasScheme) return true; // data: / about: / blob:
    if (u.scheme != 'http' && u.scheme != 'https') return true;
    final h = u.host.toLowerCase();
    if (h.isEmpty) return true;

    // 1. Jaringan iklan yang sudah dikenal → TOLAK
    for (final jahat in jaringanIklan) {
      if (h.contains(jahat)) return false;
    }

    // 2. Selain iklan → IZINKAN.
    //    (Daftar hostDiizinkan tetap ada sebagai rujukan & untuk
    //     pemeriksaan lain, tetapi TIDAK dipakai sebagai penjaga
    //     tunggal — supaya halaman pemutar tidak ikut terblokir.)
    return true;
  } catch (_) {
    return true;
  }
}

/// ── LAPIS 1: JavaScript pemblokir, disuntik SEBELUM halaman jalan ──
const String jsBlokirIklan = r'''
(function(){
  if (window.__isanBlokir) return;
  window.__isanBlokir = true;

  function lapor(pesan){
    try { if (window.IsanBlokir) window.IsanBlokir.postMessage(pesan); } catch(e){}
  }

  // 1) Bunuh window.open
  window.open = function(u){ lapor('popup:' + (u||'')); return null; };

  // 2) Tangkap klik <a target="_blank">
  document.addEventListener('click', function(ev){
    var a = ev.target;
    while (a && a.tagName !== 'A') a = a.parentElement;
    if (a && a.target === '_blank') {
      ev.preventDefault(); ev.stopPropagation();
      lapor('popup:' + (a.href||''));
      return false;
    }
  }, true);

  // 3) Bersihkan script & iframe jaringan iklan
  var pola = /(doubleclick|googlesyndication|googleadservices|adservice|adsystem|adnxs|taboola|outbrain|popads|propellerads|exoclick|juicyads|trafficjunky|adsterra|hilltopads|clickadu|onclickads|mgid|revcontent|popcash|adcash)/i;

  function bersihkan(){
    document.querySelectorAll('script[src]').forEach(function(s){
      if (pola.test(s.src)) s.remove();
    });
    document.querySelectorAll('iframe[src]').forEach(function(f){
      if (pola.test(f.src)) { f.remove(); return; }
      var w = parseInt(f.getAttribute('width')||'0',10);
      var h = parseInt(f.getAttribute('height')||'0',10);
      if (w > 0 && h > 0 && w <= 320 && h <= 100) f.remove();
    });
    document.querySelectorAll('div,a').forEach(function(el){
      var s = getComputedStyle(el);
      if (s.position === 'fixed' && parseInt(s.zIndex||'0',10) > 9000) {
        var t = (el.textContent||'').toLowerCase();
        if (/sponsor|iklan|advert|klik disini|download now|install/.test(t)) el.remove();
      }
    });
  }
  bersihkan();
  setInterval(bersihkan, 1200);
})();
''';

/// ══════════════════════════════════════════════════════════════════
///  WIDGET pemutar Linux
/// ══════════════════════════════════════════════════════════════════
class PemutarLinux extends StatefulWidget {
  final String? html;
  final String? url;
  final String? userAgent;
  final IsanWebViewControllerLinux controller;

  const PemutarLinux({
    super.key,
    this.html,
    this.url,
    this.userAgent,
    required this.controller,
  });

  @override
  State<PemutarLinux> createState() => _PemutarLinuxState();
}

class _PemutarLinuxState extends State<PemutarLinux> {
  WebViewController? _ctrl;
  Widget? _widget;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      // LAPIS 1 disiapkan sebelum webview dibuat
      final scripts = InjectUserScripts()
        ..add(UserScript(jsBlokirIklan, ScriptInjectTime.LOAD_START));

      final ctrl = WebviewManager().createWebView(
        injectUserScripts: scripts,
        loading: const Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );

      await WebviewManager().initialize(userAgent: widget.userAgent);

      // ── PENTING: pastikan CEF benar-benar SIAP dulu ──
      // Kalau CEF gagal hidup (mis. mesin grafis tidak tersedia), memanggil
      // setJavaScriptChannels/setWebviewListener akan melempar
      // "LateInitializationError: Field '_browserId' has not been
      // initialized". Dulu aplikasi ikut mati karena itu. Sekarang jalur ini
      // diperiksa lebih dulu supaya kegagalan CEF hanya membuat PANEL
      // pemutar menampilkan pesan galat, bukan menjatuhkan seluruh aplikasi.
      try {
        await ctrl.ready;
      } catch (e) {
        throw StateError(
            'Mesin Chromium (CEF) gagal disiapkan di sistem ini.\n$e');
      }

      ctrl.setWebviewListener(WebviewEventsListener(
        onUrlChanged: (u) => _cekUrl(u),
        onLoadEnd: (c, u) => widget.controller._laporPageFinished(u),
        onConsoleMessage: (level, msg, src, line) {
          widget.controller.onLog?.call('[$level] $msg');
        },
        onTitleChanged: (t) => widget.controller.onLog?.call('judul: $t'),
      ));

      // LAPIS 2 — kanal JS → Dart
      ctrl.setJavaScriptChannels({
        JavascriptChannel(
          name: 'IsanBlokir',
          onMessageReceived: (m) => _dariJs(m),
        ),
      });

      final target = widget.url ??
          'data:text/html;charset=utf-8,${Uri.encodeComponent(widget.html ?? '')}';
      await ctrl.initialize(target);

      if (!mounted) return;
      setState(() {
        _ctrl = ctrl;
        _widget = ctrl.webviewWidget;
      });
      widget.controller._attachLinux(ctrl);
    } catch (e) {
      if (!mounted) return;
      // Kegagalan mesin pemutar TIDAK menjatuhkan seluruh aplikasi:
      // panel di bawah ini hanya menggantikan area video, sedangkan
      // beranda/daftar/akun tetap bisa dipakai.
      setState(() => _galat = e.toString());
    }
  }

  /// LAPIS 2 — pesan dari JavaScript
  void _dariJs(JavascriptMessage m) {
    final t = m.message;
    if (t.startsWith('popup:')) {
      widget.controller.onPopupBlocked?.call();
      widget.controller.onLog?.call('popup diblokir: ${t.substring(6)}');
    }
    try {
      _ctrl?.sendJavaScriptChannelCallBack(
          false, '{"ok":true}', m.callbackId, m.frameId);
    } catch (_) {}
  }

  /// LAPIS 3 — jaga agar tidak lari ke host luar
  void _cekUrl(String url) {
    if (url.isEmpty || !hostBoleh(url)) {
      if (url.isNotEmpty) {
        widget.controller.onRedirectBlocked?.call(Uri.parse(url).host);
        _ctrl?.loadUrl(widget.url ?? 'https://isanim.web.id');
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    WebviewManager().quit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_galat != null) {
      // Panel ramah + langkah perbaikan, BUKAN layar galat mentah.
      return PanelPemutarGagal(
        pesan: _galat,
        onCobaLagi: () {
          MesinPemutar.segarkan();
          setState(() => _galat = null);
          _mulai();
        },
      );
    }
    return _widget ??
        const Center(child: CircularProgressIndicator(color: Colors.redAccent));
  }
}

/// ── Controller Linux: ANTARMUKA SAMA dengan IsanWebViewController ──
/// supaya 6 berkas layar lain TIDAK perlu diubah.
class IsanWebViewControllerLinux {
  WebViewController? _ctrl;

  void Function(String code)? onError;
  VoidCallback? onEnded;
  void Function(String message)? onLog;
  VoidCallback? onPopupBlocked;
  void Function(String host)? onRedirectBlocked;
  void Function(String url)? onPageFinished;
  void Function(String url)? _onPageFinished;

  /// Dipakai oleh widget Linux untuk memasang callback halaman selesai.
  set pageFinished(void Function(String url)? cb) => _onPageFinished = cb;

  void _attachLinux(WebViewController c) => _ctrl = c;
  void _laporPageFinished(String url) => _onPageFinished?.call(url);

  bool get siap => _ctrl != null;

  Future<void> loadUrl(String url) async => _ctrl?.loadUrl(url);

  Future<void> loadHtml(String html) async => _ctrl?.loadUrl(
      'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');

  Future<void> runJs(String js) async => _ctrl?.executeJavaScript(js);
  Future<void> goBack() async => _ctrl?.goBack();
  Future<void> reload() async => _ctrl?.reload();
}
