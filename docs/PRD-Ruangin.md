# PRD — Ruangin

**Product Requirements Document** · v0.2 · 19 Nov 2026
STACK 2026 (GDGoC ITB) · Case 1: Smarter Campus and Learning · Tim **Kopdes Di Tengh Laut**
Sumber utama: **abstrak final yang disubmit 10 Nov 2026** ("Ruangin: Know the Class Is Running Before You Go", lihat `docs/Fitur-Pengembangan-Ruangin.md` §0), lalu `SPEC.md` v0.1, `docs/HANDBOOK-STACK-2026.md` + Handbook PDF. `docs/Abstract-Ruangin-STACK2026.docx` adalah draf lama.
Perubahan dari v0.1 ada di bagian **Revisi** paling bawah.

> Penanda di dokumen ini:
> - **[Asumsi]**: belum ada di SPEC/abstrak, perlu dikonfirmasi owner/tim sebelum dipakai.
> - **[Rencana]**: fitur yang belum dibuat. Jangan disebut "sudah jadi" di proposal, video, atau pitching (aturan handbook).
> - Status kode per 19 Nov 2026: `lib/` masih berisi template Flutter bawaan (`main.dart` counter). Belum ada fitur M1 di kode.

---

## 1. Ringkasan

Ruangin adalah aplikasi Android (Flutter) yang menampilkan **satu timeline per dosen, gabungan dari semua prodi dalam satu kampus**. Ruangin **bukan timetable statis**: status tiap sesi **disinkronkan dengan catatan absensi kampus** (di demo: simulasi), lengkap dengan sumber dan waktu update. Mahasiswa mencari dosen, melihat kelasnya selesai jam berapa dan di ruang mana, lalu **mengikuti sesi**.

Pengikut mendapat kabar kalau:
- dosen/petugas mengonfirmasi pindah ruang, ganti jam, atau batal;
- mahasiswa lain **melaporkan ruangan kosong** (berlabel "belum dikonfirmasi");
- sesi lebih awal dosen itu hari ini belum terkonfirmasi atau kosong (**peringatan dini**).

Tidak ada catatan absensi → tampil "Belum terkonfirmasi", **tidak pernah** "Batal".

Ruangin hanya menampilkan jadwal mengajar. Ruangin **tidak** menjamin dosen bisa ditemui.

## 2. Latar belakang & masalah

- Mahasiswa di luar kelas seorang dosen sulit tahu dosen itu sedang mengajar kapan dan di mana.
- Jadwal hanya ada di grup kelas atau jadwal per prodi, yang tidak bisa dilihat orang luar.
- Perubahan ruang, jam, atau pembatalan hanya sampai ke mahasiswa di grup kelas. Orang di luar grup datang ke ruang lama atau menunggu tanpa kepastian.
- Contoh kasus (SPEC): mahasiswa Manajemen ingin minta arahan lomba ke dosen TI, tapi tidak ada di grup kelas TI.

- Pesan ke dosen harus formal dan tepat waktu; pesan yang tidak dibalas sungkan ditagih [1]. Jalan keluarnya mencegat dosen saat kelas selesai.

**Bukti yang dipakai di abstrak final** (nomor = daftar sumber abstrak)
- [2] Politeknik Negeri Pontianak: mahasiswa sering tidak tahu kegiatan dosen dan menunggu di kampus tanpa tahu berapa lama.
- [5] UNISKA: kelas kosong karena dosen telat melapor tidak hadir; perubahan mendadak tidak sampai ke sebagian mahasiswa.
- [6] UNJ: 62,5% mahasiswa Geografi yang disurvei tinggal > 20 km dari kampus.
- [8] Post publik grup Facebook "Keluh Kesah Ngampus" (5 Nov 2025) dan [9] post publik Threads 2023–2026 tentang dosen tidak datang / tidak membalas.
- Belum ada survei, wawancara, atau data uji milik tim. Angka hanya boleh ditulis kalau sudah benar-benar dikumpulkan.

**Alternatif yang ada sekarang**: grup chat kelas, jadwal per prodi, bertanya ke teman sekelas. Semuanya terutama menjangkau mahasiswa yang terdaftar di kelas itu, dan jarang menunjukkan kapan info terakhir diperbarui.
- Aplikasi janji temu Ubaya [7]: dosen harus membuka slot, jadi ada kerja tambahan. Ruangin memakai absensi yang sudah dicatat kampus.
- Aplikasi jadwal STIKI & FK UII [3][4]: hanya memberi kabar ke mahasiswa yang terdaftar. Ruangin bisa diikuti per sesi oleh orang luar kelas.

