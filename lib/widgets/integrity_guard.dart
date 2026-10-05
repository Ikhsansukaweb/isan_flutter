import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../theme.dart';

/// Anti-tamper sederhana: ambil hash SHA-256 sertifikat signing APK yang
/// SEDANG jalan di device ini (lewat MainActivity.kt getSignatureSha256()),
/// kirim ke backend buat dicocokkan sama daftar signature yang valid
/// (di-set admin lewat Telegram bot /setsignature).
///
/// PENTING buat dipahami dengan jujur: ini BUKAN bikin app "gak bisa
/// di-crack" secara mutlak -- gak ada cara bikin APK Android benar-benar
/// anti-crack 100%, orang yang punya skill reverse-engineering tetap bisa
/// modifikasi MethodChannel ini sendiri (misal hook getSignatureSha256()
/// buat selalu return hash yang valid). Yang ini lakukan adalah NAMBAH
/// EFFORT yang dibutuhkan buat crack app -- dari "sekedar re-sign APK"
/// jadi "harus reverse-engineer & patch kode native juga". Itu cukup buat
/// nyegah modifikasi kasar (re-sign, repack manual) yang paling umum
/// dipakai orang awam buat "bajak" app.
///
/// Kalau signature gak valid, app SENGAJA dirusak (bukan cuma dikasih
/// dialog peringatan yang bisa di-skip) -- sesuai permintaan "kalau
/// dipaksa, isi dalamnya rusak gak bisa dipake".
class IntegrityGuard extends StatefulWidget {
  final Widget child;
  const IntegrityGuard({super.key, required this.child});

  @override
  State<IntegrityGuard> createState() => _IntegrityGuardState();
}

class _IntegrityGuardState extends State<IntegrityGuard> {
  static const _channel = MethodChannel('isan/integrity');

  bool _checked = false;
  bool _tampered = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Cuma relevan di Android (signing certificate check ini Android-
    // specific). Di platform lain, skip aja.
    if (!Platform.isAndroid) {
      setState(() => _checked = true);
      return;
    }
    try {
      final sig = await _channel.invokeMethod<String>('getSignatureSha256');
      // ignore: avoid_print
      print('[ISAN INTEGRITY] sig dikirim app = "$sig"');
      if (sig == null || sig.isEmpty) {
        // Gagal ambil signature sama sekali -- anggap mencurigakan juga,
        // tapi jangan langsung block kalau cuma masalah API level lama.
        setState(() => _checked = true);
        return;
      }
      final res = await Api.appIntegrity(sig);
      // ignore: avoid_print
      print('[ISAN INTEGRITY] response backend = $res');
      final valid = res['valid'] != false;
      setState(() {
        _tampered = !valid;
        _checked = true;
      });
    } catch (_) {
      // Gagal connect ke backend (offline) -- jangan block, itu beda
      // kasus dari "signature beneran gak valid".
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const SizedBox.shrink();
    }

    if (_tampered) {
      // "Isi dalamnya rusak" -- app berhenti total, gak ada cara lanjut,
      // gak ada tombol apa pun. Pesan yang ditampilkan sengaja generik
      // (bukan "signature tidak valid") biar gak ngasih hint teknis ke
      // orang yang nyoba modifikasi APK soal MENGAPA app-nya berhenti.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Aplikasi tidak dapat dijalankan',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Silakan unduh ulang ISAN dari sumber resmi.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
