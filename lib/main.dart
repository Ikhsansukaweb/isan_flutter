import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'state/auth_state.dart';
import 'state/music_player_state.dart';
import 'state/push_notifications.dart';
import 'screens/auth_screen.dart';
import 'widgets/app_version_gate.dart';
import 'widgets/integrity_guard.dart';
import 'widgets/global_chat_notifier.dart';
import 'widgets/auth_gate.dart';
import 'widgets/gerbang_video_intro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Wajib di-init sebelum fitur Firebase apa pun (termasuk FCM) dipakai.
  // google-services.json di android/app/ yang nentuin project Firebase
  // mana yang dipakai -- gak perlu config manual lain di sini.
  //
  // CATATAN LINUX (desktop): firebase_core TIDAK punya implementasi
  // Linux -> kalau dipanggil di Linux, app langsung crash dengan
  // "Unable to establish connection on channel ... initializeCore".
  // Jadi di Linux (dan platform non-Android/non-iOS) init Firebase
  // DILEWATI supaya app tetap bisa jalan. Android TIDAK terpengaruh:
  // di Android jalur ini tetap dijalankan PERSIS seperti sebelumnya.
  final perluFirebase = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  if (perluFirebase) {
    await Firebase.initializeApp();
  }

  final authState = AuthState();
  await authState.loadFromStorage();

  // Kalau pas startup ternyata user udah login (sesi tersimpan), langsung
  // daftarkan FCM token-nya -- gak perlu nunggu user login ulang dulu.
  if (authState.isLoggedIn && perluFirebase) {
    PushNotifications.init();
  }

  // Urutan wrapper: AppVersionGate (force update) -> IntegrityGuard
  // (anti-tamper) -> IsanApp (app sebenarnya). Keduanya render MaterialApp
  // sendiri kalau perlu block, jadi IsanApp di dalamnya gak pernah
  // ke-render sama sekali sampai kedua gate ini lolos.
  runApp(AppVersionGate(
    child: IntegrityGuard(
      child: IsanApp(authState: authState),
    ),
  ));
}

class IsanApp extends StatelessWidget {
  final AuthState authState;
  const IsanApp({super.key, required this.authState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        // Global player musik (mini player) — supaya bisa dipanggil play()
        // dari mana saja (kartu di Beranda, page Musik, dst) dan tetap
        // nempel persisten di atas bottom nav lewat RootShell.
        ChangeNotifierProvider(create: (_) => MusicPlayerState()),
      ],
      child: MaterialApp(
        title: 'ISAN',
        debugShowCheckedModeBanner: false,
        theme: buildIsanTheme(),
        routes: {
          '/auth': (_) => const AuthScreen(),
        },
        // GlobalChatNotifier butuh Overlay dari MaterialApp di atasnya buat
        // nampilin banner broadcast, makanya dibungkus di builder (bukan
        // jadi `home` langsung) supaya tetap dapet Navigator/Overlay context
        // yang valid dari MaterialApp ini.
        builder: (context, child) => GlobalChatNotifier(child: child!),
        // Wajib login dulu: AuthGate nampilin IntroScreen (+ layar
        // Login/Daftar) selama user belum login, baru pindah ke RootShell
        // (Beranda) begitu login sukses. RootShell TIDAK dipasang langsung
        // di sini lagi.
        home: const GerbangVideoIntro(anak: AuthGate()),
      ),
    );
  }
}
