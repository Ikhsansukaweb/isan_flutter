import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../state/music_player_state.dart';
import '../state/playback_native.dart';
import '../theme.dart';
import 'isan_background_webview.dart';

/// Mini player musik persisten di RootShell, di atas bottom nav bar.
/// Dikontrol lewat MusicPlayerState (global). Tap pada bar membuka
/// FullPlayerSheet — full player dengan detail lagu, progress bar,
/// dan kontrol lengkap (prev/play/next/shuffle).
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static const String _webBase = 'https://isanim.web.id';
  static const String _desktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  final _controller = IsanWebViewController();
  bool _playerReady = false;
  String? _loadedVideoId;
  int _loadedToken = -1;
  bool _nativeStarted = false;
  MusicPlayerState? _player;

  @override
  void initState() {
    super.initState();
    _controller.onEnded = () {
      // ignore: avoid_print
      print('[ISAN MUSIC] onEnded received in Dart, calling next()');
      _player?.next();
    };
    _controller.onLog = (msg) {
      // ignore: avoid_print
      print('[ISAN MUSIC] $msg');
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = context.read<MusicPlayerState>();
    if (_player != player) {
      _player?.removeListener(_handlePlayerChange);
      _player = player;
      _player!.addListener(_handlePlayerChange);
    }
  }

  void _handlePlayerChange() {
    final player = _player;
    if (player == null) return;
    _syncWithState(player);
    if (mounted) setState(() {});
  }

  String get _playerHtml => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>body { margin:0; padding:0; background:#000; overflow:hidden; } #player { width:100%; height:100%; position:absolute; }</style>
<script>
  (function() {
    Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: true });
    Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
    var origAdd = document.addEventListener.bind(document);
    document.addEventListener = function(type, listener, options) {
      if (type === 'visibilitychange') { return; }
      return origAdd(type, listener, options);
    };
  })();
