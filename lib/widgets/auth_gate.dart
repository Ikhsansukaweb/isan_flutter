import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../root_shell.dart';
import '../screens/intro_screen.dart';

/// Gerbang wajib login: dipasang sebagai `home` di MaterialApp (lihat
/// main.dart), gantiin RootShell langsung. Selama user BELUM login, yang
/// tampil cuma IntroScreen (+ AuthScreen yang di-push dari situ) -- gak ada
/// jalan lain buat "loncat" ke RootShell/Beranda.
///
/// Begitu AuthState.setAuth() dipanggil (login/daftar sukses), widget ini
/// otomatis rebuild ke RootShell lewat Provider (context.watch), lalu
/// AuthScreen yang masih ada di atasnya (hasil Navigator.push) pop sendiri
/// balik nampilin RootShell yang baru.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return auth.isLoggedIn ? const RootShell() : const IntroScreen();
  }
}
