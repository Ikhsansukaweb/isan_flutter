/// Kumpulan SVG custom (dibuat baru, bukan dari icon library) untuk
/// bottom navbar ISAN. Warna pakai placeholder `{color}` yang akan
/// di-replace sesuai state aktif/tidak aktif.
class NavSvgIcons {
  static String _tpl(String inner) =>
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">$inner</svg>';

  /// Beranda — rumah dengan atap lengkung khas ISAN.
  static String home(String color) => _tpl('''
    <path d="M3.5 10.8 12 4l8.5 6.8" stroke="$color" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5.5 9.5V19a1 1 0 0 0 1 1H9.5a1 1 0 0 0 1-1v-4.2a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1V19a1 1 0 0 0 1 1H17.5a1 1 0 0 0 1-1V9.5" stroke="$color" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
  ''');

  /// Anime — clapperboard mini dengan kilau play.
  static String anime(String color) => _tpl('''
    <rect x="3.2" y="6" width="17.6" height="13" rx="2" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M3.5 9.5h17" stroke="$color" stroke-width="1.8"/>
    <path d="M7 6 9.2 9.5M12 6l2.2 3.5M17 6l1.7 2.7" stroke="$color" stroke-width="1.6" stroke-linecap="round"/>
    <path d="M10.3 12.3v3.6l3-1.8z" fill="$color"/>
  ''');

  /// Series — tumpukan tiga kotak (episode/season stack).
  static String series(String color) => _tpl('''
    <rect x="6.2" y="3.5" width="11.6" height="6.2" rx="1.4" stroke="$color" stroke-width="1.8" fill="none"/>
    <rect x="3.5" y="10.4" width="17" height="6.2" rx="1.4" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M9.6 19.6h4.8" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>
  ''');

  /// Akun — siluet user dalam lingkaran.
  static String account(String color) => _tpl('''
    <circle cx="12" cy="8.4" r="3.2" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M4.8 19.6c1-3.2 4-4.8 7.2-4.8s6.2 1.6 7.2 4.8" stroke="$color" stroke-width="1.8" fill="none" stroke-linecap="round"/>
  ''');

  /// Musik — not balok ganda khas ikon musik.
  static String music(String color) => _tpl('''
    <path d="M9.5 17.2a2.3 2.3 0 1 1 0-4.6 2.3 2.3 0 0 1 0 4.6Z" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M17.2 15.4a2.3 2.3 0 1 1 0-4.6 2.3 2.3 0 0 1 0 4.6Z" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M11.8 12.6V5.4l7.7-1.6v7.2" stroke="$color" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
  ''');

  /// Cari — kaca pembesar untuk tombol search di tengah navbar.
  static String search(String color) => _tpl('''
    <circle cx="10.6" cy="10.6" r="6.4" stroke="$color" stroke-width="2" fill="none"/>
    <path d="M15.4 15.4 20 20" stroke="$color" stroke-width="2.2" stroke-linecap="round"/>
  ''');

  /// Movie — film reel sederhana.
  static String movie(String color) => _tpl('''
    <rect x="3.5" y="4.5" width="17" height="15" rx="2" stroke="$color" stroke-width="1.8" fill="none"/>
    <path d="M3.5 8.6h17M3.5 15.4h17" stroke="$color" stroke-width="1.6"/>
    <path d="M8 4.5v4.1M8 15.4v4.1M16 4.5v4.1M16 15.4v4.1" stroke="$color" stroke-width="1.6"/>
  ''');

  /// Playlist — daftar dengan note kecil.
  static String playlist(String color) => _tpl('''
    <path d="M4 6.5h12M4 11h12M4 15.5h8" stroke="$color" stroke-width="1.8" stroke-linecap="round"/>
    <circle cx="18.3" cy="17.2" r="2.1" stroke="$color" stroke-width="1.7" fill="none"/>
    <path d="M20.2 17.2V7.8l-1.1.4" stroke="$color" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
  ''');
}
