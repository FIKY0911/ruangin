<?php

namespace Database\Seeders;

use App\Models\ClassSession;
use App\Models\Lecturer;
use App\Models\Room;
use App\Models\Semester;
use App\Models\SessionChange;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Seeder;

/**
 * SYNTHETIC demo data — a copy of app/lib/data/fixtures/seed_data.dart.
 * Every name, room and schedule is made up. Session dates are relative to
 * "today" (dayOffset), so re-seed (php artisan ruangin:reset-demo) on the
 * day of a demo.
 *
 * All demo accounts use the password "ruangin123".
 *
 * Besides the hand-written sessions below (the demo scenario), every session
 * also repeats weekly through the active semester (14 weeks, today in week
 * 11), so the per-semester attendance summary has history. Repeats never fall
 * in the same week as the hand-written ones' dates, and their attendance is a
 * fixed synthetic pattern (mostly "Tercatat", some "Belum terkonfirmasi",
 * a few "Batal").
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

    /** Synthetic room catalog: which building each room is in. */
    private const ROOMS = [
        'Ruang 101' => 'Gedung A', 'Ruang 103' => 'Gedung A', 'Ruang 105' => 'Gedung A',
        'Ruang 201' => 'Gedung B', 'Ruang 210' => 'Gedung B',
        'Ruang 306' => 'Gedung C', 'Lab Komputer 2' => 'Gedung C',
        'Ruang 402' => 'Gedung D', 'Ruang 404' => 'Gedung D',
        'Lab Elektro 1' => 'Gedung Teknik',
    ];

    /** Active semester: 14 weeks, today in week 11. */
    public const SEMESTER_WEEKS = 14;

    public const SEMESTER_CURRENT_WEEK = 11;

    public function run(): void
    {
        foreach (self::ROOMS as $name => $building) {
            Room::create(['name' => $name, 'building' => $building]);
        }

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

        $semesterStart = $today->copy()->startOfWeek(CarbonInterface::MONDAY)->subWeeks(self::SEMESTER_CURRENT_WEEK - 1);
        $semesterEnd = $semesterStart->copy()->addWeeks(self::SEMESTER_WEEKS)->subDay();
        Semester::create([
            'id' => 'sem-demo',
            'name' => self::semesterName($semesterStart),
            'starts_on' => $semesterStart->toDateString(),
            'ends_on' => $semesterEnd->toDateString(),
        ]);

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
                'building' => self::ROOMS[$s['room']] ?? null,
                'source' => $source,
                'is_cancelled' => $cancelled,
                'attendance_recorded_at' => $attendanceAt,
                'attendance_source' => $attendanceAt ? config('ruangin.attendance_source') : null,
            ]);
            $session->created_at = $created;
            $session->updated_at = $updatedAt;
            $session->save();

            $this->history($session, $history);

            $this->seedWeeklyRepeats($s, $at, $semesterStart, $semesterEnd);
        }
    }

    /**
     * Weekly occurrences of a hand-written session, ±7·k days (k ≠ 0) inside
     * the semester. Past ones get a deterministic synthetic attendance mark.
     */
    private function seedWeeklyRepeats(array $s, \Closure $at, CarbonInterface $from, CarbonInterface $to): void
    {
        $now = now();
        for ($k = -self::SEMESTER_WEEKS; $k <= self::SEMESTER_WEEKS; $k++) {
            if ($k === 0) {
                continue;
            }
            $day = $s['day'] + 7 * $k;
            $start = $at($day, $s['start']);
            $end = $at($day, $s['end']);
            if ($start->lt($from) || $start->gt($to->copy()->endOfDay())) {
                continue;
            }

            $id = $s['id'].($k < 0 ? '-m' : '-p').abs($k);
            $created = $at($day - 7, '06:00');
            $history = [[$created, 'Sistem', 'Jadwal diimpor dari data prodi (sintetis)']];
            $source = config('ruangin.schedule_source');
            $updatedAt = $created;
            $cancelled = false;
            $attendanceAt = null;

            if ($end->lte($now)) {
                // 1 in 12 cancelled, 1 in 12 left without a record, rest recorded.
                $roll = crc32($id) % 12;
                if ($roll === 0) {
                    $cancelled = true;
                    $updatedAt = $at($day, '06:30');
                    $source = 'Petugas akademik (sintetis)';
                    $history[] = [$updatedAt, 'Petugas akademik', 'Dibatalkan petugas (sintetis)'];
                } elseif ($roll !== 1) {
                    $attendanceAt = $start->copy()->addMinutes(3 + crc32($id.'t') % 6);
                    $updatedAt = $attendanceAt;
                    $source = config('ruangin.attendance_source');
                    $history[] = [$attendanceAt, 'Sinkron absensi', 'Kehadiran kelas tercatat di sistem absensi'];
                }
            }

            $session = new ClassSession([
                'id' => $id,
                'lecturer_id' => $s['lecturer_id'],
                'external_id' => 'ABS-'.strtoupper(substr($id, 2)),
                'course_name' => $s['course'],
                'prodi' => $s['prodi'],
                'start_at' => $start,
                'end_at' => $end,
                'room' => $s['room'],
                'building' => self::ROOMS[$s['room']] ?? null,
                'source' => $source,
                'is_cancelled' => $cancelled,
                'attendance_recorded_at' => $attendanceAt,
                'attendance_source' => $attendanceAt ? config('ruangin.attendance_source') : null,
            ]);
            $session->created_at = $created;
            $session->updated_at = $updatedAt;
            $session->save();

            $this->history($session, $history);
        }
    }

    /** @param list<array{0: CarbonInterface, 1: string, 2: string}> $history */
    private function history(ClassSession $session, array $history): void
    {
        foreach ($history as [$when, $actor, $text]) {
            SessionChange::create([
                'class_session_id' => $session->id,
                'at' => $when,
                'actor' => $actor,
                'description' => $text,
            ]);
        }
    }

    /** "Semester Ganjil 2026/2027" (Aug–Jan start) or "Semester Genap 2026/2027" (Feb–Jul). */
    private static function semesterName(CarbonInterface $start): string
    {
        $m = $start->month;
        $y = $start->year;

        return match (true) {
            $m >= 8 => "Semester Ganjil {$y}/".($y + 1),
            $m === 1 => 'Semester Ganjil '.($y - 1)."/{$y}",
            default => 'Semester Genap '.($y - 1)."/{$y}",
        };
    }
}