## 3. Tujuan & metrik sukses

| Tujuan | Metrik (diukur lewat uji pengguna berbasis tugas) | Target |
|---|---|---|
| Mahasiswa menemukan jadwal lintas prodi lebih cepat | Waktu selesai tugas "cari jadwal & ruang terbaru dosen X": cara biasa vs Ruangin | **[Asumsi]** belum ada target angka, laporkan hasil apa adanya |
| Jawaban lebih akurat | Persentase jawaban benar (ruang & jam terbaru) | Laporkan hasil asli |
| Perubahan cepat sampai ke pengikut | Jeda dari perubahan disimpan sampai notifikasi terlihat | Diukur dan dilaporkan sebagai hasil uji, bukan klaim |
| Alur inti berfungsi andal | Semua P0 bisa didemokan di satu build Android; V01–V04 & V06 lulus, notifikasi dalam app di V05 lulus | 100% skenario uji SPEC |

- Jumlah peserta uji: **[Perlu konfirmasi]** (di abstrak masih "[planned number]").
- Sebagian peserta urutannya dibalik (Ruangin dulu, baru cara biasa) untuk mengurangi bias urutan.
- "Mengurangi perjalanan sia-sia" adalah **dampak yang mau diuji**, bukan hasil demo.

## 4. Target pengguna & persona

| Peran | Siapa | Kebutuhan utama |
|---|---|---|
| Pengguna utama | Mahasiswa S1 yang perlu menemui dosen dari prodi lain | Tahu dosen mengajar di mana, sampai jam berapa, dan apakah ada perubahan |
| Pengguna sekunder | Dosen | Mengubah status/ruang/jam sesinya sendiri |
| Pengguna sekunder | Petugas akademik | Mengubah sesi di cakupan tugasnya |

**Persona 1 — Mahasiswa lintas prodi** (ilustratif, bukan data riset)
- Mahasiswa Manajemen, ingin minta arahan lomba ke dosen TI.
- Tidak ada di grup kelas TI, tidak tahu jadwal dosen itu.
- Ingin: tahu kelas dosen selesai jam berapa dan di ruang mana, dapat kabar kalau ruang pindah.
- Frustrasi: datang ke ruang lama, menunggu tanpa kepastian.

**Persona 2 — Petugas akademik** (ilustratif)
- Mengurus jadwal beberapa prodi.
- Ingin: mengubah ruang/jam/status sesi dengan cepat, yakin hanya sesi yang benar yang berubah.

**Persona 3 — Dosen** (ilustratif)
- Mengajar di dua prodi.
- Ingin: menandai pindah ruang atau batal tanpa harus mengabari banyak grup.

## 5. User stories

