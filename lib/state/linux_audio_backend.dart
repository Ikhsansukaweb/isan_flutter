import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LinuxAudioBackend {
  static Process? _process;
  static Process? _mprisBridgeProcess;
  static String? _currentVideoId;
  static bool _isPaused = false;

  static void play(String videoId, {VoidCallback? onEnded}) {
    if (_currentVideoId == videoId && _process != null && _isPaused) {
      _process?.kill(ProcessSignal.sigcont);
      _isPaused = false;
      print('[LINUX AUDIO BACKEND] Resume: $videoId');
      return;
    }

    if (_currentVideoId == videoId && _process != null && !_isPaused) {
      return;
    }

    stop();
    _currentVideoId = videoId;
    _isPaused = false;
    print('[LINUX AUDIO BACKEND] Buffer & Play: $videoId');

    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final tmpFile = '/tmp/isan_music_$safeId.m4a';
    final target = videoId.startsWith('ytsearch1:') ? videoId : 'https://www.youtube.com/watch?v=$videoId';

    // Spawn MPRIS bridge for Hyprland status bar
    Process.start(
      'python3',
      ['/home/ikhsan/.local/bin/isan-mpris-bridge.py', videoId, 'Isan App'],
    ).then((bridge) {
      _mprisBridgeProcess = bridge;
    }).catchError((_) {});

    Process.start(
      'bash',
      [
        '-c',
        'if [ -f "$tmpFile" ]; then exec /usr/bin/ffplay -nodisp -autoexit -loglevel quiet "$tmpFile"; else /home/linuxbrew/.linuxbrew/bin/yt-dlp --no-warnings -f "ba[ext=m4a]/ba/b" --extractor-args "youtube:player_client=android,web" -o "$tmpFile" "$target" 2>/dev/null && exec /usr/bin/ffplay -nodisp -autoexit -loglevel quiet "$tmpFile"; fi'
      ],
    ).then((p) {
      _process = p;
      p.exitCode.then((code) {
        print('[LINUX AUDIO BACKEND] exit: $code');
        if (_process == p) {
          _process = null;
          _currentVideoId = null;
          _isPaused = false;
          _mprisBridgeProcess?.kill(ProcessSignal.sigkill);
          _mprisBridgeProcess = null;
          if (code == 0) {
            onEnded?.call();
          }
        }
      });
    }).catchError((e) {
      print('[LINUX AUDIO BACKEND ERROR] $e');
      _process = null;
      _currentVideoId = null;
      _isPaused = false;
      _mprisBridgeProcess?.kill(ProcessSignal.sigkill);
      _mprisBridgeProcess = null;
    });
  }

  static void pause() {
    if (_process != null && !_isPaused) {
      _process?.kill(ProcessSignal.sigtstp);
      _isPaused = true;
      print('[LINUX AUDIO BACKEND] Paused via SIGTSTP');
    }
  }

  static void stop() {
    _currentVideoId = null;
    _isPaused = false;
    try {
      _process?.kill(ProcessSignal.sigkill);
      _process = null;
    } catch (_) {}
    try {
      _mprisBridgeProcess?.kill(ProcessSignal.sigkill);
      _mprisBridgeProcess = null;
    } catch (_) {}
    Process.runSync('bash', ['-c', 'pkill -9 -f "ffplay -nodisp" 2>/dev/null || true; pkill -9 -f "isan-mpris-bridge.py" 2>/dev/null || true']);
  }
}
