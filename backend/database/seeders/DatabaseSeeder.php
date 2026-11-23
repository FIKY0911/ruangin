<?php

namespace Database\Seeders;

use App\Models\ClassSession;
use App\Models\Lecturer;
use App\Models\SessionChange;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * SYNTHETIC demo data — a copy of app/lib/data/fixtures/seed_data.dart.
 * Every name, room and schedule is made up. Session dates are relative to
 * "today" (dayOffset), so re-seed (php artisan ruangin:reset-demo) on the
 * day of a demo.
 *
 * All demo accounts use the password "ruangin123".
 */
class DatabaseSeeder extends Seeder
{
    private const DEMO_PASSWORD = 'ruangin123';

    private const LECTURERS = [
        ['id' => 'l-rina', 'name' => 'Dr. Rina Kartika, M.Kom.', 'prodi' => 'Teknik Informatika', 'faculty' => 'Fakultas Teknologi Informasi'],
        ['id' => 'l-andi', 'name' => 'Andi Pratama, M.T.', 'prodi' => 'Teknik Informatika', 'faculty' => 'Fakultas Teknologi Informasi'],
        ['id' => 'l-dewi', 'name' => 'Dewi Lestari, M.Kom.', 'prodi' => 'Sistem Informasi', 'faculty' => 'Fakultas Teknologi Informasi'],
        ['id' => 'l-budi', 'name' => 'Budi Santoso, S.E., M.M.', 'prodi' => 'Manajemen', 'faculty' => 'Fakultas Ekonomi dan Bisnis'],
        ['id' => 'l-siti', 'name' => 'Siti Rahmawati, S.E., M.Ak.', 'prodi' => 'Akuntansi', 'faculty' => 'Fakultas Ekonomi dan Bisnis'],
        ['id' => 'l-rinaldi', 'name' => 'Ahmad Rinaldi, M.T.', 'prodi' => 'Teknik Elektro', 'faculty' => 'Fakultas Teknik'],
    ];

    private const ACCOUNTS = [
        ['id' => 'a-nadia', 'email' => 'nadia@demo.ruangin.id', 'name' => 'Nadia Putri', 'role' => 'mahasiswa', 'subtitle' => 'Mahasiswa Manajemen'],
        ['id' => 'a-raka', 'email' => 'raka@demo.ruangin.id', 'name' => 'Raka Wijaya', 'role' => 'mahasiswa', 'subtitle' => 'Mahasiswa Akuntansi'],
        ['id' => 'a-rina', 'email' => 'rina@demo.ruangin.id', 'name' => 'Dr. Rina Kartika', 'role' => 'dosen', 'subtitle' => 'Dosen Teknik Informatika', 'lecturer_id' => 'l-rina'],
        ['id' => 'a-hendra', 'email' => 'hendra@demo.ruangin.id', 'name' => 'Hendra Gunawan', 'role' => 'petugas', 'subtitle' => 'Petugas akademik FTI', 'scope_prodi' => ['Teknik Informatika', 'Sistem Informasi']],
    ];

