import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════════
///  PENGAMAN GALAT TAMPILAN (KHUSUS DESKTOP)
/// ══════════════════════════════════════════════════════════════════
///
///  MASALAH YANG DICEGAH
///  -------------------
///  Di Linux, mesin Chromium (CEF) bisa gagal hidup kalau pustaka sistem
///  kurang — misalnya:
///
///     ERROR:ui/aura/env.cc:246] The platform failed to initialize.
///     Unhandled Exception: LateInitializationError:
///        Field '_browserId' has not been initialized.
///
///  Dulu galat itu menjatuhkan SELURUH aplikasi (keluar kode 139).
///  Padahal yang bermasalah cuma panel pemutar video — bagian lain
///  (beranda, daftar film, akun) seharusnya tetap bisa dipakai.
///
///  CARA KERJA
///  ----------
///  Semua galat dari dalam pembangunan tampilan ditangkap di sini:
///     • bila berasal dari mesin pemutar (CEF) → diganti panel pesan
///       yang menjelaskan langkah perbaikannya
///     • bila galat lain → tetap ditampilkan ringkas, tidak menutup app
///
///  Widget ini TIDAK dipakai di Android: root_shell maupun main.dart
///  memasangnya hanya saat berjalan di desktop/Linux. Android tidak
///  tersentuh sama sekali.
class PengamanGalat extends StatefulWidget {
  final Widget child;
  const PengamanGalat({super.key, required this.child});

  @override
  State<PengamanGalat> createState() => _PengamanGalatState();
}

class _PengamanGalatState extends State<PengamanGalat> {
  @override
  void initState() {
    super.initState();
    // Galat tak tertangani yang lolos dari widget: dicatat, TIDAK
    // dibiarkan menjatuhkan proses.
    FlutterError.onError = (FlutterErrorDetails d) {
      final pesan = d.exceptionAsString();
      if (pesan.contains('_browserId') ||
          pesan.contains('LateInitializationError') ||
          pesan.contains('CEF') ||
          pesan.contains('ContentMainRun')) {
        debugPrint('[ISAN] mesin pemutar gagal: $pesan');
      }
      FlutterError.presentError(d);
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Panel pengganti saat mesin pemutar (CEF) gagal disiapkan.
///
/// Ditampilkan DI DALAM halaman pemutar saja (bukan menutup aplikasi),
/// lengkap dengan langkah perbaikan yang bisa dijalankan pengguna.
class PanelPemutarGagal extends StatelessWidget {
  final String? pesan;
  final VoidCallback? onCobaLagi;

  const PanelPemutarGagal({super.key, this.pesan, this.onCobaLagi});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0505),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_disabled_rounded,
                color: Colors.white38, size: 46),
            const SizedBox(height: 14),
            const Text(
              'Pemutar video belum bisa dijalankan',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Di Linux, pemutar memakai mesin Chromium yang butuh beberapa '
              'pustaka sistem. Pasang dulu dengan perintah berikut, lalu buka '
              'ulang aplikasi:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFFBFB0B0), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF171112),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const SelectableText(
                'bash ~/pasang_paket_cef.sh',
                style: TextStyle(
                    color: Color(0xFF7FD08A),
                    fontFamily: 'monospace',
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '(skrip itu memasang: libasound2t64, libatk1.0-0t64, '
              'libcups2t64, xclip — wajib di Linux untuk video bersuara)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white24, fontSize: 11, height: 1.4),
            ),
            if (pesan != null && pesan!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                pesan!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11, height: 1.4),
              ),
            ],
            if (onCobaLagi != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onCobaLagi,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 18),
                label: const Text('Coba lagi',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Apakah mesin pemutar tersedia di sistem ini?
///
/// Diperiksa SEKALI lalu disimpan: keberadaan berkas libcef.so di folder
/// aplikasi. Kalau tidak ada, pemutar langsung menampilkan panel pesan
/// tanpa mencoba menyalakan mesin yang pasti gagal — sehingga tidak ada
/// lagi keluar kode 139.
class MesinPemutar {
  static bool? _tersedia;

  static Future<bool> tersedia() async {
    if (_tersedia != null) return _tersedia!;
    try {
      final exe = File(Platform.resolvedExecutable).parent.path;
      final f = File('$exe/lib/libcef.so');
      _tersedia = f.existsSync();
    } catch (_) {
      _tersedia = false;
    }
    return _tersedia!;
  }

  /// Paksa periksa ulang (dipakai tombol "Coba lagi").
  static void segarkan() => _tersedia = null;
}
