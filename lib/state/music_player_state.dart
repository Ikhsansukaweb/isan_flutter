import 'package:flutter/material.dart';
import '../models/song.dart';

/// State global untuk mini player musik (mirip status bar Spotify).
/// Song diputar lewat YouTube IFrame embed (background webview native),
/// jadi bisa dipanggil play() dari kartu musik manapun (Beranda, page
/// Musik, dst) tanpa harus pindah halaman — UI mini player-nya nempel
/// persisten di RootShell, di atas bottom nav bar.
class MusicPlayerState extends ChangeNotifier {
  Song? _current;
  bool _isPlaying = false;
  bool _visible = false;
  int _reloadToken = 0;
  List<Song> _queue = [];
  int _index = 0;

  Song? get current => _current;
  bool get isPlaying => _isPlaying;
  bool get visible => _visible;
  int get reloadToken => _reloadToken;
  List<Song> get queue => _queue;
  int get index => _index;
  bool get hasNext => _queue.isNotEmpty && _index < _queue.length - 1;
  bool get hasPrev => _queue.isNotEmpty && _index > 0;

  /// Putar satu lagu langsung, opsional sambil set antrian (misal daftar
  /// trending/search saat ini) supaya tombol next/prev di mini player jalan.
  void play(Song song, {List<Song>? queue}) {
    final isSame = _current?.videoId == song.videoId;
    _current = song;
    _isPlaying = true;
    _visible = true;
    if (queue != null && queue.isNotEmpty) {
      _queue = queue;
      _index = _queue.indexWhere((s) => s.videoId == song.videoId);
      if (_index < 0) _index = 0;
    } else if (_queue.isEmpty || !_queue.any((s) => s.videoId == song.videoId)) {
      _queue = [song];
      _index = 0;
    } else {
      _index = _queue.indexWhere((s) => s.videoId == song.videoId);
    }
    if (!isSame) _reloadToken++; // paksa WebView reload embed baru
    notifyListeners();
  }

  void next() {
    if (!hasNext) return;
    play(_queue[_index + 1], queue: _queue);
  }

  void prev() {
    if (!hasPrev) return;
    play(_queue[_index - 1], queue: _queue);
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void togglePlaying() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void close() {
    _current = null;
    _isPlaying = false;
    _visible = false;
    notifyListeners();
  }
}