| ID | Sebagai | Saya ingin | Supaya | Fitur |
|---|---|---|---|---|
| US-01 | mahasiswa | mencari dosen dengan nama sebagian | cepat menemukan dosen yang benar beserta prodinya | P01 |
| US-02 | mahasiswa | melihat timeline dosen per tanggal dari semua prodi | tahu dosen mengajar di mana dan sampai jam berapa | P02 |
| US-03 | mahasiswa | membuka detail sesi | melihat jadwal terbaru, sumber, waktu update, dan apa yang berubah | P03 |
| US-04 | mahasiswa | mengikuti / berhenti mengikuti sesi | dapat kabar hanya untuk sesi yang saya pedulikan | P04 |
| US-05 | dosen/petugas | mengubah jam, ruang, status batal, atau mencatat kehadiran sesi yang menjadi hak saya | info mahasiswa selalu terbaru | P05 |
| US-06 | mahasiswa | dapat notifikasi di dalam app saat sesi yang saya ikuti berubah | tidak datang ke ruang lama | P06 |
| US-07 | mahasiswa | mengetuk notifikasi dan langsung masuk ke detail sesi | melihat ruang/jam baru sebelum berangkat | P06 |
| US-08 | mahasiswa | menerima push notification di Android | tahu perubahan walau app tertutup | P07 [Rencana, P1] |
| US-09 | tim/demo | sinkron simulasi absensi lewat ID sesi eksternal | status "Tercatat"/"Belum terkonfirmasi" terisi otomatis | P08 [Rencana, P1] |
| US-11 | mahasiswa | melihat status "Tercatat"/"Belum terkonfirmasi" dari sinkron absensi beserta jamnya | tahu kelas jalan tanpa bertanya ke teman/petugas | P08 (naik ke P0) |
| US-12 | mahasiswa di depan ruangan | melaporkan ruangan kosong | pengikut lain tidak ikut datang sia-sia | P09 (baru) |
| US-13 | petugas/dosen | mengonfirmasi atau menolak laporan ruang kosong | info ke mahasiswa tetap terpercaya | P09 |
| US-14 | pengikut sesi siang | dapat peringatan dini kalau sesi pagi dosen itu belum terkonfirmasi/kosong | bisa cek lagi sebelum berangkat | P11 (baru) |
| US-15 | mahasiswa | menyalin draf pesan sopan berisi jam selesai + ruang | pesan ke dosen konkret dan sopan | P12 (baru) |
| US-16 | pelapor | dapat poin saat laporannya terkonfirmasi | termotivasi melapor | P10 (baru, P1) |
| US-10 | pengguna baru | melihat pengenalan singkat aplikasi | paham bahwa Ruangin menampilkan jadwal, bukan jaminan dosen bisa ditemui | **[Asumsi]** onboarding |

## 6. Ruang lingkup fitur (MoSCoW)

| Prioritas | Fitur | Sumber |
|---|---|---|
| **Must** | P01 Cari dosen pakai nama (tidak peka huruf besar-kecil, nama sebagian, tampil prodi asal) | SPEC P0 |
| **Must** | P02 Profil + timeline per tanggal (lintas prodi, urut waktu) | SPEC P0 |
| **Must** | P03 Detail & status sesi (sumber, waktu update, riwayat perubahan) | SPEC P0 |
| **Must** | P04 Ikuti / berhenti ikuti sesi (persisten, idempoten) | SPEC P0 |
| **Must** | P05 Dosen/petugas ubah sesi miliknya (jam, ruang, batal, catat kehadiran) | SPEC P0 |
| **Must** | P06 Notifikasi dalam app + buka sesi dari notifikasi | SPEC P0 |
| **Must** | Masuk (login) dengan akun demo + role dari server | SPEC Batasan MVP |
| **Must** | State layar: loading, kosong, gagal muat + coba lagi, data lama + waktu update | SPEC Layar |
| **Should** | P07 Push notification Android (FCM) | SPEC P1 |
| **Must** | P08 Sinkron status kehadiran (adapter + sumber simulasi), **naik dari P1** | Abstrak final |
| **Must** | P09 Lapor ruang kosong + antrian konfirmasi petugas | Abstrak final |
| **Must** | P11 Peringatan dini berantai per dosen (notifikasi, bukan ubah status) | Abstrak final |
| **Must** | Mode uji: catat waktu tugas & jeda notifikasi | Abstrak final (rencana uji) |
| **Should** | P12 Salin usulan pesan (waktu + tempat) | Abstrak final ("propose a concrete time and place") |
| **Should** | P10 Poin untuk laporan terkonfirmasi | Abstrak final |
| **Could** | Onboarding 2–3 layar (pesan inti + batasan "jadwal ≠ jaminan bertemu") | **[Asumsi]** |
| **Could** | Daftar akun mandiri (sign up) | **[Asumsi]** — SPEC: akun demo lewat seed. Lihat §7 |
| **Won't (MVP)** | Web admin, booking konsultasi, rating dosen, kontak pribadi, GPS/lokasi live, absensi per mahasiswa, SSO, integrasi sistem kampus asli (adapter siap, data simulasi), fitur AI | SPEC + abstrak final |

Rincian fitur pengembangan + alasan juri: `docs/Fitur-Pengembangan-Ruangin.md`.

## 7. Catatan soal Onboarding & Daftar

- SPEC hanya menyebut layar **Masuk**. Akun dan jadwal demo disiapkan lewat **seed**.
- Kalau tim mau layar **Daftar**, perlu keputusan: siapa yang boleh daftar, bagaimana role & kampus ditentukan (role wajib dari server, bukan dari app), dan apakah butuh verifikasi email kampus. **[Perlu konfirmasi]**
- Rekomendasi aman untuk MVP: Onboarding ringan → **Masuk** dengan akun demo. Tombol "Daftar" boleh ada sebagai tampilan, tapi ditandai **"belum tersedia di demo"** supaya tidak mengaku fitur sudah jadi.

