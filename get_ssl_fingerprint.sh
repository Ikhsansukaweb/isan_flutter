#!/bin/bash
# Jalankan script ini di laptop/VPS yang BISA akses api.isanim.web.id
# (bukan di sandbox Claude -- domain itu diblokir dari sana).
#
# Cara pakai:
#   chmod +x get_ssl_fingerprint.sh
#   ./get_ssl_fingerprint.sh
#
# Hasilnya: SHA256 fingerprint sertifikat api.isanim.web.id. Copy HEX-nya
# (tanpa titik dua ":", huruf kecil semua) ke dalam
# lib/api/api_client.dart, ganti baris:
#   static const List<String> _pinnedSha256Fingerprints = [
#     'GANTI_DENGAN_FINGERPRINT_SHA256_SERTIFIKAT_ASLI_DI_SINI',
#   ];
#
# PENTING: kalau sertifikat di-renew (Let's Encrypt biasanya tiap 90 hari),
# fingerprint-nya BERUBAH -- APK lama bakal gagal connect total sampai
# di-update dengan fingerprint baru + rebuild + reinstall. Pertimbangkan
# masukin fingerprint sertifikat LAMA dan BARU sekaligus di array itu pas
# mendekati waktu renewal, supaya transisinya gak bikin app rusak dadakan.

DOMAIN="api.isanim.web.id"

echo "Mengambil sertifikat SSL dari $DOMAIN..."
echo ""

echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 \
  | sed 's/sha256 Fingerprint=//I'

echo ""
echo "Salin hex di atas (buang semua tanda ':' dan jadikan huruf kecil)"
echo "lalu tempel ke _pinnedSha256Fingerprints di lib/api/api_client.dart"
