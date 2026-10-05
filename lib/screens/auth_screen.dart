import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/song.dart';
import '../state/auth_state.dart';
import '../state/push_notifications.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../responsive.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _tab = 'login';
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String _error = '';

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      // Ambil AuthState SEBELUM await apa pun. Kalau dibaca setelah await
      // (async gap), analyzer menandai use_build_context_synchronously dan
      // widget bisa saja sudah di-dispose saat referensinya dipakai.
      final auth = context.read<AuthState>();
      final res = _tab == 'login'
          ? await Api.login(_email.text.trim(), _password.text)
          : await Api.register(_username.text.trim(), _email.text.trim(), _password.text);

      // Api bisa mengembalikan:
      //   * Map  -> balasan server (bisa berisi 'error')
      //   * String -> pesan galat dari sisi klien (mis. tidak bisa konek)
      if (res is! Map) {
        setState(() => _error = res?.toString() ?? 'Balasan server tidak dikenal');
        return;
      }
      if (res['error'] != null) {
        setState(() => _error = res['error'].toString());
        return;
      }
      if (res['user'] == null || res['token'] == null) {
        setState(() => _error = 'Balasan server tidak lengkap');
        return;
      }
      final user = IsanUser.fromJson(Map<String, dynamic>.from(res['user']));
      final token = res['token'].toString();
      final refreshToken = res['refreshToken']?.toString();
      await auth.setAuth(user, token, refreshToken: refreshToken);

      // ── PINDAH KE BERANDA ──
      //
      // Halaman ini dibuka dengan Navigator.push() dari IntroScreen, jadi
      // ia MENUMPUK di atas IntroScreen. Waktu AuthState berubah, AuthGate
      // sudah mengganti IntroScreen menjadi RootShell — tetapi halaman
      // login ini masih menutupinya. Akibatnya setelah login berhasil,
      // layar tetap seperti halaman login tanpa pemberitahuan apa pun,
      // dan baru berpindah ke beranda setelah tombol kembali ditekan.
      //
      // popUntil(route.isFirst) menutup SEMUA halaman yang menumpuk di
      // atas AuthGate sekaligus (termasuk halaman daftar akun kalau
      // pengguna sempat bolak-balik), sehingga yang terlihat langsung
      // beranda.
      if (mounted) {
        PushNotifications.init();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      // Tampilkan sebab sebenarnya supaya tidak bingung lagi.
      var pesan = e.toString().replaceFirst('Exception: ', '');
      if (pesan.contains('SocketException') || pesan.contains('Failed host lookup')) {
        pesan = 'Tidak bisa menghubungi server. Periksa koneksi internet.';
      } else if (pesan.contains('HandshakeException') ||
                 pesan.contains('CERTIFICATE_VERIFY_FAILED')) {
        pesan = 'Sertifikat server tidak cocok. Perlu perbarui aplikasi.';
      } else if (pesan.contains('TimeoutException')) {
        pesan = 'Server lambat merespons. Coba lagi.';
      }
      setState(() => _error = pesan);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layar login/daftar dianggap masih bagian "awal aplikasi", jadi pakai
    // background foto yang sama dengan IntroScreen (AppBg.intro).
    return AppBackground(
      image: AppBg.intro,
      overlayStrength: 0.7,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Desktop: kartu login dibatasi lebarnya (520) dan dipusatkan —
            // form selebar 1280 px terlihat aneh & sulit dibaca. Di HP
            // (lebar < 900) maxWidth = tak terbatas, jadi tampilannya
            // PERSIS seperti sebelumnya.
            padding: EdgeInsets.symmetric(
                horizontal: Layout.desktop(context) ? 40 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Layout.desktop(context) ? 520 : double.infinity,
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ISAN',
                    style: AppFonts.title(
                        size: 44,
                        weight: FontWeight.w400,
                        color: AppColors.red,
                        letterSpacing: 4,
                        shadows: [Shadow(color: AppColors.red.withValues(alpha: 0.6), blurRadius: 18)])),
                const SizedBox(height: 4),
                Text('Anime, Movie, Series & Musik', style: AppFonts.body(color: AppColors.textFaint, size: 13)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _tabBtn('login', 'Masuk'),
                            _tabBtn('register', 'Daftar'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_tab == 'register') ...[
                        _field('Username', _username, hint: 'username kamu'),
                        const SizedBox(height: 14),
                      ],
                      // Login menerima email ATAU username; daftar wajib email.
                      _tab == 'login'
                          ? _field('Email atau Username', _email,
                              hint: 'email@kamu.com atau username')
                          : _field('Email', _email, hint: 'email@kamu.com'),
                      const SizedBox(height: 14),
                      _field('Password', _password,
                          hint: '••••••••',
                          obscure: !_showPass,
                          suffix: IconButton(
                            icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility,
                                size: 18, color: AppColors.textFaint),
                            onPressed: () => setState(() => _showPass = !_showPass),
                          )),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                          ),
                          child: Text(_error, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_tab == 'login' ? 'Masuk' : 'Daftar Sekarang',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _tabBtn(String key, String label) {
    final active = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = key;
          _error = '';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : AppColors.textFaint,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textFaint, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
            filled: true,
            fillColor: AppColors.bg,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.red),
            ),
          ),
        ),
      ],
    );
  }
}
