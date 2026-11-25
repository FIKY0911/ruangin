# Ruangin

Aplikasi Android (Flutter) untuk melihat jadwal mengajar dosen lintas prodi, lengkap dengan
status sesi (tercatat / belum terkonfirmasi / batal), ruang terbaru, dan notifikasi perubahan.
Backend-nya API Laravel. Data yang dipakai saat ini adalah data demo sintetis.

```
RuangIn/
├── app/        Aplikasi Flutter (Android)   → detail: app/README.md
├── backend/    API Laravel + MySQL          → detail: backend/README.md
└── docs/       PRD dan desain referensi
```

## Prasyarat

| Untuk | Yang dibutuhkan |
|---|---|
| App | Flutter dengan Dart SDK `^3.13.5` (sesuai `app/pubspec.yaml`), Android SDK, dan emulator atau HP Android |
| Backend | PHP 8.2+ (dengan ekstensi `pdo_mysql`, `mbstring`, `xml`, `curl`, `zip`), Composer 2, MySQL 8 |

Cek setup:

```bash
flutter doctor -v
php -v
composer -V
```

## Instalasi

```bash
git clone https://github.com/FIKY0911/ruangin.git
cd ruangin
```

### 1. Backend

```bash
cd backend
composer install
cp .env.example .env          # isi DB_USERNAME dan DB_PASSWORD sesuai MySQL Anda
php artisan key:generate
```

Buat dua database kosong di MySQL, `ruangin` untuk aplikasi dan `ruangin_test` untuk test
(bisa lewat DBeaver, phpMyAdmin, atau HeidiSQL):

```sql
CREATE DATABASE IF NOT EXISTS ruangin      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ruangin_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Lalu isi tabel dan data demo:

```bash
php artisan migrate --seed
```

### 2. Aplikasi Flutter

```bash
cd ../app
flutter pub get
```

## Konfigurasi

Satu-satunya pengaturan app adalah alamat backend, lewat `--dart-define=API_BASE_URL=...`.
Nilai default-nya `http://10.0.2.2:8000/api`, yaitu alamat laptop dari sudut pandang emulator
Android (lihat `app/lib/core/api_config.dart`). App tidak membaca file `.env`.

| App berjalan di | Perintah |
|---|---|
| Emulator Android | `flutter run` |
| HP fisik (WiFi sama dengan laptop) | `flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |
| Chrome | `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api` |

Untuk HP fisik atau emulator, backend harus dijalankan dengan `--host=0.0.0.0`
(lihat langkah di bawah). Android mengizinkan `http` karena `usesCleartextTraffic="true"`.

Set zona waktu emulator ke Asia/Jakarta supaya jam sesi sama dengan jadwal kampus.

## Menjalankan

Urutannya: backend dulu, lalu app.

```bash
# Terminal 1: backend
cd backend
php artisan serve --host=0.0.0.0 --port=8000

# Terminal 2: app
cd app
flutter devices               # pastikan emulator atau HP terdeteksi
flutter run
```

Opsional, jadwal peringatan dini (P11) butuh scheduler saat pengembangan:

```bash
cd backend
php artisan schedule:work
```

### Akun demo

Password semua akun: `ruangin123`

| Email | Peran |
|---|---|
| `nadia@demo.ruangin.id` | mahasiswa (Manajemen) |
| `raka@demo.ruangin.id` | mahasiswa (Akuntansi) |
| `rina@demo.ruangin.id` | dosen (`l-rina`) |
| `hendra@demo.ruangin.id` | petugas (scope Teknik Informatika dan Sistem Informasi) |

Mengisi ulang data demo, misalnya di hari demo:

```bash
cd backend
php artisan ruangin:reset-demo --force
```

Akun yang dibuat lewat Daftar selalu berperan sebagai mahasiswa.

## Test

```bash
# Backend (memakai database ruangin_test)
cd backend
php artisan test

# App (memakai MockClient, tidak butuh server)
cd app
flutter analyze
flutter test
```

Test end-to-end app ke backend sungguhan opsional dan mengubah data, jadi jalankan hanya
di database uji:

```bash
RUANGIN_E2E_URL=http://127.0.0.1:8000/api flutter test test/e2e_api_test.dart
```

## Build APK

```bash
cd app
flutter build apk --dart-define=API_BASE_URL=http://<IP-server>:8000/api
```

Hasilnya ada di `app/build/app/outputs/flutter-apk/app-release.apk`. Build ini masih
ditandatangani dengan kunci debug. Untuk Google Play, siapkan keystore sendiri sesuai
[panduan Flutter](https://docs.flutter.dev/deployment/android).

## Masalah umum

| Gejala | Penyebab dan solusi |
|---|---|
| `No supported devices found` | Emulator belum jalan. Jalankan lewat `flutter emulators --launch <nama>` atau Device Manager di Android Studio. |
| Emulator mati atau `Lost connection to device` | Memori laptop habis. Jalankan emulator dengan `-memory 1536`, dan tutup aplikasi berat lain. |
| Login gagal: tidak bisa terhubung ke server | Backend belum jalan, atau belum `--host=0.0.0.0`. Cek juga firewall port 8000. |
| `Unknown database 'ruangin'` | Database belum dibuat. Jalankan SQL di bagian Backend. |
| `flutter pub get` gagal | `flutter clean`, lalu ulangi `flutter pub get` di folder `app/`. |

## Struktur dan dokumen

- [`app/README.md`](app/README.md): arsitektur app, daftar layar, dan endpoint yang dipakai.
- [`backend/README.md`](backend/README.md): daftar endpoint, format error, dan aturan bisnis.
- [`docs/PRD-Ruangin.md`](docs/PRD-Ruangin.md): requirement produk.

## Lisensi dan tim

Proyek ini dibuat untuk STACK 2026 (GDGoC ITB), Case 1: Smarter Campus and Learning,
oleh tim Kopdes Di Tengah Laut.
