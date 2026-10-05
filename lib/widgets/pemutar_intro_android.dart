import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ════════════════════════════════════════════════════════════════════
///  PEMUTAR INTRO ISAN (ANDROID) — DECODER PERANGKAT LUNAK
/// ════════════════════════════════════════════════════════════════════
///
///  Memakai platform view "isan_intro_video" yang dibuat sendiri di
///  sisi Android (lihat android/.../PemutarIntroSoftware.kt).
///
///  KENAPA TIDAK PAKAI video_player?
///  HP Infinix X655C (MediaTek MT6765, Android 10) punya decoder
///  perangkat keras yang rusak — semua video H.264 gagal di-decode
///  (galat: "Decoder init failed: OMX.MTK.VIDEO.DECODER.AVC").
///  Paket video_player tidak menyediakan cara memaksa decoder
///  perangkat lunak, sedangkan pemutar kita sendiri bisa.
///
///  Pemutar ini HANYA untuk intro. Pemutar film/series aplikasi
///  (Hydrax/WebView) tidak disentuh.
class PemutarIntroAndroid extends StatefulWidget {
  const PemutarIntroAndroid({
    super.key,
    required this.berkasAset,
    required this.setelahSelesai,
    this.durasiPerkiraan = const Duration(seconds: 15),
  });

  /// Jalur aset video, mis. 'assets/video/isan_intro.mp4'
  final String berkasAset;

  /// Dipanggil saat intro selesai / dilewati.
  final VoidCallback setelahSelesai;

  /// Durasi perkiraan video (jaring pengaman kalau tidak ada kabar).
  final Duration durasiPerkiraan;

  @override
  State<PemutarIntroAndroid> createState() => _PemutarIntroAndroidState();
}

class _PemutarIntroAndroidState extends State<PemutarIntroAndroid> {
  static const MethodChannel _kanal = MethodChannel('isan/intro_video_0');

  // Nama view type yang didaftarkan di MainActivity.kt
  static const String _jenisView = 'isan_intro_video';

  Timer? _pengaman;
  bool _selesai = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[INTRO ANDROID] membuka pemutar untuk ${widget.berkasAset}');

    // Jaring pengaman: kalau tidak ada kabar sama sekali, tetap lanjut.
    _pengaman = Timer(
      widget.durasiPerkiraan + const Duration(seconds: 3),
      _selesaiKan,
    );
  }

  void _selesaiKan() {
    if (_selesai || !mounted) return;
    _selesai = true;
    _pengaman?.cancel();
    debugPrint('[INTRO ANDROID] selesai — lanjut ke aplikasi');
    widget.setelahSelesai();
  }

  @override
  void dispose() {
    _pengaman?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AndroidView = platform view milik kita di sisi Android.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AndroidView(
              viewType: _jenisView,
              creationParams: <String, dynamic>{
                'aset': widget.berkasAset,
                'paksaSoftware': true,
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (id) {
                debugPrint('[INTRO ANDROID] platform view dibuat, id=$id');
                // Perintah putar dikirim setelah view siap.
                _kanal.invokeMethod('putar', <String, dynamic>{
                  'aset': widget.berkasAset,
                  'paksaSoftware': true,
                }).catchError((Object e) {
                  debugPrint('[INTRO ANDROID] gagal kirim perintah putar: $e');
                });
              },
            ),
          ),
          // Tombol LEWATI
          Positioned(
            right: 20,
            bottom: 32,
            child: TextButton(
              onPressed: _selesaiKan,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('LEWATI', style: TextStyle(letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pilih pemutar yang tepat sesuai platform.
///
/// Di Android → PemutarIntroAndroid (decoder perangkat lunak).
/// Di platform lain → null (pemanggil memakai jalur lain).
bool get introAndroidTersedia => Platform.isAndroid;
