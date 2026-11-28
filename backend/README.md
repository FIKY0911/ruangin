# Ruangin Backend (Laravel API)

REST API untuk aplikasi Flutter Ruangin: login + role dari server, cari dosen/mata kuliah/sesi, timeline lintas prodi, riwayat kehadiran per semester, detail sesi + riwayat, edit sesi oleh dosen/petugas, ikuti sesi atau dosen, notifikasi dalam app, lapor ruang kosong + konfirmasi, poin, sinkron absensi (simulasi), dan peringatan dini.

Semua data seed **sintetis** (sama dengan `app/lib/data/fixtures/seed_data.dart`).

- Stack: Laravel 12, PHP 8.2+, MySQL 8, Laravel Sanctum (Bearer token)
- Zona waktu: `Asia/Jakarta`. Semua tanggal dikirim sebagai ISO-8601 dengan offset, mis. `2026-11-23T07:30:00+07:00`

## Cara memasang server

Yang perlu ada: PHP 8.2 atau lebih baru, Composer, dan MySQL 8.

1. Masuk ke folder `backend` dan pasang paket PHP:

   ```bash
   cd backend
   composer install
   ```

2. Buat file pengaturan dari contoh:

   ```bash
   cp .env.example .env
   php artisan key:generate
   ```

3. Buka `.env`, lalu isi `DB_USERNAME` dan `DB_PASSWORD` dengan user MySQL Anda.

4. Buat dua database kosong di MySQL: `ruangin` (untuk aplikasi) dan `ruangin_test` (untuk test).

5. Isi database dengan data contoh:

   ```bash
   php artisan migrate --seed
   ```

6. Nyalakan server:

   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```

Keterangan:
- `--host=0.0.0.0` membuat server bisa diakses dari emulator Android dan dari HP di WiFi yang sama.
- `RUANGIN_SYNC_KEY` di `.env` boleh diisi string acak. Ini hanya dipakai kalau ingin memanggil endpoint sinkron absensi dengan kunci.

### Data demo

Jadwal seed memakai tanggal **relatif ke hari ini**. Seed juga membuat satu semester aktif (14 minggu, hari ini di minggu ke-11) dan mengulang setiap sesi tiap minggu sepanjang semester itu, supaya riwayat kehadiran per semester ada isinya. Reset di hari demo:

```bash
php artisan ruangin:reset-demo --force   # migrate:fresh --seed
```

| Akun | Role | Catatan |
|---|---|---|
| `nadia@demo.ruangin.id` | mahasiswa | Mahasiswa Manajemen |
| `raka@demo.ruangin.id` | mahasiswa | Mahasiswa Akuntansi |
| `rina@demo.ruangin.id` | dosen | Dosen `l-rina` |
| `hendra@demo.ruangin.id` | petugas | Scope: Teknik Informatika, Sistem Informasi |

Password semua akun: `ruangin123`

### Peringatan dini (P11)

Butuh scheduler yang berjalan:

```bash
php artisan schedule:work          # dev: cek tiap menit
php artisan ruangin:early-warnings # atau jalankan manual sekali
```

### Hapus notifikasi lama

Notifikasi yang lebih lama dari `RUANGIN_NOTIFICATION_RETENTION_DAYS` hari (default 30, `0` = simpan selamanya) tidak ditampilkan lagi dan dihapus setiap hari pukul 02.00 oleh scheduler:

```bash
php artisan ruangin:prune-notifications   # atau jalankan manual
```

### Test

Test memakai database `ruangin_test` (lihat `phpunit.xml`). Pastikan database itu sudah dibuat.

```bash
php artisan test --testsuite=Feature
```

Tanpa MySQL, test juga bisa jalan di SQLite memori (butuh ekstensi `pdo_sqlite`):

```bash
DB_CONNECTION=sqlite DB_DATABASE=:memory: php artisan test --testsuite=Feature
```

## Konvensi API

- Base URL: `http://<host>:8000/api`
- Header: `Accept: application/json`, dan `Authorization: Bearer <token>` untuk semua endpoint kecuali login/register.
- Field JSON memakai camelCase dan sama dengan `fromJson` di model Dart (`Account`, `Lecturer`, `Session`, `AppNotification`, `EmptyRoomReport`), ditambah beberapa field turunan dari server.
- Format error:

