import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../screens/auth_screen.dart';

/// Helper buat nge-cek status login sebelum akses fitur yang WAJIB login
/// (player movie/series/anime, sesuai requireAuth di backend). Kalau belum
/// login, munculin dialog "Silakan login dulu" -- TIDAK langsung nembak
/// API dan ngandelin response 401 doang, supaya pengalamannya jelas dari
/// awal (user gak nunggu loading dulu baru ketauan ditolak).
class AuthGuard {
  /// Return true kalau user sudah login (boleh lanjut). Kalau belum,
  /// munculin popup dan return false -- pemanggil harus stop proses di sini.
  static bool requireLoginOr(BuildContext context) {
    final auth = context.read<AuthState>();
    if (auth.isLoggedIn) return true;
    showLoginRequiredDialog(context);
    return false;
  }

  static void showLoginRequiredDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.login, color: AppColors.red, size: 22),
            SizedBox(width: 10),
            Text('Belum Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          message ?? 'Silakan login dulu untuk menonton konten ini.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti', style: TextStyle(color: AppColors.textFaint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
