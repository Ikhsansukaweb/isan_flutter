import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';
import '../responsive.dart';

/// Halaman "SEMUA FILM" — pengganti tiga halaman lama
/// (Anime / Movie / Series) yang terpisah.
///
/// Alasannya: sumber datanya SATU (TMDB), jadi memisahkan halaman per
/// jenis cuma memaksa pengguna menebak dulu filmnya jenis apa sebelum
/// mencari. Di sini semuanya bisa dicari sekaligus, lalu DISARING sesuai
/// kebutuhan.
///
/// Filter yang tersedia (semua dari TMDB, bukan daftar karangan sendiri):
///   • Jenis   — Film / Series / Anime / Drakor
///   • Genre   — daftar genre resmi TMDB untuk jenis yang sedang dipilih
///   • Negara  — kode negara asal produksi
///   • Tahun   — 30 tahun terakhir
///   • Urutan  — populer / rating tertinggi / terbaru / terlaris
///
/// Catatan penting soal genre: TMDB punya daftar genre BERBEDA untuk film
/// dan serial. Contohnya "Percintaan" (10749) HANYA ada di film; serial
/// tidak punya. Backend memetakan sendiri permintaan yang tidak ada ke
/// padanannya, jadi daftar di sini cukup memakai yang dikirim backend.
class SemuaFilmScreen extends StatefulWidget {
  const SemuaFilmScreen({super.key});

  @override
  State<SemuaFilmScreen> createState() => _SemuaFilmScreenState();
}

class _SemuaFilmScreenState extends State<SemuaFilmScreen> {
  // ── Nilai filter yang sedang aktif ──
  String _jenis = 'movie';
  String? _genre;
  String? _negara;
  String? _tahun;
  String _urut = 'popularity.desc';

  // ── Daftar pilihan filter (dari backend) ──
  List<Map<String, dynamic>> _pilihanNegara = const [];
  Map<String, List<Map<String, dynamic>>> _pilihanGenre = const {};
  List<Map<String, dynamic>> _pilihanUrut = const [];
  List<String> _pilihanTahun = const [];
  bool _filterSiap = false;

  // ── Hasil ──
  List<Map<String, dynamic>> _hasil = const [];
  bool _loading = true;
  int _halaman = 1;
  int _totalHalaman = 1;
  final _scroll = ScrollController();

  static const _jenisPilihan = [
    ('movie', 'Film'),
    ('tv', 'Series'),
    ('anime', 'Anime'),
    ('drakor', 'Drakor'),
  ];