```json
{ "message": "Password salah.", "code": "wrongPassword", "errors": { "password": ["Password salah."] } }
```

| HTTP | `code` | Arti |
|---|---|---|
| 401 | `unauthenticated` | Token tidak ada / kedaluwarsa |
| 401 | `accountNotFound`, `wrongPassword` | Gagal login |
| 403 | `forbidden` | Role/scope tidak berhak |
| 404 | `notFound` | Data tidak ada |
| 409 | `staleVersion` | Sesi sudah diubah orang lain, muat ulang |
| 422 | `invalidInput` | Validasi form (lihat `errors`) |
| 422 | `emailTaken`, `invalidState`, `outsideWindow`, `limitReached`, `alreadyResolved` | Aturan bisnis |
| 429 | `tooManyRequests` | Rate limit |

> Catatan untuk Flutter: `DateTime.parse("...+07:00")` menghasilkan waktu UTC. Panggil `.toLocal()` sebelum memformat jam.

## Endpoint

### Auth

| Method | Path | Body | Hasil |
|---|---|---|---|
| POST | `/auth/register` | `email`, `password`, `confirmPassword` | 201 `{data: Account}`. Role selalu `mahasiswa`. Tidak langsung login |
| POST | `/auth/login` | `email`, `password`, `deviceName?` | `{token, tokenType, account}` |
| GET | `/auth/me` | | `{data: Account}` |
| POST | `/auth/logout` | | 204, token dicabut |

`Account`: `id, name, email, role (mahasiswa|dosen|petugas), roleLabel, subtitle, lecturerId, scopeProdi[], points`

### Dosen & timeline (P01, P02)

| Method | Path | Query | Hasil |
|---|---|---|---|
| GET | `/lecturers` | `q?` (nama sebagian, tidak peka huruf besar/kecil) | `{data: Lecturer[]}` urut nama |
| GET | `/lecturers/{id}` | | `{data: Lecturer}` |
| GET | `/lecturers/{id}/timeline` | `date?=YYYY-MM-DD` (default hari ini) | `{data: Session[], lecturer, date}` urut jam mulai, lintas prodi |
| GET | `/lecturers/{id}/attendance` | | `{data: LecturerAttendance}` riwayat kehadiran semester aktif |

`Lecturer`: `id, name, prodi, faculty, isFollowed`

### Riwayat kehadiran per semester

`GET /lecturers/{id}/attendance` mengembalikan semua sesi dosen di semester aktif (semester yang tanggal mulai–selesainya mencakup hari ini):

```json
{ "data": {
  "lecturer": { "id": "l-rina", "name": "...", "prodi": "...", "faculty": "...", "isFollowed": false },
  "semester": { "id": "sem-demo", "name": "Semester Ganjil 2026/2027", "startsOn": "2026-09-14", "endsOn": "2026-12-20" },
  "summary": { "total": 66, "tercatat": 39, "belumTerkonfirmasi": 4, "batal": 3, "belumBerlangsung": 20, "counted": 43, "rate": 0.907 },
  "courses": [
    { "courseName": "Basis Data Lanjut", "prodi": "Sistem Informasi", "summary": { "...": "sama" },
      "meetings": [ { "number": 1, "sessionId": "...", "start": "...", "end": "...", "room": "Ruang 201", "building": "Gedung B", "status": "tercatat" } ] }
  ],
  "generatedAt": "2026-11-23T09:45:00+07:00"
} }
```

- `status` tiap pertemuan: `tercatat` (ada catatan absensi), `belumTerkonfirmasi` (sesi sudah selesai tanpa catatan), `batal`, atau `belumBerlangsung` (belum ada catatan dan sesi belum selesai). Sesi tanpa catatan **tidak pernah** dihitung "tidak hadir".
- `rate` = `tercatat / (tercatat + belumTerkonfirmasi)`, atau `null` kalau belum ada sesi yang dihitung. Sesi batal dan yang belum berlangsung tidak ikut dihitung.
- Pertemuan diberi nomor 1..n per mata kuliah (mata kuliah + prodi), urut waktu. Mata kuliah diurutkan menurut nama.
- Tidak ada semester aktif → 404 `notFound` ("Belum ada semester aktif.").

### Cari dosen, mata kuliah, atau sesi

`GET /search?q=` (wajib, maks 100 karakter, tidak peka huruf besar/kecil, sebagian kata)