## 8. Alur pengguna utama

**Mahasiswa**: Masuk → cari dosen → buka profil → lihat timeline → buka detail → ikuti sesi → dapat kabar perubahan → buka detail terbaru → putuskan kapan datang.

**Dosen/petugas**: Masuk → pilih sesi yang boleh diubah → ubah status, ruang, atau jam → cek lagi → simpan → lihat konfirmasi.

Detail layar dan diagram ada di `docs/UserFlow-Ruangin.md`.

**Skenario demo (SPEC §7)**
1. Mahasiswa Manajemen mencari dosen TI untuk minta arahan lomba.
2. Timeline menunjukkan kelas selesai 10.00 di Ruang 306. Dia mengikuti sesi itu.
3. Petugas memindahkan sesi ke Ruang 402.
4. Mahasiswa membuka notifikasi, melihat ruang baru sebelum berangkat.
5. Tunjukkan satu sesi lain berstatus "Belum terkonfirmasi" untuk memperlihatkan bedanya.
6. **[Baru]** Panel demo: kirim batch absensi (simulasi) → sesi pagi jadi "Tercatat · Sinkron absensi 08.04".
7. **[Baru]** Sesi pagi dosen lain tetap "Belum terkonfirmasi" lewat masa tenggang → pengikut sesi siangnya dapat peringatan dini.
8. **[Baru]** Mahasiswa melapor "Ruangan kosong" → pengikut lain dapat kabar berlabel "belum dikonfirmasi" → petugas konfirmasi "Batal" → semua dapat notifikasi resmi, pelapor dapat poin (kalau P10 jadi).

Demo memakai dua akun di dua HP/emulator. Semua data contoh **sintetis**.

## 9. Non-goals

- Tidak menunjukkan apakah dosen sedang luang atau bisa ditemui.
- Tidak menampilkan lokasi real-time (GPS) dosen.
- Tidak menampilkan absensi per mahasiswa. Yang tampil hanya status per sesi.
- Laporan mahasiswa tidak pernah mengubah status jadwal sebelum dikonfirmasi petugas/dosen.
- Poin tidak bisa ditukar hadiah/uang.
- Tidak menampilkan kontak pribadi dosen.
- Tidak ada booking konsultasi atau rating dosen.
- Tidak terhubung ke API/sistem kampus asli di MVP.
- Tidak ada fitur AI di versi ini (abstrak: kebutuhan intinya data jadwal yang terkonfirmasi).
- "Tercatat" **bukan** berarti dosen sedang ada di ruangan sekarang.

## 10. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Akses ke jadwal lintas prodi resmi | Data tidak tersedia untuk pemakaian nyata | MVP pakai data sintetis + update yang diinput petugas. Uji kesediaan kampus sebelum pakai nyata |
| Update telat dari dosen/petugas | Info tetap basi | Tampilkan sumber + waktu update di tiap sesi. Status "Belum terkonfirmasi" jelas dibedakan |
| Mahasiswa salah paham "Tercatat" = dosen ada | Ekspektasi salah | Label + teks penjelas di detail sesi; catatan di onboarding [Asumsi] |
| Izin push ditolak / FCM belum siap | Notifikasi tidak sampai | Notifikasi P0 disimpan di database dan tampil di app; semua alur P0 bisa didemokan tanpa FCM |
| Bentrok edit dua petugas | Data tertimpa | Nomor versi sesi; edit dari versi basi ditolak (409), user diminta muat ulang |
| Siapa memegang penugasan petugas belum jelas | Hak akses salah | Pakai role demo dulu; tandai sebagai keputusan terbuka |
| Waktu sempit sebelum 30 Nov | Fitur tidak selesai | Kerjakan per milestone, tulis jujur mana yang sudah/belum jadi |
| Laporan ruang kosong palsu/iseng | Pengikut salah info | Label "belum dikonfirmasi", tidak mengubah status, 1 laporan per orang per sesi, hanya bisa di jendela sesi, poin hanya untuk laporan terkonfirmasi |
| Absensi kampus telat masuk | Sesi berjalan tapi tampil "Belum terkonfirmasi" | Teks jelas "belum ada catatan, bukan berarti batal"; peringatan dini memakai masa tenggang |
| Klaim berlebihan di submission | Sanksi handbook (sampai diskualifikasi) | Tandai data sintetis, mockup, fitur rencana; catat bantuan AI di README & proposal |

