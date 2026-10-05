import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/playback_native.dart';
import '../theme.dart';

/// Player musik — UI 100% native Flutter (artwork, judul, tombol, list lagu).
/// WebView-nya cuma "mesin audio" yang disembunyiin, isinya YouTube IFrame API.
///
/// KETEMU PENYEBAB BENERAN gak bisa play, dari `MusicFragment.kt` (versi native
/// Kotlin lama) sebagai referensi: di sana WebView-nya di-setting
/// `mediaPlaybackRequiresUserGesture = false`. Itu setting WAJIB di Android —
/// defaultnya WebView NOLAK manggil play() kalau bukan dari user-gesture ASLI
/// di dalam WebView itu sendiri. Player musik kita autoplay-nya dipanggil dari
/// Dart (lewat runJavaScript), bukan dari tap user di dalam halaman webview-nya
/// — jadi dari sudut pandang Android, itu dianggap "bukan gesture", makanya
/// video ke-load tapi audionya gak pernah jalan sama sekali.
///
/// Versi sebelumnya pakai custom native AndroidView (`isan_background_webview`)
/// yang source Kotlin-nya gak ada di project Flutter ini, jadi gak bisa
/// dipastikan/diubah dari sini. Makanya diganti total ke `webview_flutter`
/// biasa (sudah dipakai juga di AnimeEpisodeScreen) yang punya API resmi buat
/// matiin gesture requirement itu langsung dari Dart:
/// `(controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false)`.
///
/// Bonus: karena sekarang pakai `webview_flutter` biasa, ada JavaScriptChannel
/// resmi buat kirim pesan JS -> Dart (onEnded/onError/onPlaying), jadi
/// next-otomatis bisa pakai callback asli dari player, bukan tebak-tebakan
/// pakai Timer durasi lagu lagi.
class MusicWebViewScreen extends StatefulWidget {
  final String? initialQuery;
  const MusicWebViewScreen({super.key, this.initialQuery});

  @override
  State<MusicWebViewScreen> createState() => _MusicWebViewScreenState();
}

class _MusicWebViewScreenState extends State<MusicWebViewScreen> {
  late final WebViewController _webCtrl;
  bool _loading = true;
  bool _isPlaying = true;
  bool _playerReady = false;
  bool _started = false;
  int _index = 0;
  List<Song> _queue = [];

  @override
  void initState() {
    super.initState();
    PlaybackNative.start();
    PlaybackNative.setActionHandler(_onNotifAction);
    _setupWebView();
    _loadQueue();
  }

  void _setupWebView() {
    final controller = WebViewController();

    // INI FIX UTAMANYA — lihat penjelasan di komentar atas class.
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('Isan', onMessageReceived: (msg) => _onBridgeMessage(msg.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _onPlayerPageFinished()))
      ..loadHtmlString(_playerHtml, baseUrl: 'https://www.youtube.com');

    _webCtrl = controller;
  }

