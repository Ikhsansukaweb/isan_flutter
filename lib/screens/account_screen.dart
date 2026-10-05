import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/instagram_button.dart';
import 'auth_screen.dart';
import 'playlist_screen.dart';
import 'history_screen.dart';
import 'favorit_screen.dart';
import 'about_isan_screen.dart';
import '../responsive.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    // Halaman Akun WAJIB pakai background foto ke-3 (AppBg.account), beda
    // dari background utama app -- sesuai request.
    return AppBackground(
      image: AppBg.account,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Akun', style: AppFonts.title(size: 20, color: Colors.white, weight: FontWeight.w400)),
        ),
        body: auth.isLoggedIn ? _LoggedInView(auth: auth) : const _LoggedOutView(),
      ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Layout.desktop(context) ? 56 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.person_outline, size: 38, color: AppColors.textFaint),
            ),
            const SizedBox(height: 18),
            const Text('Kamu belum masuk',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Masuk untuk menyimpan playlist dan preferensi kamu.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Masuk / Daftar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInView extends StatelessWidget {
  final AuthState auth;
  const _LoggedInView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    return ListView(
      padding: EdgeInsets.all(Layout.desktop(context) ? 30 : 20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.red,
                child: Text(
                  user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(user.username,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(user.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _menuItem(context, Icons.playlist_play, 'Playlist Saya',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlaylistScreen()))),
        _menuItem(context, Icons.history, 'Riwayat Tontonan',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()))),
        // Favorit ditaruh tepat setelah Riwayat karena keduanya sama-sama
        // daftar judul milik pengguna; bedanya Riwayat terisi sendiri
        // saat menonton, sedangkan Favorit hanya kalau disengaja.
        _menuItem(context, Icons.favorite_border_rounded, 'Favorit',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritScreen()))),
        _menuItem(context, Icons.info_outline, 'Tentang ISAN',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutIsanScreen()))),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => auth.logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ikuti ISAN di ', style: AppFonts.body(size: 11.5, color: AppColors.textFaint)),
            const InstagramButton(size: 32),
          ],
        ),
      ],
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.textMuted, size: 20),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 18),
      ),
    );
  }
}