```json
{ "query": "mobile", "lecturers": [Lecturer], "sessions": [Session], "from": "2026-11-23", "to": "2026-11-29" }
```

- `lecturers`: nama dosen cocok, urut nama.
- `sessions`: nama mata kuliah **atau** ruang cocok, dari hari ini sampai 6 hari ke depan, urut jam mulai, maks 50. Sesi batal ikut tampil (dengan status `batal`).
- `q` kosong → 422 `invalidInput`.

### Ikuti dosen

| Method | Path | Hasil |
|---|---|---|
| PUT | `/lecturers/{id}/follow` | ikuti (idempoten), 404 kalau dosen tidak ada |
| DELETE | `/lecturers/{id}/follow` | berhenti ikuti (idempoten) |
| GET | `/me/followed-lecturers` | `{data: Lecturer[], lecturerIds: []}` urut nama |

Mengikuti dosen = mengikuti **semua** sesinya: perubahan sesi, laporan ruang kosong, sinkron absensi, dan peringatan dini dikirim ke pengikut dosen juga. Orang yang mengikuti dosen sekaligus sesinya tetap hanya mendapat satu notifikasi per kejadian, dan pengubahnya sendiri tidak diberi notifikasi. Sesi hari ini milik dosen yang diikuti juga muncul di `GET /me/today`. `isFollowed` di `Session` tetap berarti sesi itu diikuti langsung.

### Pengaturan app

`GET /app-config` → `{data: {simulatedData, notificationRetentionDays}}`

- `simulatedData` (`RUANGIN_SIMULATED_DATA`, default `true`): semua jadwal dan absensi adalah data sintetis / sinkron absensi simulasi. App menampilkan label "Simulasi" selama nilainya `true`.
- `notificationRetentionDays` (`RUANGIN_NOTIFICATION_RETENTION_DAYS`, default 30): app menampilkan "Notifikasi otomatis dihapus setelah N hari". `null` kalau notifikasi disimpan selamanya.

### Sesi (P03, P05)

| Method | Path | Body / Query | Siapa |
|---|---|---|---|
| GET | `/sessions` | `date?`, `editable?=1` | semua (daftar "Kelola") |
| GET | `/sessions/{id}` | | semua, termasuk `history`, `myReport`, `pendingReportCount` |
| POST | `/sessions/{id}/time` | `version`, `start`, `end` (ISO-8601) | dosen pemilik / petugas dalam scope |
| POST | `/sessions/{id}/room` | `version`, `room` | idem |
| POST | `/sessions/{id}/cancel` | `version`, `reason?` | idem |
| POST | `/sessions/{id}/attendance` | `version` | idem (catat kehadiran manual) |

`Session`: `id, lecturerId, lecturer?, courseName, prodi, start, end, room, building, source, updatedAt, isCancelled, attendance{recordedAt, source}|null, history?[{at, actor, description}], status (tercatat|belumTerkonfirmasi|batal), statusLabel, statusExplanation, version, canEdit, isFollowed`

- `status` dihitung server: batal → `batal`, ada catatan absensi → `tercatat`, selain itu `belumTerkonfirmasi` (**tidak pernah** jadi batal hanya karena belum ada absensi).
- `building` (Gedung) diambil dari katalog ruang (tabel `rooms`) setiap kali ruang diisi atau dipindah. Pencocokan nama ruang tidak peka huruf besar/kecil. Ruang yang tidak ada di katalog → `building: null`.
- Setiap edit wajib mengirim `version` terakhir yang dilihat client. Kalau versinya sudah basi, server menjawab **409** `staleVersion`.
- Setiap edit menambah riwayat, mengganti `source` menjadi "Petugas akademik · Nama", dan mengirim notifikasi `sessionChanged` ke semua pengikut (kecuali pengubahnya sendiri).

### Ikuti sesi (P04)

| Method | Path | Hasil |
|---|---|---|
| PUT | `/sessions/{id}/follow` | ikuti (idempoten) |
| DELETE | `/sessions/{id}/follow` | berhenti ikuti (idempoten) |
| GET | `/me/follows` | `{data: Session[], sessionIds: []}` |

### Notifikasi (P06)

