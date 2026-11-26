# Ruangin

Ruangin adalah aplikasi Android untuk melihat jadwal dosen. Mahasiswa bisa tahu dosen mengajar di ruang mana dan jam berapa. Kalau ada perubahan, aplikasi akan memberi tahu.

Aplikasi ini terdiri dari dua bagian:

- **app/**: aplikasi Android (Flutter)
- **backend/**: server (Laravel) dan database (MySQL)

Ada juga **docs/** berisi dokumen produk dan desain.

## Yang perlu disiapkan

| Bagian | Yang perlu ada |
|---|---|
| Aplikasi | Flutter, Android SDK, dan emulator atau HP Android |
| Server | PHP 8.2 atau lebih baru, Composer, dan MySQL 8 |

Untuk cek apakah sudah siap, jalankan:

```bash
flutter doctor -v
php -v
composer -V
```

## Cara instalasi

Download proyeknya dulu:

```bash
git clone https://github.com/FIKY0911/ruangin.git
cd ruangin
```

### 1. Siapkan server

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Buka file `.env`, lalu isi `DB_USERNAME` dan `DB_PASSWORD` dengan user MySQL Anda.

Buat dua database kosong di MySQL. Anda bisa pakai DBeaver, phpMyAdmin, atau HeidiSQL:

```sql
CREATE DATABASE IF NOT EXISTS ruangin      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ruangin_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

- `ruangin` dipakai aplikasi.
- `ruangin_test` dipakai untuk test.

Lalu isi database dengan data contoh:

```bash
php artisan migrate --seed
```

### 2. Siapkan aplikasi

```bash
cd ../app
flutter pub get
```

## Cara mengatur alamat server

Aplikasi perlu tahu alamat server. Alamat ini diatur saat menjalankan aplikasi, lewat `--dart-define`.

Kalau tidak diatur, aplikasi memakai `http://10.0.2.2:8000/api`. Alamat ini berarti laptop Anda, dilihat dari emulator Android.

| Aplikasi dijalankan di | Perintah |
|---|---|
| Emulator Android | `flutter run` |
| HP sendiri (satu WiFi dengan laptop) | `flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |
| Browser Chrome | `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api` |

Ganti `<IP-laptop>` dengan alamat IP laptop Anda. Cek alamatnya dengan `ip addr` (Linux) atau `ipconfig` (Windows).

Di emulator, atur zona waktu ke Asia/Jakarta supaya jamnya sama dengan jadwal kampus.

## Cara menjalankan

Nyalakan server dulu, baru aplikasinya.

```bash
# Terminal 1: server
cd backend
php artisan serve --host=0.0.0.0 --port=8000
```

```bash
# Terminal 2: aplikasi
cd app
flutter devices
flutter run
```

`flutter devices` menampilkan daftar perangkat yang terdeteksi. Pastikan emulator atau HP Anda ada di daftar itu.

Kalau ingin peringatan dini berjalan otomatis saat pengembangan:

```bash
cd backend
php artisan schedule:work
```

### Akun untuk mencoba

Semua akun memakai password `ruangin123`.

| Email | Peran |
|---|---|
| `nadia@demo.ruangin.id` | Mahasiswa |
| `raka@demo.ruangin.id` | Mahasiswa |
| `rina@demo.ruangin.id` | Dosen |
| `hendra@demo.ruangin.id` | Petugas |

Kalau data sudah berantakan dan ingin mengembalikannya seperti awal:

```bash
cd backend
php artisan ruangin:reset-demo --force
```

Akun yang dibuat sendiri lewat menu Daftar otomatis menjadi mahasiswa.

## Menjalankan test

```bash
# Test server (pakai database ruangin_test)
cd backend
php artisan test

# Test aplikasi (tidak perlu server)
cd app
flutter analyze
flutter test
```

Ada juga test yang menguji aplikasi langsung ke server sungguhan. Test ini mengubah data, jadi hanya jalankan di database test:

```bash
RUANGIN_E2E_URL=http://127.0.0.1:8000/api flutter test test/e2e_api_test.dart
```

## Membuat file APK

```bash
cd app
flutter build apk --dart-define=API_BASE_URL=http://<IP-server>:8000/api
```

File APK akan ada di `app/build/app/outputs/flutter-apk/app-release.apk`.

APK ini masih memakai kunci debug. Untuk dibagikan ke Google Play, buat kunci sendiri. Panduannya ada di [dokumentasi Flutter](https://docs.flutter.dev/deployment/android).

## Kalau ada masalah

| Yang terjadi | Cara mengatasi |
|---|---|
| `No supported devices found` | Emulator belum menyala. Nyalakan dulu dari Android Studio, atau jalankan `flutter emulators --launch <nama>`. |
| Emulator mati sendiri | Memori laptop kurang. Jalankan emulator dengan `-memory 1536`, lalu tutup aplikasi lain yang berat. |
| Login gagal, muncul "tidak bisa terhubung ke server" | Server belum menyala, atau belum memakai `--host=0.0.0.0`. Cek juga firewall di port 8000. |
| `Unknown database 'ruangin'` | Database `ruangin` belum dibuat. Ulangi langkah membuat database. |
| `flutter pub get` gagal | Jalankan `flutter clean`, lalu `flutter pub get` lagi di folder `app/`. |

## Dokumen lain

- [`app/README.md`](app/README.md): penjelasan aplikasi, daftar layar, dan koneksi ke server.
- [`backend/README.md`](backend/README.md): daftar alamat API dan aturan bisnis.
- [`docs/PRD-Ruangin.md`](docs/PRD-Ruangin.md): dokumen kebutuhan produk.

Proyek ini dibuat untuk STACK 2026 (GDGoC ITB), Case 1: Smarter Campus and Learning, oleh tim Kopdes Di Tengah Laut.
