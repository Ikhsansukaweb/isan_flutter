import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// ════════════════════════════════════════════════════════════════════
///  ALAT UJI MANDIRI — MEMUTAR VIDEO ASET (tanpa gerbang, tanpa login)
/// ════════════════════════════════════════════════════════════════════
///
///  Tujuan: memisahkan masalah. Alat ini TIDAK punya SharedPreferences,
///  TIDAK punya gerbang, TIDAK punya login — hanya MEMUTAR VIDEO.
///
///  Kalau video MUNCUL di sini → masalahnya di gerbang/penanda.
///  Kalau video TIDAK muncul juga → masalahnya di video_player/aset.
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HalamanUjiVideo(),
  ));
}

class HalamanUjiVideo extends StatefulWidget {
  const HalamanUjiVideo({super.key});

  @override
  State<HalamanUjiVideo> createState() => _HalamanUjiVideoState();
}

class _HalamanUjiVideoState extends State<HalamanUjiVideo> {
  VideoPlayerController? _pengendali;
  String _status = 'memulai…';
  double _posisi = 0;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      setState(() => _status = 'membuat pengendali…');
      final c = VideoPlayerController.asset('assets/video/isan_intro.mp4');
      _pengendali = c;

      setState(() => _status = 'initialize()…');
      await c.initialize();

      setState(() {
        _status = 'SIAP · durasi=${c.value.duration} · '
            'ukuran=${c.value.size} · rasio=${c.value.aspectRatio}';
      });

      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();

      c.addListener(() {
        if (!mounted) return;
        setState(() => _posisi = c.value.position.inMilliseconds / 1000);
      });
    } catch (e, s) {
      setState(() => _status = 'GAGAL: $e');
      debugPrint('[UJI VIDEO] GAGAL: $e');
      debugPrint('$s');
    }
  }

  @override
  void dispose() {
    _pengendali?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _pengendali;
    final siap = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Panel status — supaya kita LIHAT apa yang terjadi
          Container(
            width: double.infinity,
            color: Colors.blueGrey.shade900,
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              bottom: false,
              child: Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          if (siap)
            Container(
              color: Colors.white10,
              padding: const EdgeInsets.all(6),
              child: Text(
                'detik ke-${_posisi.toStringAsFixed(1)}'
                '   (angka ini HARUS naik kalau video jalan)',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: Center(
              child: siap
                  ? AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: VideoPlayer(c),
                    )
                  : const Text(
                      'menunggu video…',
                      style: TextStyle(color: Colors.white54),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
