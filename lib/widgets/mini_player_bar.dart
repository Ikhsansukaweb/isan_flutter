import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../state/music_player_state.dart';
import '../theme.dart';

/// Mini player musik yang nempel persisten di atas bottom nav bar,
/// mirip status bar "now playing" Spotify. Audio diputar lewat
/// YouTube IFrame Player API (jadi tetap di dalam aplikasi, bukan
/// pindah ke app YouTube).
class MiniPlayerBar extends StatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar> {
  WebViewController? _webCtrl;
  String? _loadedVideoId;
  int _loadedToken = -1;

  void _ensureWebView(MusicPlayerState player) {
    final song = player.current;
    if (song == null) return;
    if (_loadedVideoId == song.videoId && _loadedToken == player.reloadToken) return;
    _loadedVideoId = song.videoId;
    _loadedToken = player.reloadToken;

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;background:#000;overflow:hidden;}</style>
</head>
<body>
<div id="player"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
  var player;
  function onYouTubeIframeAPIReady() {
    player = new YT.Player('player', {
      height: '100%',
      width: '100%',
      videoId: '${song.videoId}',
      playerVars: { autoplay: 1, playsinline: 1, controls: 0, rel: 0 },
      events: { 'onReady': function(e){ e.target.playVideo(); } }
    });
  }
  function isanPlay(){ if (player && player.playVideo) player.playVideo(); }
  function isanPause(){ if (player && player.pauseVideo) player.pauseVideo(); }
</script>
</body>
</html>
''';

    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();
    final song = player.current;
    if (!player.visible || song == null) return const SizedBox.shrink();

    _ensureWebView(player);

    // Sinkronkan play/pause ke player JS tiap kali state berubah.
    final ctrl = _webCtrl;
    if (ctrl != null) {
      ctrl.runJavaScript(player.isPlaying ? 'isanPlay();' : 'isanPause();');
    }

    return Container(
      height: 58,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Frame iframe YouTube kecil — ini "iframe" pemutar musiknya,
          // ditampilkan mini di pojok kiri bar (seperti album art Spotify).
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 42,
              child: ctrl != null
                  ? WebViewWidget(controller: ctrl)
                  : Container(color: AppColors.surfaceAlt),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: AppColors.red, size: 30),
            onPressed: () => player.togglePlaying(),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textFaint, size: 20),
            onPressed: () => player.close(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
