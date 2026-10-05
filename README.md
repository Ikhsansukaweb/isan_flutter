# ISAN — Flutter App

Aplikasi mobile (Android & iOS) untuk ISAN, dibangun ulang secara native dengan
Flutter — **tanpa WebView** untuk UI. Backend tetap memakai API yang sama:
`https://api.isanim.web.id` (lihat `lib/api/api_client.dart`).

> Catatan: WebView **hanya** dipakai di satu tempat — layar nonton episode
> anime (`lib/screens/anime_episode_screen.dart`) — karena server video anime
> (mega, vidhide, filedon, dll) adalah embed pihak ketiga berbentuk iframe,
> bukan file video langsung, jadi tidak bisa diputar dengan native video
> player. Untuk Film dan Series, stream berupa `.m3u8` (HLS) sehingga diputar
> 100% native lewat `video_player`.

## Struktur proyek

```
lib/
  api/api_client.dart        # semua endpoint backend (mirror dari frontend/lib/api.ts)
  models/                    # model data anime, movie, series, song, user
  state/auth_state.dart      # state login (token disimpan di shared_preferences)
  theme.dart                 # warna & tema merah-hitam ala ISAN
  widgets/
    bottom_nav_bar.dart      # navbar bawah custom
    nav_svg_icons.dart       # SVG baru: home, anime, series, akun, kaca pembesar (search)
    poster_card.dart         # kartu poster anime/movie/series
    section_widgets.dart     # header section + scroll horizontal
    hero_banner.dart         # carousel banner di Beranda
  screens/
    home_screen.dart
    anime_list_screen.dart / anime_detail_screen.dart / anime_episode_screen.dart
    movie_list_screen.dart / movie_detail_screen.dart
    series_list_screen.dart / series_detail_screen.dart / series_episode_screen.dart
    music_screen.dart
    search_screen.dart       # halaman cari (dibuka dari tombol tengah navbar)
    auth_screen.dart / account_screen.dart
  root_shell.dart             # scaffold + bottom nav
  main.dart
assets/images/logo.png        # dari frontend/public/icon-512x512.png
assets/images/banners/*.jpeg  # banner hero (dari frontend/public/benner)
```

## Navbar bawah

Sesuai permintaan, navbar dipindah ke bawah dengan SVG baru (bukan icon
library bawaan): **Beranda – Anime – [Cari, tombol tengah elevated] – Series –
Akun**. Film dan Musik tetap bisa diakses lewat section "Lihat semua" di
Beranda. Tombol **Cari** di tengah pakai SVG kaca pembesar + label "Cari",
membuka halaman pencarian gabungan (anime/film/series/musik).

## Setup & Menjalankan

Project ini dibuat tanpa akses ke Flutter SDK/pub.dev dari sandbox saya, jadi
kamu perlu menjalankan langkah berikut di komputer kamu sendiri:

```bash
# 1. Pastikan Flutter SDK sudah terinstall (flutter doctor)
flutter --version

# 2. Masuk ke folder project
cd isan_flutter

# 3. Lengkapi scaffolding platform (folder android/ sudah saya siapkan manual,
#    tapi jalankan ini agar Gradle wrapper & project iOS Xcode lengkap/terbaru)
flutter create --platforms=ios,android .

# 4. Install dependency
flutter pub get

# 5. Jalankan di emulator/device
flutter run
```

`flutter create .` aman dijalankan di project yang sudah ada — Flutter hanya
akan melengkapi file platform yang belum ada/usang, dan **tidak** akan
menimpa folder `lib/` atau isi `pubspec.yaml` yang sudah saya tulis.

### Android
Folder `android/` sudah saya siapkan lengkap (manifest, gradle, icon,
permission INTERNET) — langsung bisa `flutter run` / `flutter build apk`
setelah `flutter pub get`.

### iOS
Saya sudah siapkan `ios/Runner/Info.plist`. Jalankan `flutter create
--platforms=ios .` untuk men-generate `Runner.xcodeproj` dan `Podfile` (file
project Xcode ini sebaiknya digenerate langsung oleh tool resminya, bukan
ditulis manual, supaya tidak corrupt). Setelah itu:

```bash
cd ios && pod install && cd ..
flutter run
```

## Mengganti base URL backend

Cukup ubah satu baris di `lib/api/api_client.dart`:

```dart
static const String base = 'https://api.isanim.web.id';
```

## Build APK release

```bash
flutter build apk --release
```
File hasil ada di `build/app/outputs/flutter-apk/app-release.apk`.
