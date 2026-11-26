# Ruangin: aplikasi Android (Flutter)

Aplikasi ini mengambil semua datanya dari server Laravel di folder `../backend`. Data akun, dosen, jadwal, sesi, notifikasi, laporan, dan poin semuanya dari server. Tidak ada data contoh di dalam aplikasi.

## Langkah 1: nyalakan server

Ikuti panduan di [`../backend/README.md`](../backend/README.md). Intinya:

```bash
cd ../backend
php artisan serve --host=0.0.0.0 --port=8000
```

## Langkah 2: jalankan aplikasi

```bash
flutter pub get
flutter run
```

Alamat server yang dipakai secara default: `http://10.0.2.2:8000/api`. Itu alamat laptop dilihat dari emulator Android.

Kalau aplikasi dijalankan di tempat lain, ganti alamatnya dengan `--dart-define`:

| Aplikasi dijalankan di | Perintah |
|---|---|
| Emulator Android | `flutter run` |
| HP sendiri (satu WiFi dengan laptop) | `flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |
| Browser Chrome | `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api` |
| File APK | `flutter build apk --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |

Alamat yang sedang dipakai bisa dilihat di menu **Profil → Server**.

Android mengizinkan koneksi `http` karena `usesCleartextTraffic="true"` di `android/app/src/main/AndroidManifest.xml`. Ini cukup untuk demo. Untuk aplikasi yang dirilis, pakai `https`.

Jam di aplikasi mengikuti zona waktu perangkat. Atur emulator ke Asia/Jakarta supaya jamnya sama dengan jadwal kampus.

## Akun untuk mencoba

Semua akun memakai password `ruangin123`.

| Email | Peran |
|---|---|
| `nadia@demo.ruangin.id` | Mahasiswa |
| `raka@demo.ruangin.id` | Mahasiswa |
| `rina@demo.ruangin.id` | Dosen |
| `hendra@demo.ruangin.id` | Petugas |

Akun yang dibuat lewat menu Daftar otomatis menjadi mahasiswa.

## Layar di aplikasi

Menu bawah: **Beranda · Jadwal · Laporan · Profil**.

| Layar | Isinya |
|---|---|
| Beranda | Pencarian dosen, notifikasi, dan sesi hari ini. Dosen dan petugas melihat sesi yang bisa mereka ubah. |
| Cari dosen | Hasil pencarian dan tampilan kalau tidak ada hasil. |
| Profil dosen | Jadwal dosen per hari. |
| Detail sesi | Status, riwayat, tombol ikuti, lapor ruang kosong, dan salin draf pesan ke dosen. |
| Ubah sesi | Ganti ruang, jam, batalkan sesi, atau catat kehadiran. Dosen dan petugas saja. |
| Jadwal | Sesi yang Anda ikuti. Dosen dan petugas juga melihat "Kelola". |
| Laporan | Untuk dosen dan petugas: daftar laporan ruang kosong untuk dikonfirmasi atau ditolak. Untuk mahasiswa: poin dan hasil laporan Anda. |
| Notifikasi | Perubahan sesi, laporan, peringatan dini, dan hasil laporan. |
| Profil | Data akun dan tombol keluar. Petugas juga melihat Panel demo. |
| Mode uji | Stopwatch untuk tugas uji pengguna. |

Desain tampilan mengacu ke `../image/ui-ux/`. Folder ini tidak ada di git, jadi perlu disalin secara terpisah.

## Kalau server tidak bisa dihubungi

- Pesannya: "Tidak bisa terhubung ke server" beserta alamat yang dipakai. Cek lagi server sudah menyala dan alamatnya benar.
- Kalau login habis masa berlakunya, aplikasi kembali ke layar awal dan menampilkan "Sesi login berakhir".
- Kalau ada perubahan dari orang lain saat Anda mengedit sesi, aplikasi menawarkan tombol "Muat ulang".
- Kalau aplikasi tidak bisa mengambil data terbaru, layar akan menampilkan pesan gagal muat. Buka lagi layar itu setelah server menyala.

## Test dan pengecekan kode

```bash
flutter analyze
flutter test
```

`flutter test` tidak butuh server. Ia memakai data palsu dari `test/fake_backend.dart`.

Untuk menguji ke server sungguhan (mengubah data, jadi pakai database test):

```bash
RUANGIN_E2E_URL=http://127.0.0.1:8000/api flutter test test/e2e_api_test.dart
```

## Struktur kode

```
lib/
  core/          Hasil dan error, jam, format tanggal, dan alamat server (api_config.dart)
  data/          Model data, klien HTTP (remote/api_client.dart), dan repository
  domain/        Validasi form, layanan login, dan aturan status sesi
  presentation/  Layar, controller, dan widget
```

Token login disimpan di perangkat lewat `shared_preferences` (kunci `auth.token`).
Tema ada di `lib/presentation/theme/app_theme.dart`. Font Jost dan Source Serif 4 ikut dibundel.