  Future<void> _loadQueue() async {
    try {
      final d = widget.initialQuery != null
          ? await Api.musicSearch(widget.initialQuery!)
          : await Api.musicTrending();
      final list = daftarDari(d)
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _queue = list;
        _loading = false;
      });
      // Race fix: WebView bisa selesai load duluan SEBELUM API ini kelar
      // (atau sebaliknya) — jadi dua-duanya wajib ngecek & nyalain lagu
      // pertama begitu KEDUA syarat (player ready + ada queue) terpenuhi.
      if (_playerReady && _queue.isNotEmpty && !_started) {
        _started = true;
        _loadSongAt(0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Player HTML minimal. PENTING: gak ada CSS display:none/visibility:hidden
  // di sini — itu jebakan lain yang juga bisa bikin video gak kedengeran di
  // sebagian WebView engine (karena iframe-nya ikut ke-hide pas YT.Player()
  // ganti div #player jadi <iframe id="player">). "Nyembunyiinnya" cukup
  // lewat ukuran widget Flutter-nya aja (lihat SizedBox kecil di build()).
  String get _playerHtml => '''
<!DOCTYPE html>
<html>
<head><style>html,body{margin:0;padding:0;background:#000;overflow:hidden;}</style></head>
<body>
<div id="player"></div>
<script>
  window.ytPlayer = null;
  window.pendingVideoId = null;

  var tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  document.head.appendChild(tag);

  window.onYouTubeIframeAPIReady = function() {
    var opts = {
      height: '100%', width: '100%',
      playerVars: { autoplay: 1, controls: 0, playsinline: 1, origin: 'https://www.youtube.com' },
      events: {
        onReady: function(e) {
          window.ytPlayer = e.target;
          e.target.playVideo();
          if (window.pendingVideoId) {
            e.target.loadVideoById(window.pendingVideoId);
            window.pendingVideoId = null;
          }
        },
        onStateChange: function(e) {
          if (e.data === 0) Isan.postMessage('ended');
          if (e.data === 1) Isan.postMessage('playing');
          if (e.data === 2) Isan.postMessage('paused');
        },
        onError: function(e) {
          Isan.postMessage('error:' + e.data);
        }
      }
    };
    window.ytPlayer = new YT.Player('player', opts);
  };

  function isanLoad(id){
    if (window.ytPlayer && window.ytPlayer.loadVideoById) { window.ytPlayer.loadVideoById(id); }
    else { window.pendingVideoId = id; }
  }
  function isanPlay(){ if (window.ytPlayer && window.ytPlayer.playVideo) window.ytPlayer.playVideo(); }
  function isanPause(){ if (window.ytPlayer && window.ytPlayer.pauseVideo) window.ytPlayer.pauseVideo(); }
</script>
</body>
</html>
''';

  void _onPlayerPageFinished() {
    _playerReady = true;
    if (mounted) setState(() => _loading = false);
    if (_queue.isNotEmpty && !_started) {
      _started = true;
      _loadSongAt(0);
    }
  }

  void _onBridgeMessage(String msg) {
    if (msg == 'ended') {
      _next();
    } else if (msg == 'playing') {
      if (mounted) setState(() => _isPlaying = true);
    } else if (msg == 'paused') {
      if (mounted) setState(() => _isPlaying = false);
    }
    // pesan "error:<code>" sengaja gak di-handle khusus dulu — kalau ada lagu
    // tertentu yang konsisten gagal, baru perlu nambah penanganan per kode error.
  }

  void _loadSongAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    setState(() {
      _index = index;
      _isPlaying = true;
    });
    final song = _queue[index];
    _webCtrl.runJavaScript("isanLoad('${song.videoId}');");
    PlaybackNative.update(title: song.title, subtitle: song.artist, isPlaying: true);
  }

  void _onNotifAction(String action) {
    switch (action) {
      case 'next':
        _next();
        break;
      case 'prev':
        _prev();
        break;
      case 'toggle':
        _togglePlay();
        break;
    }
  }

  void _next() {
    if (_queue.isEmpty) return;
    _loadSongAt((_index + 1) % _queue.length);
  }

  void _prev() {
    if (_queue.isEmpty) return;
    _loadSongAt((_index - 1 + _queue.length) % _queue.length);
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    _webCtrl.runJavaScript(_isPlaying ? 'isanPlay();' : 'isanPause();');
    if (_queue.isNotEmpty) {
      final song = _queue[_index];
      PlaybackNative.update(title: song.title, subtitle: song.artist, isPlaying: _isPlaying);
    }
  }

  @override
  void dispose() {
    PlaybackNative.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _queue.isNotEmpty ? _queue[_index] : null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Musik', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          // Mesin audio doang — disembunyiin lewat UKURAN widget (1x1), bukan
          // lewat CSS. Ditaruh paling bawah Stack jadi ketutup total UI lain.
          SizedBox(
            width: 1,
            height: 1,
            child: WebViewWidget(controller: _webCtrl),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.red))
          else if (_queue.isEmpty)
            const Center(child: Text('Belum ada lagu.', style: TextStyle(color: AppColors.textMuted)))
          else
            Column(
              children: [
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    current!.thumbnailUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 220,
                      color: AppColors.surfaceAlt,
                      child: const Icon(Icons.music_note, color: AppColors.border, size: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(current.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(current.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _TransportBar(isPlaying: _isPlaying, onPrev: _prev, onTogglePlay: _togglePlay, onNext: _next),
                const Divider(color: AppColors.border, height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: _queue.length,
                    itemBuilder: (ctx, i) {
                      final s = _queue[i];
                      final active = i == _index;
                      return ListTile(
                        onTap: () => _loadSongAt(i),
                        leading: Icon(Icons.music_note, color: active ? AppColors.red : AppColors.textFaint),
                        title: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: active ? AppColors.red : Colors.white,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13.5)),
                        subtitle: Text(s.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TransportBar extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPrev;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;

  const _TransportBar({
    required this.isPlaying,
    required this.onPrev,
    required this.onTogglePlay,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: onPrev,
        ),
        const SizedBox(width: 10),
        Container(
          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
          child: IconButton(
            iconSize: 34,
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            onPressed: onTogglePlay,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: onNext,
        ),
      ],
    );
  }
}