## 11. Timeline (selaras jadwal handbook & milestone SPEC)

Semua deadline 23:59 WIB, bisa berubah (pantau IG @gdgocitb).

| Tanggal | Tahap handbook | Target Ruangin |
|---|---|---|
| 10 Nov 2026 | Submit abstrak + twibbon | Selesai (abstrak sudah dikirim, tim lolos semifinal) |
| 18 Nov 2026 | Pengumuman semifinal | Lolos |
| 19–24 Nov | — | **M1**: Flutter jalan di Android, data sintetis lokal, cari → profil → timeline → detail (+ status sinkron & tombol lapor kosong di UI) |
| 20–29 Nov | — | **M2** (paralel dengan M1): migrasi, seed, login + role, data dari backend, petugas bisa ubah sesi, RPC sinkron absensi. Rekam video 28 Nov dari progres nyata |
| **30 Nov 2026** | Submit proposal (maks 10 hlm) + video (maks 2 mnt, 1080p) + Declaration of Originality | Proposal & video Bahasa Inggris, sebut jelas mana yang sudah dan belum jadi |
| 7 Des 2026 | Pengumuman Top 10 | Konfirmasi ikut final |
| 1–15 Des 2026 | Menunggu Top 10 (7 Des) + masa pengembangan | **M3**: ikuti sesi, notifikasi dalam app, lapor kosong + konfirmasi, peringatan dini, uji dua akun. **M4**: uji pengguna, APK demo, README |
| **16 Des 2026** | Final Day (Bandung, offline) | 2–3 tugas besar di sesi build (usulan: P10 poin, P07 push FCM, kartu "Hari ini"/polish), submit produk + deck (maks 15 slide), pitching 10 + 10 menit |

Jadwal harian per orang: `docs/Task-Harian-Tim.md`.

## 12. Hal yang belum diputuskan (dari SPEC + temuan dokumen)

- Akses dan aturan publikasi jadwal dari kampus.
- Siapa yang memegang penugasan petugas.
- Kesiapan akses push (FCM).
- Peran tiap anggota. Nama sudah ada di abstrak final (Surya Fafta Utama (Lead), Mohamad Fiky Ba'dafitro, Fayza Azzahra, Andika Catur Ariantono), perannya belum.
- Jumlah peserta uji pengguna.
- Perlu tidaknya onboarding dan layar daftar.
- Angka yang masih [Asumsi]: jendela lapor (15 menit sebelum mulai s.d. selesai), masa tenggang peringatan dini (15 menit), poin per laporan (10), batas lapor per hari (5).
- Persetujuan tim atas konflik SPEC vs abstrak (`docs/Fitur-Pengembangan-Ruangin.md` §3), lalu SPEC.md diperbarui.

---

## Revisi

**v0.2 · 19 Nov 2026**: diselaraskan dengan abstrak final yang disubmit 10 Nov 2026 (bukan draf `.docx`).
- Nama tim diisi: Kopdes Di Tengh Laut. Judul proyek: "Ruangin: Know the Class Is Running Before You Go".
- §1: Ruangin ditegaskan bukan timetable statis; status disinkronkan dengan absensi.
- §2: bukti diganti dengan sumber [1]–[9] dari abstrak final; alternatif Ubaya/STIKI/FK UII ditambahkan.
- §5: user story US-11 s.d. US-16 (sinkron absensi, lapor kosong, konfirmasi, peringatan dini, usulan pesan, poin).
- §6: P08 naik dari Should ke **Must**; fitur baru P09 (lapor kosong), P10 (poin), P11 (peringatan dini), P12 (usulan pesan), mode uji.
- §8: skenario demo 6–8.
- §9–§10: non-goal & risiko baru (absensi per orang, laporan palsu, absensi telat).
- §11: M1/M2 dibuat paralel, rincian harian dipindah ke `Task-Harian-Tim.md`.
- §12: placeholder nama tim dihapus; angka asumsi baru dicatat.
