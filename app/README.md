# Ruangin — aplikasi Android (Flutter)

App terhubung ke API Laravel di `../backend` (Sanctum, Bearer token). Semua data —
akun & role, dosen, timeline, detail sesi, ikuti sesi, notifikasi, laporan ruang
kosong, poin — datang dari server. Tidak ada lagi data/fixture lokal atau hashing
password di app.

## Menghubungkan ke backend

1. Jalankan backend (lihat `../backend/README.md`):

   ```sh
   cd ../backend
   composer install && cp .env.example .env && php artisan key:generate
   php artisan migrate --seed
   php artisan serve --host=0.0.0.0 --port=8000
   ```

2. Jalankan app. Base URL default `http://10.0.2.2:8000/api` (laptop dilihat dari
   emulator Android). Ganti dengan `--dart-define`:

   | App berjalan di | Perintah |
   |---|---|
   | Emulator Android | `flutter run` |
   | HP fisik (WiFi sama) | `flutter run --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |
   | Chrome | `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api` |
   | Build APK | `flutter build apk --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api` |

   Alamat server yang dipakai terlihat di **Profil → Server**. Android memakai
   `usesCleartextTraffic="true"` karena server demo memakai `http` (hapus untuk produksi).
   Jam ditampilkan dalam zona waktu perangkat; set emulator ke Asia/Jakarta agar sama
   dengan jadwal kampus.

Akun demo (password `ruangin123`): `nadia@demo.ruangin.id`, `raka@demo.ruangin.id`
(mahasiswa), `rina@demo.ruangin.id` (dosen), `hendra@demo.ruangin.id` (petugas).
Akun hasil Daftar selalu ber-role mahasiswa (ditentukan server).

## Layar

Navigasi bawah mengikuti `../image/ui-ux/`: **Beranda · Jadwal · Laporan · Profil**.

| Layar | Referensi | Endpoint |
|---|---|---|
| Beranda: cari, lonceng notifikasi, "Sesi hari ini" | `beranda.png` | mahasiswa `GET /me/today`; dosen/petugas `GET /sessions?editable=1` |
| Cari dosen + hasil kosong | `Hasil_Pencarian.png`, `Hasil_Pencarian_Tidak_Ada.png` | `GET /lecturers?q=` |
| Profil dosen + pilih hari + timeline | `profil.png` | `GET /lecturers/{id}`, `/lecturers/{id}/timeline?date=` |
| Detail sesi: status, riwayat, ikuti, lapor kosong, usulan pesan, ubah | — (tema yang ada) | `GET /sessions/{id}`, `PUT/DELETE /sessions/{id}/follow`, `POST /sessions/{id}/reports`, `GET /sessions/{id}/message-draft` |
| Ubah sesi (ruang, jam, batal, catat hadir) | — | `POST /sessions/{id}/room`, `/time`, `/cancel`, `/attendance` (+`version`) |
| Jadwal: Diikuti (+ Kelola untuk dosen/petugas) | gaya `profil.png` | `GET /me/follows`, `GET /sessions?date=&editable=1` |
| Laporan (dosen/petugas): antrian konfirmasi | kartu `Hasil_Pencarian.png` | `GET /reports?status=`, `POST /reports/{id}/confirm`, `/reject` |
| Laporan (mahasiswa): poin + hasil laporan | — | `GET /auth/me`, `GET /me/notifications` (`reportResolved`) |
| Notifikasi (perubahan, laporan, peringatan dini, hasil laporan) | — | `GET /me/notifications`, `POST /notifications/{id}/read`, `/me/notifications/read-all`, `/me/notifications/seen` |
| Profil akun | header `profil.png` | `GET /auth/me`, `POST /auth/logout` |
| Panel demo (petugas) | — | `POST /demo/attendance-batch`, `/demo/early-warnings`, `/demo/reset` |
| Mode uji (stopwatch) | — | `POST /test-runs`, `/test-runs/{id}/finish`, `GET /test-runs` |

Tidak dipakai app: `POST /sync/attendance` (feed kampus, diwakili panel demo),
`GET /test-runs/export` (CSV untuk fasilitator), `GET /test/notification-latency`,
`POST/DELETE /me/devices` (push FCM belum dikonfigurasi di app; badge notifikasi
di-refresh tiap 30 detik dan saat app dibuka lagi).

## Error dari server

`lib/data/remote/api_client.dart` memetakan `{message, code, errors}` ke `ApiFailure`
(turunan `AppFailure`), dan UI menampilkan `message` dari server apa adanya.

- **401 `unauthenticated`**: token dihapus, pengguna kembali ke Welcome dengan pesan
  "Sesi login berakhir". (401 `wrongPassword`/`accountNotFound` saat login tetap jadi
  error form.)
- **409 `staleVersion`**: layar Ubah sesi menawarkan "Muat ulang" lalu memakai versi terbaru.
- **422**: `errors` per field dipetakan ke field form (register/login).
- Server tak terjangkau: pesan "Tidak bisa terhubung ke server (alamat)". Saat app dibuka
  offline, akun terakhir dipakai dan layar menampilkan "gagal muat" / "data lama".

## Menjalankan test

```sh
flutter analyze
flutter test        # MockClient + test/fake_backend.dart, tanpa server
```

Opsional, ke backend sungguhan (mengubah data, reset sesudahnya):

```sh
RUANGIN_E2E_URL=http://127.0.0.1:8000/api flutter test test/e2e_api_test.dart
```

## Arsitektur

```
lib/
  core/          Result/AppFailure, Clock, formatter, api_config (API_BASE_URL)
  data/          models (fromJson sesuai backend), remote/api_client.dart (HTTP + token),
                 repositories/ (interface + implementasi API)
  domain/        validasi form, auth_service (validasi lokal lalu /auth/*), aturan status
  presentation/  controller (ChangeNotifier + Provider) dan widget yang hanya menampilkan state
```

Token Sanctum disimpan di shared_preferences (`auth.token`, plus salinan akun terakhir).
Theme & komponen: `lib/presentation/theme/app_theme.dart`,
`lib/presentation/widgets/{auth_components,ruangin_widgets}.dart`. Font dibundel (OFL):
Jost (UI) dan Source Serif 4 (judul).
