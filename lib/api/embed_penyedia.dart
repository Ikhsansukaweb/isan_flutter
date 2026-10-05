/// Penyusun URL embed pemutar — dilakukan DI APLIKASI.
///
/// Kenapa di aplikasi, bukan di backend:
///
///   URL embed harus memuat MUSIM dan EPISODE yang benar-benar ditekan
///   pengguna. Kalau pembentukannya diserahkan ke backend, hasilnya
///   bergantung pada versi backend yang sedang terpasang — dan versi
///   yang tidak meneruskan musim/episode akan selalu memutar musim 1
///   episode 1.
///
///   Dengan menyusunnya di sini, musim dan episode selalu ikut, apa pun
///   versi backend-nya. Aplikasi tidak perlu menunggu backend diperbarui.
///
/// Pola URL:
///   film   : {base}/embed/movie/{tmdb_id}
///   serial : {base}/embed/tv/{tmdb_id}?s={musim}&e={episode}
///
/// Catatan: pola serial memakai QUERY STRING (?s=&e=), berbeda dari
/// VidSrc yang memakai segmen jalur (/embed/tv/{id}/{musim}/{episode}).
library;

/// Penyedia embed yang dikenal aplikasi.
///
/// `polaFilm` memakai {tmdb_id}; `polaSerial` memakai {tmdb_id},
/// {musim}, dan {episode}.
class PenyediaEmbed {
  final String id;
  final String label;
  final String base;
  final String polaFilm;
  final String polaSerial;

  const PenyediaEmbed({
    required this.id,
    required this.label,
    required this.base,
    required this.polaFilm,
    required this.polaSerial,
  });
}

/// Daftar penyedia. Saat ini hanya CineSrc.
///
/// Penyedianya cuma satu, jadi halaman detail TIDAK menampilkan tombol
/// ganti-penyedia (tombol itu hanya muncul kalau penyedia lebih dari
/// satu). Kalau nanti mau menambah penyedia lain, cukup tambah satu
/// entri di sini — tombolnya akan muncul sendiri.
const List<PenyediaEmbed> penyediaEmbed = [
  PenyediaEmbed(
    id: 'cinesrc',
    label: 'CineSrc',
    base: 'https://cinesrc.st',
    polaFilm: '/embed/movie/{tmdb_id}',
    polaSerial: '/embed/tv/{tmdb_id}?s={musim}&e={episode}',
  ),
];

/// Penyedia yang dipakai lebih dulu.
const penyediaUtama = 'cinesrc';

/// Ganti {nama} dengan nilainya.
String _isi(String pola, Map<String, String> nilai) {
  var hasil = pola;
  nilai.forEach((k, v) {
    hasil = hasil.replaceAll('{$k}', v);
  });
  return hasil;
}

/// Buang garis miring di ujung base supaya tidak jadi dua.
String _rapiBase(String b) => b.replaceAll(RegExp(r'/+$'), '');

/// Ambil id TMDB dari nilai apa pun.
///
/// Menerima id angka ("1399") maupun teks yang mengandung angka di
/// ujungnya (mis. "game-of-thrones-1399"). Mengembalikan string kosong
/// kalau tidak ada angka sama sekali — pemanggil lalu memakai URL dari
/// backend seperti semula.
String idTmdbDari(dynamic nilai) {
  if (nilai == null) return '';
  final t = nilai.toString().trim();
  if (t.isEmpty) return '';
  // id angka murni
  if (RegExp(r'^\d+$').hasMatch(t)) return t;
  // angka di ujung teks, mis. "judul-1399"
  final m = RegExp(r'(\d+)$').firstMatch(t);
  return m?.group(1) ?? '';
}

/// URL embed FILM.
String embedFilmUrl(String idTmdb, {String? penyediaId}) {
  final id = idTmdbDari(idTmdb);
  if (id.isEmpty) return '';
  final p = penyediaEmbed.firstWhere(
    (x) => x.id == (penyediaId ?? penyediaUtama),
    orElse: () => penyediaEmbed.first,
  );
  return _rapiBase(p.base) + _isi(p.polaFilm, {'tmdb_id': id});
}

/// URL embed SERIAL untuk MUSIM dan EPISODE tertentu.
///
/// Inilah inti perbaikannya: musim & episode benar-benar dimasukkan ke
/// URL, sehingga menekan episode 3 memutar episode 3 — bukan selalu
/// episode 1.
String embedSerialUrl(
  String idTmdb,
  int musim,
  int episode, {
  String? penyediaId,
}) {
  final id = idTmdbDari(idTmdb);
  if (id.isEmpty) return '';
  final p = penyediaEmbed.firstWhere(
    (x) => x.id == (penyediaId ?? penyediaUtama),
    orElse: () => penyediaEmbed.first,
  );
  final s = musim < 1 ? 1 : musim;
  final e = episode < 1 ? 1 : episode;
  return _rapiBase(p.base) +
      _isi(p.polaSerial, {
        'tmdb_id': id,
        'musim': '$s',
        'episode': '$e',
      });
}

/// Semua pilihan penyedia untuk sebuah episode serial.
///
/// Dipakai mengisi tombol ganti-penyedia: tiap penyedia menghasilkan
/// URL-nya sendiri untuk musim & episode yang sama.
List<Map<String, String>> pilihanSerial(String idTmdb, int musim, int episode) {
  final id = idTmdbDari(idTmdb);
  if (id.isEmpty) return const [];
  return penyediaEmbed
      .map((p) => {
            'id': p.id,
            'label': p.label,
            'embed': embedSerialUrl(id, musim, episode, penyediaId: p.id),
          })
      .where((m) => (m['embed'] ?? '').isNotEmpty)
      .toList();
}

/// Semua pilihan penyedia untuk sebuah film.
List<Map<String, String>> pilihanFilm(String idTmdb) {
  final id = idTmdbDari(idTmdb);
  if (id.isEmpty) return const [];
  return penyediaEmbed
      .map((p) => {
            'id': p.id,
            'label': p.label,
            'embed': embedFilmUrl(id, penyediaId: p.id),
          })
      .where((m) => (m['embed'] ?? '').isNotEmpty)
      .toList();
}