| Method | Path | Hasil |
|---|---|---|
| GET | `/me/notifications?unread=1` | `{data: AppNotification[], unreadCount, retentionDays}`, terbaru dulu, hanya yang belum lewat masa simpan |
| POST | `/notifications/{id}/read` | tandai dibaca |
| POST | `/me/notifications/read-all` | `{updated}` |

`kind`: `sessionChanged` (perubahan resmi), `emptyRoomReport` (laporan mahasiswa, "belum dikonfirmasi"), `earlyWarning` (P11), `reportResolved` (laporan Anda dikonfirmasi/ditolak). `sessionId` dipakai untuk membuka detail sesi dari notifikasi.

> Catatan untuk Flutter: enum `NotificationKind` di app baru punya 2 nilai. Tambahkan `earlyWarning` dan `reportResolved`, kalau tidak `byName` akan error.

### Lapor ruang kosong + poin (P09, P10)

| Method | Path | Siapa | Hasil |
|---|---|---|---|
| POST | `/sessions/{id}/reports` | mahasiswa | 201 laporan baru / 200 laporan yang sudah ada (1 per orang per sesi) |
| GET | `/reports?status=pending\|confirmed\|rejected\|all` | dosen/petugas | antrian laporan untuk sesi yang boleh dia ubah |
| POST | `/reports/{id}/confirm` | dosen pemilik / petugas scope | sesi jadi **Batal**, semua pelapor pending dapat poin |
| POST | `/reports/{id}/reject` | idem | laporan ditolak, jadwal tidak berubah |

Aturan: laporan hanya bisa dikirim dari 15 menit sebelum mulai sampai sesi selesai, maksimal 5 laporan per hari, dan bernilai 10 poin kalau dikonfirmasi. Semua angka ini bisa diubah di `.env` / `config/ruangin.php`. Laporan tidak pernah mengubah status sesi sebelum dikonfirmasi.

### Sinkron absensi (P08)

`POST /sync/attendance`, autentikasi pakai **salah satu**:

- header `X-Sync-Key: <RUANGIN_SYNC_KEY>` (feed absensi kampus / skrip simulasi), atau
- Bearer token petugas (panel demo), yang hanya bisa menyinkronkan sesi dalam scope-nya.

```json
{ "records": [
  { "externalId": "ABS-MOBILE-TODAY", "recordedAt": "2026-11-23T07:34:00+07:00" },
  { "sessionId": "s-strukdat-today" }
] }
```

Respons: `{recorded, results: [{index, key, sessionId, status}]}` dengan `status` salah satu dari `recorded | alreadyRecorded | cancelled | notFound | forbidden`. Endpoint ini idempoten. Sesi yang tercatat mengirim notifikasi "Kelas tercatat berjalan · HH.MM" ke pengikutnya.

`externalId` seed = `ABS-` + id sesi tanpa awalan `s-`, dalam huruf besar (mis. `s-pm-today` → `ABS-PM-TODAY`).

### Peringatan dini (P11)

Kalau sebuah sesi dosen hari ini masih "Belum terkonfirmasi" 15 menit setelah mulai, atau dilaporkan kosong, pengikut sesi-sesi **berikutnya** dosen itu hari ini mendapat notifikasi `earlyWarning`. Peringatan dikirim sekali per sesi dan hanya berupa notifikasi, tidak mengubah status sesi apa pun.

### Kartu "Hari ini"

`GET /me/today` → `{data: Session[], date, nextSessionId, unreadCount, points, serverTime}`: sesi hari ini yang diikuti langsung atau lewat dosen yang diikuti, urut jam mulai. `nextSessionId` adalah sesi yang belum batal dan belum selesai.

### Usulan pesan (P12)

`GET /sessions/{id}/message-draft?purpose=meminta arahan lomba` → `{text, proposedTime, proposedPlace, note}`

Isinya draf pesan sopan yang mengusulkan bertemu setelah kelas selesai, di ruang sesi itu. App hanya menyalinnya: Ruangin tidak mengirim pesan dan tidak menampilkan kontak dosen. Sesi yang batal → 422.

### Push notification (P07)

| Method | Path | Body |
|---|---|---|
| POST | `/me/devices` | `token` (FCM registration token), `platform?` (android/ios/web) |
| DELETE | `/me/devices` | `token` (panggil saat logout) |