</script>
</head>
<body>
<div id="player"></div>
<script>
  var tag = document.createElement('script');
  tag.src = "https://www.youtube.com/iframe_api";
  document.head.appendChild(tag);

  window.ytPlayer = null;
  window.pendingVideoId = null;

  window.onYouTubeIframeAPIReady = function() {
    window.ytPlayer = new YT.Player('player', {
      height: '100%',
      width: '100%',
      playerVars: {
        'autoplay': 1,
        'controls': 0,
        'enablejsapi': 1,
        'origin': '$_webBase',
        'widget_refer': '$_webBase'
      },
      events: {
        'onReady': function(event) {
          if (window.pendingVideoId) {
            event.target.loadVideoById(window.pendingVideoId);
            window.pendingVideoId = null;
          }
        },
        'onStateChange': function(event) {
          IsanBridge.log('onStateChange data=' + event.data);
          if (event.data === YT.PlayerState.ENDED) {
            IsanBridge.log('ENDED detected, calling onEnded()');
            IsanBridge.onEnded();
          }
        },
        'onError': function(event) {
          IsanBridge.onError('' + event.data);
        }
      }
    });
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

  void _onPlayerPageFinished(String _) {
    _playerReady = true;
    if (_player != null) _syncWithState(_player!);
  }

  void _onNotifAction(String action) {
    // ignore: avoid_print
    print('[ISAN_NOTIF] Dart received action="$action"');
    final player = _player;
    if (player == null) return;
    switch (action) {
      case 'next':
        player.next();
        break;
      case 'prev':
        player.prev();
        break;
      case 'toggle':
        player.togglePlaying();
        break;
    }
  }

  void _syncWithState(MusicPlayerState player) {
    final song = player.current;
    if (song == null || !_playerReady) return;

    if (_loadedVideoId != song.videoId || _loadedToken != player.reloadToken) {
      _loadedVideoId = song.videoId;
      _loadedToken = player.reloadToken;
      // ignore: avoid_print
      print('[ISAN MUSIC] Dart calling isanLoad with videoId="${song.videoId}" (title="${song.title}")');
      _controller.runJs("isanLoad('${song.videoId}');");
      if (!_nativeStarted) {
        _nativeStarted = true;
        PlaybackNative.start();
        PlaybackNative.setActionHandler(_onNotifAction);
      }
      PlaybackNative.update(
        title: song.title,
        subtitle: song.artist,
        isPlaying: true,
        artworkUrl: song.thumbnailUrl,
      );
    } else {
      _controller.runJs(player.isPlaying ? 'isanPlay();' : 'isanPause();');
      PlaybackNative.update(
        title: song.title,
        subtitle: song.artist,
        isPlaying: player.isPlaying,
        artworkUrl: song.thumbnailUrl,
      );
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_handlePlayerChange);
    if (_nativeStarted) PlaybackNative.stop();
    super.dispose();
  }

  void _openFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: _player!,
        child: const _FullPlayerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _player ?? context.watch<MusicPlayerState>();
    final song = player.current;

    final webview = song == null
        ? const SizedBox.shrink()
        : SizedBox(
            width: 1,
            height: 1,
            child: IsanBackgroundWebView(
              html: _playerHtml,
              baseUrl: _webBase,
              userAgent: _desktopUserAgent,
              controller: _controller,
              onPageFinished: _onPlayerPageFinished,
            ),
          );

    if (!player.visible || song == null) {
      return webview;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        webview,
        GestureDetector(
          onTap: () => _openFullPlayer(context),
          child: Container(
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
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    song.thumbnailUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      color: AppColors.surfaceAlt,
                      child: const Icon(Icons.music_note, color: AppColors.border, size: 18),
                    ),
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
                // Tombol prev
                if (player.hasPrev)
                  GestureDetector(
                    onTap: () {
                      player.prev();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                // Tombol play/pause — intercept tap biar gak buka full player
                GestureDetector(
                  onTap: () => player.togglePlaying(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: AppColors.red,
                      size: 30,
                    ),
                  ),
                ),
                // Tombol next
                if (player.hasNext)
                  GestureDetector(
                    onTap: () => player.next(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                // Tombol close
                GestureDetector(
                  onTap: () => player.close(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.close, color: AppColors.textFaint, size: 20),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full player sheet — muncul dari bawah saat mini bar di-tap.
/// Menampilkan: thumbnail besar, judul, artist, queue info,
/// progress bar (simulasi), kontrol prev/play/next, tombol shuffle & repeat.
class _FullPlayerSheet extends StatefulWidget {
  const _FullPlayerSheet();

  @override
  State<_FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends State<_FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _shuffleOn = false;
  bool _repeatOn = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerState>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle bar ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header (playlist name + close) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SEDANG DIPUTAR', style: TextStyle(color: AppColors.textFaint, fontSize: 10, letterSpacing: 1.2)),
                    if (player.queue.isNotEmpty)
                      Text(
                        '${player.index + 1} / ${player.queue.length}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // ── Thumbnail besar ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Center(
                child: ScaleTransition(
                  scale: player.isPlaying ? _pulseCtrl : const AlwaysStoppedAnimation(0.95),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.music_note, color: AppColors.border, size: 60),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Info lagu ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Durasi lagu
                if (song.durationSeconds > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _formatDuration(song.durationSeconds),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Progress bar (simulasi statis — backend tidak expose posisi real-time) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.red,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: Colors.white,
                    overlayColor: AppColors.red.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: 0.0,
                    onChanged: (_) {}, // read-only; posisi real dikelola JS WebView
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0:00', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                    Text('Live', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Kontrol utama ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: _shuffleOn ? AppColors.red : AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _shuffleOn = !_shuffleOn),
                ),
                // Prev
                IconButton(
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: player.hasPrev ? Colors.white : AppColors.border,
                    size: 36,
                  ),
                  onPressed: player.hasPrev ? player.prev : null,
                ),
                // Play / Pause besar
                GestureDetector(
                  onTap: player.togglePlaying,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                // Next
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: player.hasNext ? Colors.white : AppColors.border,
                    size: 36,
                  ),
                  onPressed: player.hasNext ? player.next : null,
                ),
                // Repeat
                IconButton(
                  icon: Icon(
                    Icons.repeat_rounded,
                    color: _repeatOn ? AppColors.red : AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _repeatOn = !_repeatOn),
                ),
              ],
            ),
          ),

          // ── Queue preview ──
          if (player.queue.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BERIKUTNYA', style: TextStyle(color: AppColors.textFaint, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  if (player.hasNext) ...[
                    _QueueNextItem(song: player.queue[player.index + 1]),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Item lagu berikutnya di queue preview.
class _QueueNextItem extends StatelessWidget {
  final Song song;
  const _QueueNextItem({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              song.thumbnailUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 36,
                height: 36,
                color: AppColors.surfaceAlt,
                child: const Icon(Icons.music_note, color: AppColors.border, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.queue_music_rounded, color: AppColors.textFaint, size: 18),
        ],
      ),
    );
  }
}