  @override
  void initState() {
    super.initState();
    _muatFilter();
    _muat();
    _scroll.addListener(_diUjung);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Muat daftar pilihan filter sekali saja.
  Future<void> _muatFilter() async {
    try {
      final d = await Api.get('/api/semua/filter');
      if (d is! Map) return;
      final negara = (d['negara'] as List?) ?? const [];
      final genre = d['genre'];
      final urut = (d['urut'] as List?) ?? const [];
      final tahun = (d['tahun'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _pilihanNegara = negara
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (genre is Map) {
          _pilihanGenre = {
            'movie': ((genre['film'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
            'tv': ((genre['tv'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          };
        }
        _pilihanUrut = urut
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _pilihanTahun = tahun.map((e) => e.toString()).toList();
        _filterSiap = true;
      });
    } catch (_) {
      if (mounted) setState(() => _filterSiap = true);
    }
  }

  /// Genre yang berlaku untuk jenis yang sedang dipilih.
  ///
  /// Anime & drakor memakai daftar genre SERIAL, karena keduanya data TV
  /// di TMDB. Membiarkannya memakai daftar film akan memunculkan genre
  /// yang tidak ada isinya (mis. anime "Percintaan" yang selalu kosong).
  List<Map<String, dynamic>> get _genreUntukJenis {
    if (_jenis == 'movie') return _pilihanGenre['movie'] ?? const [];
    return _pilihanGenre['tv'] ?? const [];
  }

  Future<void> _muat({bool tambah = false}) async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{
        'jenis': _jenis,
        'urut': _urut,
        'halaman': '$_halaman',
      };
      if (_genre != null && _genre!.isNotEmpty) params['genre'] = _genre!;
      if (_negara != null && _negara!.isNotEmpty) params['negara'] = _negara!;
      if (_tahun != null && _tahun!.isNotEmpty) params['tahun'] = _tahun!;

      final d = await Api.get('/api/semua', params);
      final daftar = bacaDaftar(d)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final total = (d is Map ? d['totalHalaman'] : null);
      if (!mounted) return;
      setState(() {
        _hasil = tambah ? [..._hasil, ...daftar] : daftar;
        _totalHalaman = total is int ? total : 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Muat halaman berikutnya saat daftar digulir sampai bawah.
  void _diUjung() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        !_loading &&
        _halaman < _totalHalaman) {
      _halaman += 1;
      _muat(tambah: true);
    }
  }

  void _ubahFilter(VoidCallback ubah) {
    setState(() {
      ubah();
      _halaman = 1;
      _hasil = const [];
    });
    _muat();
  }

  void _buka(Map<String, dynamic> x) {
    final id = (x['tmdbId'] ?? x['id'] ?? '').toString();
    if (id.isEmpty) return;
    // Halaman tujuan ditentukan oleh JENIS item, bukan oleh filter yang
    // sedang dipilih. Dulu di sini memakai `_jenis` (filter), sehingga
    // saat filter 'movie' tetapi yang ditekan item serial, aplikasi
    // membuka halaman FILM dengan id serial — hasilnya "kartu X ditekan,
    // yang terbuka Y" alias error.
    final jenis = (x['jenis'] ?? _jenis).toString();
    if (jenis == 'movie') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => MovieDetailScreen(url: id)));
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(slug: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── JARAK KE TOP BAR ────────────────────────────────────────
          //
          // Dinaikkan dari 76 menjadi 104 px supaya baris filter turun
          // dan tidak bertabrakan dengan logo ISAN di top bar. Logo itu
          // tinggi, jadi 76 px masih terasa mepet.
          const SizedBox(height: 104),
          if (_filterSiap) _barisFilter(),
          const SizedBox(height: 6),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  // ── Baris jenis (Film / Series / Anime / Drakor) DIHAPUS ──────────
  //
  // Atas permintaan pemilik aplikasi: tombol jenis di halaman Film
  // dibuang. Series, Anime, dan Drakor tetap bisa dijangkau — lewat
  // FILTER yang sudah ada (dan lewat pencarian gabungan). Jadi halaman
  // ini murni "All Film + filter".
  //
  // Catatan: `_jenis` (bidang filter) sengaja TETAP ADA dan tetap
  // dipakai untuk menyusun permintaan ke backend; yang dihapus cuma
  // tombolnya di layar. Nilai bawaannya 'movie'.
  //
  // Sengaja disimpan supaya baris filter jenis tinggal dipanggil lagi
  // kalau nanti mau dimunculkan kembali.
  // ignore: unused_element
  Widget _barisJenisDihapus() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final (id, nama) in _jenisPilihan)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _cip(
                nama,
                aktif: _jenis == id,
                // Ganti jenis = filter genre direset, karena daftar genre
                // film dan serial berbeda dan genre lama bisa tidak ada.
                onTap: () => _ubahFilter(() {
                  _jenis = id;
                  _genre = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ── Baris 2: filter genre / negara / tahun / urutan ──
  Widget _barisFilter() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _pilihChip(
            label: 'Genre',
            nilai: _genre,
            pilihan: _genreUntukJenis,
            onPilih: (v) => _ubahFilter(() => _genre = v),
          ),
          _pilihChip(
            label: 'Negara',
            nilai: _negara,
            pilihan: _pilihanNegara,
            onPilih: (v) => _ubahFilter(() => _negara = v),
          ),
          _pilihChip(
            label: 'Tahun',
            nilai: _tahun,
            pilihan: _pilihanTahun.map((t) => {'id': t, 'nama': t}).toList(),
            onPilih: (v) => _ubahFilter(() => _tahun = v),
          ),
          _pilihChip(
            label: 'Urutan',
            nilai: _urut == 'popularity.desc' ? null : _urut,
            pilihan: _pilihanUrut,
            onPilih: (v) => _ubahFilter(() => _urut = v ?? 'popularity.desc'),
          ),
        ],
      ),
    );
  }

  /// Ambil nilai yang dipakai sebagai parameter dari satu item pilihan.
  ///
  /// PERHATIAN: kunci `id` dari backend TIDAK seragam, dan salah membaca
  /// berarti filter diam-diam tidak jalan (nilainya jadi string kosong).
  /// Yang benar-benar dikirim backend:
  ///   genre  -> { id: 28, nama: 'Aksi' }
  ///   negara -> { kode: 'KR', nama: 'Korea Selatan' }   ← bukan `id`!
  ///   urut   -> { id: 'popularity.desc', nama: '...' }
  /// Karena itu ketiganya dicoba berurutan.
  static String _nilaiDari(Map<String, dynamic> p) {
    for (final k in ['id', 'kode', 'slug', 'value']) {
      final v = p[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  /// Nama yang ditampilkan untuk satu item pilihan.
  static String _namaDari(Map<String, dynamic> p) {
    for (final k in ['nama', 'name', 'label', 'title']) {
      final v = p[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return _nilaiDari(p);
  }

  /// Chip yang membuka daftar pilihan saat ditekan.
  Widget _pilihChip({
    required String label,
    required String? nilai,
    required List<Map<String, dynamic>> pilihan,
    required ValueChanged<String?> onPilih,
  }) {
    final terpakai = nilai != null && nilai.isNotEmpty;
    String? namaTerpakai;
    if (terpakai) {
      final cocok = pilihan.where((e) => _nilaiDari(e) == nilai);
      namaTerpakai = cocok.isEmpty ? nilai : _namaDari(cocok.first);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _cip(
        terpakai ? '$label: $namaTerpakai' : label,
        aktif: terpakai,
        ikon: terpakai ? Icons.close : Icons.expand_more,
        // Kalau sudah terpakai, tekan = bersihkan (bukan buka daftar).
        onTap: terpakai
            ? () => onPilih(null)
            : () async {
                final pilih = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: AppColors.surface,
                  isScrollControlled: true,
                  builder: (ctx) => _lembarPilihan(label, pilihan),
                );
                if (pilih != null) onPilih(pilih);
              },
      ),
    );
  }

  Widget _isi() {
    if (_loading && _hasil.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasil.isEmpty) {
      return const Center(
        child: Text('Tidak ada judul untuk filter ini',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        Layout.desktop(context) ? 28 : 14, 0,
        Layout.desktop(context) ? 28 : 14, 120,
      ),
      // Kolom: HP tetap 3 (persis seperti sebelumnya), desktop jadi
      // 6–9 kolom lewat Layout.kolom(). Di HP lebarnya < 900 sehingga
      // Layout.kolom(3) mengembalikan 3 — Android tidak berubah.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Layout.of(context).kolom(3),
        childAspectRatio: 0.52,
        crossAxisSpacing: Layout.desktop(context) ? 16 : 10,
        mainAxisSpacing: Layout.desktop(context) ? 20 : 14,
      ),
      itemCount: _hasil.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _hasil.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final x = _hasil[i];
        return PosterCard(
          title: (x['title'] ?? '').toString(),
          imageUrl: Api.imgProxy((x['poster'] ?? '').toString()),
          ratingText: (x['rating'] ?? '').toString(),
          width: double.infinity,
          onTap: () => _buka(x),
        );
      },
    );
  }

  /// Chip kecil bergaya tema.
  Widget _cip(String teks,
      {required bool aktif, IconData? ikon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? AppColors.red : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: aktif ? AppColors.red : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              teks,
              style: TextStyle(
                color: aktif ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (ikon != null) ...[
              const SizedBox(width: 4),
              Icon(ikon,
                  size: 15,
                  color: aktif ? Colors.white : AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  /// Lembar pilihan dari bawah layar.
  Widget _lembarPilihan(String judul, List<Map<String, dynamic>> pilihan) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(judul,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in pilihan)
                  ListTile(
                    dense: true,
                    title: Text(
                      _namaDari(p),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () =>
                        Navigator.of(context).pop(_nilaiDari(p)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
