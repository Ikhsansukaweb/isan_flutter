import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/semua_film_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/music_list_screen.dart';
import 'screens/account_screen.dart';
import 'screens/search_screen.dart';
import 'screens/history_screen.dart';
import 'responsive.dart';
import 'theme.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/isan_top_bar.dart';
import 'widgets/mini_player.dart';
import 'widgets/sidebar_kanan.dart';
import 'widgets/app_background.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // 0 Beranda, 1 Film (semua + filter), 2 Series, 3 Anime, 4 Musik, 5 Akun
  // ── SUSUNAN NAVBAR ─────────────────────────────────────────────
  //
  // Atas permintaan pemilik aplikasi:
  //   • Halaman Series & Anime DIHAPUS dari navbar. Keduanya sekarang
  //     dijangkau lewat FILTER di halaman Film (jenis: Film / Series /
  //     Anime / Drakor) — jadi tidak perlu tab sendiri.
  //   • Tempatnya dipakai PlaylistScreen, yang lebih sering dibuka.
  //
  // Urutan: Beranda · Film · Playlist · Musik · Akun
  final List<Widget> _tabs = const [
    HomeScreen(),
    SemuaFilmScreen(),   // 1 — semua film + filter jenis/genre/negara/tahun
    PlaylistScreen(),    // 2 — Playlist (dulu tab Series)
    MusicListScreen(),   // 3
    AccountScreen(),     // 4 — Akun
  ];

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  void _openAccount() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  // Popup navigasi cepat, dibuka lewat tombol menu (☰) di top bar.
  // Isinya shortcut ke semua tab utama + Riwayat Tontonan & Akun, biar
  // gak harus scroll bottom nav / pindah tab dulu.
  void _openMenuPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                _menuTile(ctx, Icons.home_rounded, 'Beranda', AppColors.red, () => _jumpTab(0)),
                // 'Film' membuka halaman Film + filter. Dari situ Series,
                // Anime, dan Drakor dipilih lewat filter — jadi tidak perlu
                // baris menu sendiri-sendiri lagi.
                _menuTile(ctx, Icons.movie_rounded, 'Film', AppColors.purple, () => _jumpTab(1)),
                _menuTile(ctx, Icons.playlist_play_rounded, 'Playlist', AppColors.blue, () => _jumpTab(2)),
                _menuTile(ctx, Icons.music_note_rounded, 'Musik', AppColors.blue, () => _jumpTab(3)),
                _menuTile(ctx, Icons.person_rounded, 'Akun', AppColors.textMuted, () => _jumpTab(4)),
                const Divider(color: AppColors.border, height: 20),
                _menuTile(ctx, Icons.history_rounded, 'Riwayat Tontonan', AppColors.textMuted, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                }),
                _menuTile(ctx, Icons.person_rounded, 'Akun', AppColors.textMuted, () {
                  Navigator.of(ctx).pop();
                  _openAccount();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _jumpTab(int i) {
    Navigator.of(context).pop();
    setState(() => _index = i);
  }

  Widget _menuTile(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Background foto (AppBg.main) dipasang SEKALI di sini, di belakang
    // IndexedStack -- otomatis nutupin semua tab (Beranda, Anime, Movie,
    // Series, Musik, Playlist) tanpa perlu background sendiri-sendiri per
    // tab. Tiap layar tab wajib backgroundColor: Colors.transparent biar
    // foto ini keliatan tembus.
    final layout = Layout.of(context);

    // ══════════════════════════════════════════════════════════════
    //  TAMPILAN DESKTOP (lebar >= 900) — SIDEBAR KANAN
    //  ──────────────────────────────────────────────────────────────
    //  Di HP lebar layar selalu < 900, jadi blok ini TIDAK PERNAH
    //  dijalankan di Android: Android tetap memakai tata letak di
    //  bawahnya (top bar + floating bottom navbar) PERSIS seperti
    //  sebelumnya.
    // ══════════════════════════════════════════════════════════════
    if (layout.isDesktop) {
      return AppBackground(
        image: AppBg.main,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // ── Isi (kiri) ──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IndexedStack(index: _index, children: _tabs),
                    // Mini player tetap di bawah-tengah, tapi tidak
                    // sampai menutupi sidebar.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MiniPlayer(),
                    ),
                  ],
                ),
              ),
              // ── Navigasi (kanan) ──
              IsanSidebarKanan(
                currentIndex: _index,
                lebar: layout.lebarSidebar,
                onTap: (i) => setState(() => _index = i),
                onSearchTap: _openSearch,
                onAccountTap: _openAccount,
                onHistoryTap: _openHistory,
              ),
            ],
          ),
        ),
      );
    }

    // ══════════════════════════════════════════════════════════════
    //  TAMPILAN HP / ANDROID — TIDAK DIUBAH SAMA SEKALI
    // ══════════════════════════════════════════════════════════════
    return AppBackground(
      image: AppBg.main,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: IsanTopBar(
        isHome: _index == 0,
        onSearchTap: _openSearch,
        onAccountTap: _openAccount,
        onMenuTap: _openMenuPopup,
      ),
      // Navbar & mini player DITARUH DI ATAS konten lewat Stack (bukan lewat
      // slot bottomNavigationBar), supaya konten (list/poster/dll) beneran
      // nge-scroll sampai ke belakang navbar. Area margin transparan di
      // sekitar pill jadi nunjukin konten asli di baliknya, bukan cuma
      // warna solid kosong -- sebelumnya pakai bottomNavigationBar+extendBody
      // gak mempan karena tiap tab (HomeScreen dkk) punya Scaffold sendiri
      // yang nutup areanya sendiri dengan warna solid.
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: _index, children: _tabs),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                IsanBottomNavBar(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