Push **nonaktif** sampai `FCM_PROJECT_ID` dan `FCM_CREDENTIALS` (path ke file service-account JSON Firebase) diisi di `.env`. Saat aktif, setiap notifikasi dalam app juga dikirim lewat FCM dengan `data: {sessionId, kind}`, dan token yang sudah tidak valid dihapus otomatis. Notifikasi di database tetap menjadi sumber utama, jadi semua alur P0 tetap jalan tanpa FCM.

### Mode uji

| Method | Path | Body | Siapa |
|---|---|---|---|
| POST | `/test-runs` | `participantCode`, `task`, `method` (`biasa`/`ruangin`), `targetSessionId?` | semua (mulai stopwatch) |
| POST | `/test-runs/{id}/finish` | `answerRoom?`, `answerEndTime?`, `isCorrect?`, `notes?` | pemilik (stop stopwatch) |
| GET | `/test-runs` | | petugas: semua, lainnya: milik sendiri. Ada `summary` per metode (n, rata-rata, median, maks durasi, tingkat benar) |
| GET | `/test-runs/export` | | petugas, file CSV |
| POST | `/me/notifications/seen` | `ids[]` | app melapor notifikasi yang baru tampil di layar |
| GET | `/test/notification-latency?date=` | | petugas: jeda dari perubahan disimpan sampai notifikasi terlihat |

Kalau `targetSessionId` diisi, jawaban (ruang + jam selesai) dicek otomatis dengan data **terbaru** sesi itu saat tugas selesai. `isCorrect` dari fasilitator menimpa hasil cek otomatis. Format jawaban fleksibel (`"ruang 306"` = `"Ruang 306"`, `"10:00"` = `"10.00"`).

### Panel demo

Khusus petugas, dan hanya aktif kalau `RUANGIN_DEMO_MODE=true`.

| Method | Path | Fungsi |
|---|---|---|
| POST | `/demo/attendance-batch` | Simulasi batch absensi. Tanpa body: semua sesi dalam scope yang sudah mulai hari ini dan belum tercatat (dicatat 4 menit setelah mulai). Bisa juga `{sessionIds: [...]}` |
| POST | `/demo/early-warnings` | Jalankan cek peringatan dini sekarang |
| POST | `/demo/reset` | Hapus semua data dan isi ulang data demo hari ini (semua akun ter-logout) |

## Menghubungkan app Flutter

| App berjalan di | Base URL |
|---|---|
| Chrome (Flutter web) | `http://127.0.0.1:8000/api` |
| Emulator Android | `http://10.0.2.2:8000/api` |
| HP fisik (WiFi sama) | `http://<IP-laptop>:8000/api` (lihat `ipconfig`) |

Untuk emulator dan HP, jalankan server dengan `php artisan serve --host=0.0.0.0 --port=8000`. Karena memakai `http` (bukan https), Android perlu `android:usesCleartextTraffic="true"` di `AndroidManifest.xml` (untuk demo saja).

## Struktur

```
app/
  Enums/UserRole.php
  Exceptions/DomainError.php        error bisnis -> JSON {message, code}
  Http/Controllers/Api/*            endpoint
  Http/Resources/*                  bentuk JSON (sama dengan model Dart)
  Models/*                          Lecturer, User, ClassSession, SessionChange, AppNotification, EmptyRoomReport, Room, Semester
  Services/SessionService.php       edit sesi + riwayat + notifikasi + optimistic locking
  Services/ReportService.php        lapor kosong, konfirmasi/tolak, poin
  Services/EarlyWarningService.php  peringatan dini
  Services/NotificationService.php  notifikasi dalam app (+ push setelah commit)
  Services/PushService.php          FCM HTTP v1 (P07)
  Http/Controllers/Api/TestModeController.php  mode uji
  Http/Controllers/Api/DemoController.php      panel demo
config/ruangin.php                  angka aturan bisnis ([Asumsi] di PRD §12), demo mode, FCM
database/seeders/DatabaseSeeder.php data demo sintetis
routes/api.php, routes/console.php  route + command terjadwal
tests/Feature/RuanginApiTest.php    skenario demo PRD §8 end-to-end
tests/Feature/SystemFeaturesTest.php panel demo, mode uji, push, usulan pesan, Hari ini
tests/Feature/DesignGapsTest.php    gedung, riwayat per semester, cari, ikuti dosen, Simulasi, masa simpan notifikasi
```
