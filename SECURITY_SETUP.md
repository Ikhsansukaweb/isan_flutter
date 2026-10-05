# Setup Keamanan ISAN — Checklist

Langkah-langkah WAJIB sebelum build ulang, urut dari yang paling penting.

## 1. Tambah dependency baru ke `pubspec.yaml`

Buka `pubspec.yaml`, di bagian `dependencies:`, tambahkan baris ini (jangan
hapus yang sudah ada):

```yaml
dependencies:
  flutter_secure_storage: ^9.2.2
  uuid: ^4.4.0
  crypto: ^3.0.5
  webview_flutter_android: ^4.0.0   # kalau belum ada dari sesi sebelumnya
```

Setelah itu:
```
flutter clean
flutter pub get
```

## 2. Ambil fingerprint SSL certificate asli (untuk SSL Pinning)

Jalankan script `get_ssl_fingerprint.sh` yang disertakan, DARI LAPTOP ATAU
SERVER YANG BISA AKSES `api.isanim.web.id` (bukan dari mana pun yang
jaringannya dibatasi):

```bash
chmod +x get_ssl_fingerprint.sh
./get_ssl_fingerprint.sh
```

Hasilnya berupa hex string panjang. Copy itu, buka
`lib/api/api_client.dart`, cari baris:

```dart
static const List<String> _pinnedSha256Fingerprints = [
  'GANTI_DENGAN_FINGERPRINT_SHA256_SERTIFIKAT_ASLI_DI_SINI',
];
```

Ganti dengan fingerprint asli (huruf kecil semua, tanpa tanda `:`).

**PENTING:** kalau sertifikat di-renew (Let's Encrypt biasanya tiap 90
hari), fingerprint-nya berubah dan APK lama bakal gagal connect total.
Disarankan masukin fingerprint LAMA + BARU sekaligus ke array itu pas
mendekati waktu renewal, baru rebuild & update APK, baru hapus yang lama.

**Tanpa langkah ini, app TIDAK BISA connect ke backend sama sekali** --
karena `SecurityContext(withTrustedRoots: false)` bikin semua koneksi
HTTPS otomatis gak dipercaya kecuali fingerprint-nya cocok.

## 3. Set environment variable `JWT_SECRET` yang kuat di server

Backend sudah pakai `process.env.JWT_SECRET` -- pastikan `.env` di server
production punya value yang kuat & random (bukan default fallback), dan
**JANGAN** ke-commit ke Git.

## 4. Install dependency baru di backend

```bash
cd backend
npm install
```

(`cookie-parser` baru ditambahkan ke `package.json`.)

## 5. Restart backend & test alur auth

Setelah deploy, test manual:
1. Login dari web -> cek di DevTools > Application > Cookies, harus ada
   `isan_token` & `isan_refresh` dengan flag `HttpOnly` tercentang.
2. Coba akses film/series/anime TANPA login -> harus muncul popup
   "Belum Login", bukan error teknis.
3. Login dari Flutter -> putar film -> tutup app sepenuhnya, buka lagi
   sebelum 1 jam -> harus tetap bisa nonton tanpa login ulang (refresh
   token jalan otomatis).
4. Setelah > 1 jam tanpa aktivitas refresh, coba lagi -> kalau refresh
   token juga sudah lewat 30 hari atau IP/device beda, baru diminta
   login ulang.

## Catatan: hal yang TIDAK termasuk di sini

- **Play Integrity API** -- butuh setup manual di Google Play Console
  (App Signing, API enablement) yang gak bisa dilakukan dari sini. Kalau
  nanti mau ditambahkan, kabari supaya kode client+backend-nya disiapkan.
- Endpoint metadata publik (list/search/detail anime/movie/series, musik
  trending/search) **sengaja tidak dikunci login** -- cuma endpoint yang
  benar-benar membuka link streaming (`/api/episode/:id`,
  `/api/movie/stream`, `/api/series/stream/...`, `/api/server/:id`) yang
  wajib login, sesuai permintaan awal ("khusus stream").
