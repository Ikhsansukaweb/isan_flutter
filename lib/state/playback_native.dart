import 'dart:io';
import 'package:flutter/services.dart';

/// Jembatan ke PlaybackService Android (notifikasi + keep-alive proses).
/// Di iOS gak ada foreground service Android, jadi method ini no-op di sana
/// (iOS pakai UIBackgroundModes=audio di Info.plist, lihat README_NATIVE.md).
class PlaybackNative {
  static const _ch = MethodChannel('isan/playback');

  /// Mulai notifikasi persistent (proses gak gampang dibunuh saat di-minimize).
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('start');
    } catch (_) {}
  }

  /// Update judul/subjudul notifikasi + status play/pause. artworkUrl
  /// opsional -- kalau diisi (untuk musik), notifikasi nampilin thumbnail
  /// lagu sebagai largeIcon (mirip player musik native).
  static Future<void> update({
    required String title,
    required String subtitle,
    required bool isPlaying,
    String? artworkUrl,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('update', {
        'title': title,
        'subtitle': subtitle,
        'isPlaying': isPlaying,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  /// Dengerin tombol "prev"/"toggle"/"next" yang dipencet dari notifikasi.
  static void setActionHandler(void Function(String action) handler) {
    if (!Platform.isAndroid) return;
    _ch.setMethodCallHandler((call) async {
      handler(call.method);
    });
  }
}
