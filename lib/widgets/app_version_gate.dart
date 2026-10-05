import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../theme.dart';

/// Bungkus root app dengan widget ini buat force-update. Cek versi ke
/// backend (/api/app/version) tiap startup -- kalau versi app SEKARANG di
/// bawah minVersion yang di-set admin lewat Telegram bot (/setversion),
/// tampilan diganti TOTAL jadi dialog "wajib update" yang gak ada tombol
/// close/back sama sekali (PopScope nahan back gesture juga), jadi app
/// gak bisa dipakai sampai user update dulu.
class AppVersionGate extends StatefulWidget {
  final Widget child;
  const AppVersionGate({super.key, required this.child});

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  bool _checked = false;
  bool _mustUpdate = false;
  String _updateUrl = '';
  String _message = '';
  String _latestVersion = '';
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      final d = await Api.appVersion();
      final minVersion = (d['minVersion'] ?? '0.0.0').toString();
      _latestVersion = (d['latestVersion'] ?? _currentVersion).toString();
      _updateUrl = (d['updateUrl'] ?? '').toString();
      _message = (d['message'] ?? '').toString();

      if (_isOlder(_currentVersion, minVersion)) {
        setState(() {
          _mustUpdate = true;
          _checked = true;
        });
        return;
      }
    } catch (_) {
      // Gagal cek versi (misal offline) -- biarkan app tetap jalan,
      // jangan block user cuma karena gak bisa connect ke server version
      // check (itu beda kasus dari "app emang ketinggalan versi").
    }
    setState(() => _checked = true);
  }

  /// Bandingkan versi semver sederhana (major.minor.patch). Return true
  /// kalau [a] lebih lama/kecil dari [b].
  bool _isOlder(String a, String b) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va < vb;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: CircularProgressIndicator(color: AppColors.red)),
        ),
      );
    }

    if (_mustUpdate) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: PopScope(
          // Tahan tombol back fisik/gesture -- gak boleh keluar dari
          // halaman force-update ini sama sekali.
          canPop: false,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update_rounded, size: 72, color: AppColors.red),
                    const SizedBox(height: 24),
                    const Text(
                      'Update Tersedia',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message.isNotEmpty
                          ? _message
                          : 'Versi aplikasi kamu ($_currentVersion) sudah tidak didukung. '
                              'Update ke versi $_latestVersion untuk melanjutkan.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          if (_updateUrl.isNotEmpty) {
                            final uri = Uri.tryParse(_updateUrl);
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text('Update Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() => _checked = false);
                        _check();
                      },
                      child: const Text('Cek lagi', style: TextStyle(color: AppColors.textFaint)),
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
