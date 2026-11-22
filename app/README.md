# Ruangin — aplikasi Android (Flutter)

Scope saat ini: **Welcome → Register / Login → Home dummy**, sesi persisten, Logout.
Tampilan mengikuti `../docs/design/{welcome,register,login}.jpg`. Register hanya
email + password + konfirmasi (tanpa nama); sapaan di Home = bagian email sebelum `@`.
Tombol Apple/Google, "Forgot password?", Terms, dan Privacy hanya tampilan:
saat diketuk muncul snackbar "Belum tersedia di demo". Tanpa backend: semua data lokal (seed sintetis + shared_preferences)
di balik interface repository.

## Menjalankan

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter emulators --launch Medium_Phone   # atau emulator lain
flutter run                               # atau: flutter build apk --debug
```

Akun demo (data sintetis, password `ruangin123`):
`nadia@demo.ruangin.id` (mahasiswa), `raka@demo.ruangin.id` (mahasiswa),
`rina@demo.ruangin.id` (dosen), `hendra@demo.ruangin.id` (petugas).
Akun hasil Daftar selalu ber-role mahasiswa.

## Arsitektur

```
lib/
  core/          Result/AppFailure, Clock, formatter, brand assets
  data/          models (immutable), fixtures/seed_data.dart, local/key_value_store.dart,
                 repositories/ (interface + implementasi lokal)
  domain/        aturan & use case pure Dart: auth_validators, password_hasher (PBKDF2-SHA256,
                 salt acak), auth_service (register/login/logout/restore session)
  presentation/  controller (ChangeNotifier + Provider) dan widget yang hanya menampilkan state
                 dan meneruskan aksi
```

- Password tidak pernah disimpan plain text (PBKDF2-HMAC-SHA256, 10.000 iterasi, salt 16 byte).
- Sesi login disimpan di shared_preferences (`auth.currentAccount`); buka ulang app tetap masuk.
- Mengganti ke backend: buat implementasi `AuthRepository` baru dan pasang di `buildDependencies`
  (`lib/app.dart`); UI tidak berubah.

## Catatan

Kode fitur jadwal dari scope sebelumnya (cari dosen, timeline, detail sesi, ikuti,
notifikasi dalam app, lapor ruang kosong) masih ada di `lib/` beserta unit testnya,
tetapi **tidak terhubung ke navigasi** dan tidak dikembangkan lagi sesuai perubahan scope.

Theme & komponen reusable: `lib/presentation/theme/app_theme.dart`,
`lib/presentation/widgets/auth_components.dart`. Font dibundel (OFL) di
`assets/fonts`: Jost (UI) dan Source Serif 4 (judul "Class awaits").

Asset gambar berasal dari `../assets` (disalin ke `app/assets/images`).
`ruangin_logo_cropped.webp` adalah logo resmi yang dipangkas ruang kosongnya.