    private const SESSIONS = [
        ['id' => 's-mobile-today', 'lecturer_id' => 'l-rina', 'course' => 'Pemrograman Mobile', 'prodi' => 'Teknik Informatika', 'day' => 0, 'start' => '07:30', 'end' => '10:00', 'room' => 'Ruang 306', 'attendanceAt' => '07:34'],
        ['id' => 's-basdat-today', 'lecturer_id' => 'l-rina', 'course' => 'Basis Data Lanjut', 'prodi' => 'Sistem Informasi', 'day' => 0, 'start' => '13:00', 'end' => '15:30', 'room' => 'Ruang 201'],
        ['id' => 's-ai-today', 'lecturer_id' => 'l-rina', 'course' => 'Kecerdasan Buatan', 'prodi' => 'Teknik Informatika', 'day' => 0, 'start' => '10:30', 'end' => '12:00', 'room' => 'Lab Komputer 2'],
        ['id' => 's-mobile-tomorrow', 'lecturer_id' => 'l-rina', 'course' => 'Pemrograman Mobile', 'prodi' => 'Teknik Informatika', 'day' => 1, 'start' => '07:30', 'end' => '10:00', 'room' => 'Ruang 306'],
        ['id' => 's-sim-yesterday', 'lecturer_id' => 'l-rina', 'course' => 'Sistem Informasi Manajemen', 'prodi' => 'Manajemen', 'day' => -1, 'start' => '09:00', 'end' => '11:00', 'room' => 'Ruang 105', 'attendanceAt' => '09:03'],
        ['id' => 's-jarkom-today', 'lecturer_id' => 'l-andi', 'course' => 'Jaringan Komputer', 'prodi' => 'Teknik Informatika', 'day' => 0, 'start' => '08:00', 'end' => '10:30', 'room' => 'Ruang 404', 'cancelled' => true, 'cancelNote' => 'Dibatalkan petugas: dosen dinas luar (sintetis)'],
        ['id' => 's-strukdat-today', 'lecturer_id' => 'l-andi', 'course' => 'Struktur Data', 'prodi' => 'Teknik Informatika', 'day' => 0, 'start' => '13:00', 'end' => '14:40', 'room' => 'Ruang 306'],
        ['id' => 's-apb-today', 'lecturer_id' => 'l-dewi', 'course' => 'Analisis Proses Bisnis', 'prodi' => 'Sistem Informasi', 'day' => 0, 'start' => '09:00', 'end' => '11:30', 'room' => 'Ruang 210', 'attendanceAt' => '09:06'],
        ['id' => 's-pm-today', 'lecturer_id' => 'l-budi', 'course' => 'Pengantar Manajemen', 'prodi' => 'Manajemen', 'day' => 0, 'start' => '08:00', 'end' => '09:40', 'room' => 'Ruang 101'],
        ['id' => 's-akb-tomorrow', 'lecturer_id' => 'l-siti', 'course' => 'Akuntansi Biaya', 'prodi' => 'Akuntansi', 'day' => 1, 'start' => '10:00', 'end' => '12:30', 'room' => 'Ruang 103'],
        ['id' => 's-elda-later', 'lecturer_id' => 'l-rinaldi', 'course' => 'Elektronika Dasar', 'prodi' => 'Teknik Elektro', 'day' => 2, 'start' => '08:00', 'end' => '10:30', 'room' => 'Lab Elektro 1'],
    ];

    public function run(): void
    {
        foreach (self::LECTURERS as $l) {
            Lecturer::create($l);
        }

        foreach (self::ACCOUNTS as $a) {
            $user = new User([
                'id' => $a['id'],
                'name' => $a['name'],
                'email' => $a['email'],
                'password' => self::DEMO_PASSWORD,
                'subtitle' => $a['subtitle'],
            ]);
            // Server-only fields (not mass assignable).
            $user->forceFill([
                'role' => $a['role'],
                'lecturer_id' => $a['lecturer_id'] ?? null,
                'scope_prodi' => $a['scope_prodi'] ?? null,
            ])->save();
        }

        $today = now()->startOfDay();
        $at = fn (int $day, string $hhmm) => $today->copy()->addDays($day)->setTimeFromTimeString($hhmm);

        foreach (self::SESSIONS as $s) {
            $created = $at($s['day'] - 7, '06:00');
            $source = config('ruangin.schedule_source');
            $updatedAt = $created;
            $history = [[$created, 'Sistem', 'Jadwal diimpor dari data prodi (sintetis)']];
            $attendanceAt = null;

            if (isset($s['attendanceAt'])) {
                $attendanceAt = $at($s['day'], $s['attendanceAt']);
                $updatedAt = $attendanceAt;
                $source = config('ruangin.attendance_source');
                $history[] = [$attendanceAt, 'Sinkron absensi', 'Kehadiran kelas tercatat di sistem absensi'];
            }

            $cancelled = $s['cancelled'] ?? false;
            if ($cancelled) {
                $updatedAt = $at($s['day'], '06:30');
                $source = 'Petugas akademik (sintetis)';
                $history[] = [$updatedAt, 'Petugas akademik', $s['cancelNote'] ?? 'Sesi dibatalkan'];
            }

            $session = new ClassSession([
                'id' => $s['id'],
                'lecturer_id' => $s['lecturer_id'],
                // Id in the simulated campus attendance system (P08).
                'external_id' => 'ABS-'.strtoupper(substr($s['id'], 2)),
                'course_name' => $s['course'],
                'prodi' => $s['prodi'],
                'start_at' => $at($s['day'], $s['start']),
                'end_at' => $at($s['day'], $s['end']),
                'room' => $s['room'],
                'source' => $source,
                'is_cancelled' => $cancelled,
                'attendance_recorded_at' => $attendanceAt,
                'attendance_source' => $attendanceAt ? config('ruangin.attendance_source') : null,
            ]);
            $session->created_at = $created;
            $session->updated_at = $updatedAt;
            $session->save();

            foreach ($history as [$when, $actor, $text]) {
                SessionChange::create([
                    'class_session_id' => $session->id,
                    'at' => $when,
                    'actor' => $actor,
                    'description' => $text,
                ]);
            }
        }
    }
}
