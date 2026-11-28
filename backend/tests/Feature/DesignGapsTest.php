<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\Lecturer;
use App\Models\Room;
use App\Models\Semester;
use App\Models\User;
use App\Services\EarlyWarningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Data for the latest mobile designs: building per room, per-semester
 * attendance, search by course/room, follow a lecturer, "Simulasi" label and
 * notification retention.
 */
class DesignGapsTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    protected function setUp(): void
    {
        // Monday 23 Nov 2026, 09:45 WIB (same frozen clock as the other suites).
        // Seeded semester: Mon 14 Sep 2026 – Sun 20 Dec 2026 (14 weeks, now in week 11).
        Carbon::setTestNow(Carbon::parse('2026-11-23 09:45:00', 'Asia/Jakarta'));
        parent::setUp();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function tokenFor(string $email): string
    {
        $this->app['auth']->forgetGuards();

        return $this->postJson('/api/auth/login', ['email' => $email, 'password' => 'ruangin123'])
            ->assertOk()
            ->json('token');
    }

    private function tok(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    private function as(string $email): static
    {
        return $this->tok($this->tokenFor($email));
    }

    /** @return list<string> notification kinds of $email, newest first */
    private function kindsFor(string $email): array
    {
        return AppNotification::where('recipient_id', User::where('email', $email)->value('id'))
            ->orderByDesc('created_at')->orderByDesc('id')->pluck('kind')->all();
    }

    private function makeSession(string $id, string $lecturerId, string $course, string $prodi, string $start, string $end, array $extra = []): ClassSession
    {
        $s = new ClassSession(array_merge([
            'id' => $id,
            'lecturer_id' => $lecturerId,
            'course_name' => $course,
            'prodi' => $prodi,
            'start_at' => Carbon::parse($start, 'Asia/Jakarta'),
            'end_at' => Carbon::parse($end, 'Asia/Jakarta'),
            'room' => 'Ruang 101',
            'building' => 'Gedung A',
            'source' => 'test',
        ], $extra));
        $s->save();

        return $s;
    }

    // ---- Gedung ---------------------------------------------------------------

    public function test_sessions_carry_the_building_of_their_room(): void
    {
        $this->assertSame('Gedung C', Room::buildingOf('Ruang 306'));
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');

        $this->tok($nadia)->getJson('/api/sessions/s-mobile-today')->assertOk()
            ->assertJsonPath('data.room', 'Ruang 306')
            ->assertJsonPath('data.building', 'Gedung C');
        $this->tok($nadia)->getJson('/api/lecturers/l-rina/timeline')->assertOk()
            ->assertJsonPath('data.0.building', 'Gedung C')   // 07.30 Ruang 306
            ->assertJsonPath('data.1.building', 'Gedung C')   // 10.30 Lab Komputer 2
            ->assertJsonPath('data.2.building', 'Gedung B');  // 13.00 Ruang 201
        $this->tok($nadia)->getJson('/api/sessions')->assertOk()->assertJsonStructure(['data' => [['building']]]);
    }

    public function test_changing_room_updates_building_from_catalog(): void
    {
        $hendra = $this->tokenFor('hendra@demo.ruangin.id');
        $v = fn () => ClassSession::find('s-mobile-today')->version;

        $this->tok($hendra)->postJson('/api/sessions/s-mobile-today/room', ['version' => $v(), 'room' => 'Ruang 402'])
            ->assertOk()->assertJsonPath('data.room', 'Ruang 402')->assertJsonPath('data.building', 'Gedung D');

        // Case-insensitive lookup; the room keeps the text that was typed.
        $this->tok($hendra)->postJson('/api/sessions/s-mobile-today/room', ['version' => $v(), 'room' => '  ruang 201 '])
            ->assertOk()->assertJsonPath('data.room', 'ruang 201')->assertJsonPath('data.building', 'Gedung B');

        // Not in the catalog: building unknown, never the old one.
        $this->tok($hendra)->postJson('/api/sessions/s-mobile-today/room', ['version' => $v(), 'room' => 'Aula Utama'])
            ->assertOk()->assertJsonPath('data.room', 'Aula Utama')->assertJsonPath('data.building', null);
    }

    // ---- Riwayat kehadiran per semester -------------------------------------

    public function test_attendance_requires_login_and_existing_lecturer(): void
    {
        $this->getJson('/api/lecturers/l-rina/attendance')->assertStatus(401)->assertJsonPath('code', 'unauthenticated');
        $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/tidak-ada/attendance')
            ->assertNotFound()->assertJsonPath('code', 'notFound');
    }

    public function test_active_semester_includes_its_first_and_last_day(): void
    {
        Semester::query()->delete();
        Semester::create(['id' => 'sem-x', 'name' => 'Semester X', 'starts_on' => '2026-11-23', 'ends_on' => '2026-11-27']);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');

        foreach (['2026-11-23 00:00:00', '2026-11-23 09:45:00', '2026-11-27 23:59:59'] as $now) {
            Carbon::setTestNow(Carbon::parse($now, 'Asia/Jakarta'));
            $this->assertSame('sem-x', Semester::current()?->id, $now);
            $this->tok($nadia)->getJson('/api/lecturers/l-rina/attendance')->assertOk()
                ->assertJsonPath('data.semester.startsOn', '2026-11-23')
                ->assertJsonPath('data.semester.endsOn', '2026-11-27');
        }
        foreach (['2026-11-22 23:59:59', '2026-11-28 00:00:00'] as $now) {
            Carbon::setTestNow(Carbon::parse($now, 'Asia/Jakarta'));
            $this->assertNull(Semester::current(), $now);
        }
    }

    public function test_attendance_without_active_semester_is_not_found(): void
    {
        Semester::query()->delete();
        $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/l-rina/attendance')
            ->assertNotFound()->assertJsonPath('code', 'notFound')->assertJsonPath('message', 'Belum ada semester aktif.');
    }

    public function test_seeded_attendance_covers_the_semester_and_matches_the_prd_rule(): void
    {
        $res = $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/l-rina/attendance')->assertOk()
            ->assertJsonPath('data.lecturer.id', 'l-rina')
            ->assertJsonPath('data.semester.name', 'Semester Ganjil 2026/2027')
            ->assertJsonPath('data.semester.startsOn', '2026-09-14')
            ->assertJsonPath('data.semester.endsOn', '2026-12-20')
            ->json('data');

        $now = now();
        $expected = ['tercatat' => 0, 'belumTerkonfirmasi' => 0, 'batal' => 0, 'belumBerlangsung' => 0];
        $inSemester = ClassSession::where('lecturer_id', 'l-rina')
            ->whereBetween('start_at', [Carbon::parse('2026-09-14 00:00', 'Asia/Jakarta'), Carbon::parse('2026-12-20 23:59:59', 'Asia/Jakarta')])
            ->get();
        foreach ($inSemester as $s) {
            $mark = match (true) {
                $s->is_cancelled => 'batal',
                $s->attendance_recorded_at !== null => 'tercatat',
                $s->end_at->gt($now) => 'belumBerlangsung',
                default => 'belumTerkonfirmasi',
            };
            $expected[$mark]++;
        }
        $this->assertGreaterThan(40, $inSemester->count()); // weekly repeats exist
        $this->assertGreaterThan(0, $expected['tercatat']);
        $this->assertGreaterThan(0, $expected['belumBerlangsung']);

        $summary = $res['summary'];
        foreach ($expected as $k => $n) {
            $this->assertSame($n, $summary[$k], $k);
        }
        $this->assertSame($inSemester->count(), $summary['total']);
        $counted = $expected['tercatat'] + $expected['belumTerkonfirmasi'];
        $this->assertSame($counted, $summary['counted']);
        $this->assertEqualsWithDelta($expected['tercatat'] / $counted, $summary['rate'], 0.0001);

        // Courses add up to the total; meetings are numbered 1..n in time order.
        $meetings = collect($res['courses'])->flatMap(fn ($c) => $c['meetings']);
        $this->assertSame($summary['total'], $meetings->count());
        foreach ($res['courses'] as $course) {
            $this->assertSame(range(1, count($course['meetings'])), array_column($course['meetings'], 'number'));
            $starts = array_column($course['meetings'], 'start');
            $sorted = $starts;
            sort($sorted);
            $this->assertSame($sorted, $starts);
            $this->assertSame(count($course['meetings']), $course['summary']['total']);
        }
        $this->assertSame([], $meetings->pluck('status')->diff(['tercatat', 'belumTerkonfirmasi', 'batal', 'belumBerlangsung'])->values()->all());

        $byId = $meetings->keyBy('sessionId');
        $this->assertSame('tercatat', $byId['s-mobile-today']['status']);        // running, recorded 07.34
        $this->assertSame('belumBerlangsung', $byId['s-basdat-today']['status']); // 13.00 later today
        $this->assertSame('belumBerlangsung', $byId['s-ai-today']['status']);     // 10.30, no record yet
        $this->assertSame('tercatat', $byId['s-sim-yesterday']['status']);
        $this->assertSame('Gedung C', $byId['s-mobile-today']['building']);
        // Pemrograman Mobile meets twice a week (Monday + Tuesday) in this demo.
        $mobile = collect($res['courses'])->firstWhere('courseName', 'Pemrograman Mobile');
        $this->assertSame(28, $mobile['summary']['total']);
    }

    public function test_attendance_counts_exactly_and_never_marks_missing_records_absent(): void
    {
        Lecturer::create(['id' => 'l-test', 'name' => 'Dosen Uji', 'prodi' => 'Teknik Informatika', 'faculty' => 'FTI']);
        $this->makeSession('s-t1', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-11-16 08:00', '2026-11-16 10:00', ['attendance_recorded_at' => Carbon::parse('2026-11-16 08:05', 'Asia/Jakarta')]);
        $this->makeSession('s-t2', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-11-18 08:00', '2026-11-18 10:00'); // finished, no record
        $this->makeSession('s-t3', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-11-20 08:00', '2026-11-20 10:00', ['is_cancelled' => true]);
        $this->makeSession('s-t4', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-11-23 09:00', '2026-11-23 11:00'); // running, no record
        $this->makeSession('s-t5', 'l-test', 'Algoritma', 'Sistem Informasi', '2026-11-30 08:00', '2026-11-30 10:00'); // future, other prodi
        $this->makeSession('s-t0', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-09-07 08:00', '2026-09-07 10:00'); // before semester
        $this->makeSession('s-t9', 'l-test', 'Algoritma', 'Teknik Informatika', '2026-12-21 08:00', '2026-12-21 10:00'); // after semester

        $data = $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/l-test/attendance')->assertOk()->json('data');

        $this->assertSame([
            'total' => 5, 'tercatat' => 1, 'belumTerkonfirmasi' => 1, 'batal' => 1,
            'belumBerlangsung' => 2, 'counted' => 2, 'rate' => 0.5,
        ], $data['summary']);
        // Same course name in two prodi = two courses (sorted by course, then prodi).
        $this->assertSame(['Sistem Informasi', 'Teknik Informatika'], array_column($data['courses'], 'prodi'));
        $this->assertSame(
            ['s-t1' => 'tercatat', 's-t2' => 'belumTerkonfirmasi', 's-t3' => 'batal', 's-t4' => 'belumBerlangsung'],
            array_column($data['courses'][1]['meetings'], 'status', 'sessionId'),
        );
        $this->assertSame([1, 2, 3, 4], array_column($data['courses'][1]['meetings'], 'number'));
        $this->assertSame(4, $data['courses'][1]['summary']['total']);
        $this->assertSame(1, $data['courses'][0]['meetings'][0]['number']);
        $this->assertNull($data['courses'][0]['summary']['rate']); // only an upcoming session

        // A late attendance record turns "Belum terkonfirmasi" into "Tercatat".
        $this->postJson('/api/sync/attendance', ['records' => [['sessionId' => 's-t2']]], ['X-Sync-Key' => 'k'])->assertStatus(401);
        config(['ruangin.sync_key' => 'k']);
        $this->postJson('/api/sync/attendance', ['records' => [['sessionId' => 's-t2']]], ['X-Sync-Key' => 'k'])->assertOk();
        $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/l-test/attendance')
            ->assertJsonPath('data.summary.tercatat', 2)
            ->assertJsonPath('data.summary.belumTerkonfirmasi', 0)
            ->assertJsonPath('data.summary.rate', 1);
    }

    public function test_attendance_of_lecturer_without_sessions_is_empty(): void
    {
        Lecturer::create(['id' => 'l-baru', 'name' => 'Dosen Baru', 'prodi' => 'Akuntansi', 'faculty' => 'FEB']);
        $this->as('raka@demo.ruangin.id')->getJson('/api/lecturers/l-baru/attendance')->assertOk()
            ->assertJsonPath('data.summary.total', 0)
            ->assertJsonPath('data.summary.counted', 0)
            ->assertJsonPath('data.summary.rate', null)
            ->assertJsonPath('data.courses', []);
    }

    // ---- Cari dosen, mata kuliah, sesi ---------------------------------------

    public function test_search_validates_query_and_requires_login(): void
    {
        $this->getJson('/api/search?q=rina')->assertStatus(401);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($nadia)->getJson('/api/search')->assertStatus(422)
            ->assertJsonPath('code', 'invalidInput')->assertJsonPath('errors.q.0', 'Kata kunci wajib diisi.');
        $this->tok($nadia)->getJson('/api/search?q=%20%20')->assertStatus(422)->assertJsonPath('code', 'invalidInput');
        $this->tok($nadia)->getJson('/api/search?q='.str_repeat('a', 101))->assertStatus(422)
            ->assertJsonPath('errors.q.0', 'Kata kunci maksimal 100 karakter.');
    }

    public function test_search_finds_lecturers_by_partial_name(): void
    {
        $this->as('nadia@demo.ruangin.id')->getJson('/api/search?q=RINA')->assertOk()
            ->assertJsonPath('query', 'RINA')
            ->assertJsonPath('lecturers.0.name', 'Ahmad Rinaldi, M.T.')
            ->assertJsonPath('lecturers.1.name', 'Dr. Rina Kartika, M.Kom.')
            ->assertJsonPath('lecturers.1.prodi', 'Teknik Informatika')
            ->assertJsonCount(2, 'lecturers')
            ->assertJsonPath('sessions', []);
    }

    public function test_search_finds_sessions_by_course_within_the_coming_week(): void
    {
        $res = $this->as('nadia@demo.ruangin.id')->getJson('/api/search?q=mobile')->assertOk()
            ->assertJsonPath('lecturers', [])
            ->assertJsonPath('from', '2026-11-23')
            ->assertJsonPath('to', '2026-11-29');
        // Next week's repeat (30 Nov) and last week's ones are outside the window.
        $this->assertSame(['s-mobile-today', 's-mobile-tomorrow'], array_column($res->json('sessions'), 'id'));
        $res->assertJsonPath('sessions.0.lecturer.name', 'Dr. Rina Kartika, M.Kom.')
            ->assertJsonPath('sessions.0.building', 'Gedung C')
            ->assertJsonPath('sessions.0.status', 'tercatat');

        // Today's already-finished session is listed; yesterday's is not, its repeat on Sunday is.
        $ids = array_column($this->getJson('/api/search?q=manajemen')->assertOk()->json('sessions'), 'id');
        $this->assertSame(['s-pm-today', 's-sim-yesterday-p1'], $ids);
    }

    public function test_search_finds_sessions_by_room_and_shows_cancelled_ones(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->assertSame(
            ['s-mobile-today', 's-strukdat-today', 's-mobile-tomorrow'],
            array_column($this->tok($nadia)->getJson('/api/search?q=306')->assertOk()->json('sessions'), 'id'),
        );
        $this->tok($nadia)->getJson('/api/search?q=jaringan')->assertOk()
            ->assertJsonPath('sessions.0.id', 's-jarkom-today')
            ->assertJsonPath('sessions.0.status', 'batal');
    }

    public function test_search_treats_underscore_and_percent_literally(): void
    {
        $this->makeSession('s-lab1', 'l-andi', 'Praktikum 50% Daring', 'Teknik Informatika', '2026-11-24 08:00', '2026-11-24 10:00', ['room' => 'Lab_1']);
        $this->makeSession('s-labx', 'l-andi', 'Praktikum 500 Soal', 'Teknik Informatika', '2026-11-24 13:00', '2026-11-24 15:00', ['room' => 'Lab-1']);
        Lecturer::create(['id' => 'l-under', 'name' => 'Dosen_Uji', 'prodi' => 'Akuntansi', 'faculty' => 'FEB']);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $ids = fn (string $q) => array_column($this->tok($nadia)->getJson('/api/search?q='.urlencode($q))->assertOk()->json('sessions'), 'id');

        $this->assertSame(['s-lab1'], $ids('lab_1'));   // _ is not "any character"
        $this->assertSame(['s-labx'], $ids('lab-1'));
        $this->assertSame(['s-lab1'], $ids('50%'));     // % is not "anything"
        $this->assertSame(['s-lab1', 's-labx'], $ids('praktikum 50'));
        $this->assertSame([], $ids('lab!1'));            // the escape character itself is literal

        $this->tok($nadia)->getJson('/api/search?q=dosen_')->assertJsonPath('lecturers.0.id', 'l-under')->assertJsonCount(1, 'lecturers');
        $this->tok($nadia)->getJson('/api/lecturers?q=dosen_')->assertJsonPath('data.0.id', 'l-under')->assertJsonCount(1, 'data');
        $this->tok($nadia)->getJson('/api/lecturers?q=n_u')->assertJsonCount(1, 'data');   // "Dosen_Uji" only
        $this->tok($nadia)->getJson('/api/lecturers?q=a_')->assertJsonCount(0, 'data');    // no literal "a_" in any name
    }

    public function test_search_without_match_and_wildcards_return_nothing(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        foreach (['Zaydan', '%', '_'] as $q) {
            $this->tok($nadia)->getJson('/api/search?q='.urlencode($q))->assertOk()
                ->assertJsonPath('lecturers', [])
                ->assertJsonPath('sessions', []);
        }
    }

    // ---- Ikuti dosen ------------------------------------------------------------

    public function test_follow_lecturer_is_idempotent_and_listed(): void
    {
        $this->putJson('/api/lecturers/l-rina/follow')->assertStatus(401);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');

        $this->tok($nadia)->getJson('/api/lecturers/l-rina')->assertJsonPath('data.isFollowed', false);
        $this->tok($nadia)->putJson('/api/lecturers/l-rina/follow')->assertOk()
            ->assertJsonPath('lecturerId', 'l-rina')->assertJsonPath('isFollowed', true);
        $this->tok($nadia)->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $this->assertSame(1, DB::table('lecturer_follows')->count());

        $this->tok($nadia)->getJson('/api/lecturers/l-rina')->assertJsonPath('data.isFollowed', true);
        $this->tok($nadia)->getJson('/api/lecturers?q=rina')
            ->assertJsonPath('data.0.isFollowed', false)  // Ahmad Rinaldi
            ->assertJsonPath('data.1.isFollowed', true);
        $this->tok($nadia)->getJson('/api/me/followed-lecturers')->assertOk()
            ->assertJsonPath('lecturerIds', ['l-rina'])
            ->assertJsonPath('data.0.isFollowed', true);
        // Following a lecturer is per user.
        $this->as('raka@demo.ruangin.id')->getJson('/api/lecturers/l-rina')->assertJsonPath('data.isFollowed', false);

        $this->tok($nadia)->deleteJson('/api/lecturers/l-rina/follow')->assertOk()->assertJsonPath('isFollowed', false);
        $this->tok($nadia)->deleteJson('/api/lecturers/l-rina/follow')->assertOk();
        $this->tok($nadia)->getJson('/api/me/followed-lecturers')->assertJsonPath('lecturerIds', []);
        $this->tok($nadia)->putJson('/api/lecturers/tidak-ada/follow')->assertNotFound()->assertJsonPath('code', 'notFound');
    }

    public function test_lecturer_followers_are_notified_once_about_any_of_their_sessions(): void
    {
        $this->as('nadia@demo.ruangin.id')->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $raka = $this->tokenFor('raka@demo.ruangin.id');
        $this->tok($raka)->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $this->tok($raka)->putJson('/api/sessions/s-ai-today/follow')->assertOk(); // both ways: still one notification
        $this->as('raka@demo.ruangin.id')->putJson('/api/lecturers/l-andi/follow')->assertOk();

        $version = ClassSession::find('s-ai-today')->version;
        $this->as('hendra@demo.ruangin.id')
            ->postJson('/api/sessions/s-ai-today/room', ['version' => $version, 'room' => 'Ruang 404'])->assertOk();

        $this->assertSame(['sessionChanged'], $this->kindsFor('nadia@demo.ruangin.id'));
        $this->assertSame(['sessionChanged'], $this->kindsFor('raka@demo.ruangin.id'));
        $this->as('nadia@demo.ruangin.id')->getJson('/api/me/notifications')
            ->assertJsonPath('data.0.sessionId', 's-ai-today')
            ->assertJsonPath('data.0.title', 'Kecerdasan Buatan: Pindah ruang: Lab Komputer 2 → Ruang 404');
    }

    public function test_the_actor_is_not_notified_about_own_change_via_lecturer_follow(): void
    {
        $rina = $this->tokenFor('rina@demo.ruangin.id');
        $this->tok($rina)->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $version = ClassSession::find('s-ai-today')->version;
        $this->tok($rina)->postJson('/api/sessions/s-ai-today/room', ['version' => $version, 'room' => 'Ruang 210'])->assertOk();
        $this->assertSame([], $this->kindsFor('rina@demo.ruangin.id'));
    }

    public function test_reports_and_early_warnings_reach_lecturer_followers(): void
    {
        $this->as('raka@demo.ruangin.id')->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($nadia)->putJson('/api/lecturers/l-rina/follow')->assertOk();

        // Nadia reports the 07.30–10.00 session empty: Raka hears about it, the reporter does not.
        $this->tok($nadia)->postJson('/api/sessions/s-mobile-today/reports')->assertStatus(201);
        $raka = $this->kindsFor('raka@demo.ruangin.id');
        $this->assertSame(1, count(array_keys($raka, 'emptyRoomReport')));
        $this->assertNotContains('emptyRoomReport', $this->kindsFor('nadia@demo.ruangin.id'));
        // ...and both get the early warning for Rina's later sessions today (10.30 and 13.00).
        $this->assertSame(2, count(array_keys($raka, 'earlyWarning')));
        $this->assertSame(2, count(array_keys($this->kindsFor('nadia@demo.ruangin.id'), 'earlyWarning')));
    }

    public function test_report_and_warning_bodies_name_building_and_room(): void
    {
        $this->as('raka@demo.ruangin.id')->putJson('/api/lecturers/l-rina/follow')->assertOk();
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $report = $this->tok($nadia)->postJson('/api/sessions/s-mobile-today/reports')->assertStatus(201)->json('data.id');

        $body = fn (string $kind, string $user) => AppNotification::where('recipient_id', $user)->where('kind', $kind)->value('body');
        $this->assertStringContainsString('melaporkan Gedung C · Ruang 306 kosong', $body('emptyRoomReport', 'a-raka'));
        $this->assertStringContainsString('(Pemrograman Mobile, 07.30–10.00, Gedung C · Ruang 306) dilaporkan kosong', $body('earlyWarning', 'a-raka'));

        $this->as('hendra@demo.ruangin.id')->postJson("/api/reports/{$report}/confirm")->assertOk();
        $this->assertStringContainsString('di Gedung C · Ruang 306 dikonfirmasi', $body('reportResolved', 'a-nadia'));
    }

    public function test_reject_body_names_building_and_room(): void
    {
        $report = $this->as('nadia@demo.ruangin.id')->postJson('/api/sessions/s-mobile-today/reports')->assertStatus(201)->json('data.id');
        $this->as('hendra@demo.ruangin.id')->postJson("/api/reports/{$report}/reject")->assertOk();
        $this->assertStringContainsString(
            'di Gedung C · Ruang 306 ditolak',
            AppNotification::where('recipient_id', 'a-nadia')->where('kind', 'reportResolved')->value('body'),
        );
    }

    public function test_early_warning_job_reaches_lecturer_followers(): void
    {
        ClassSession::whereKey('s-mobile-today')->update(['attendance_recorded_at' => null]);
        $this->as('nadia@demo.ruangin.id')->putJson('/api/lecturers/l-rina/follow')->assertOk();

        $this->assertSame(2, app(EarlyWarningService::class)->run()); // 10.30 + 13.00
        $this->assertSame(['earlyWarning', 'earlyWarning'], $this->kindsFor('nadia@demo.ruangin.id'));
    }

    public function test_today_card_includes_sessions_of_followed_lecturers(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($nadia)->putJson('/api/lecturers/l-andi/follow')->assertOk();
        $this->tok($nadia)->putJson('/api/sessions/s-strukdat-today/follow')->assertOk(); // no duplicate
        $this->tok($nadia)->putJson('/api/sessions/s-pm-today/follow')->assertOk();

        $res = $this->tok($nadia)->getJson('/api/me/today')->assertOk();
        $this->assertSame(['s-jarkom-today', 's-pm-today', 's-strukdat-today'], array_column($res->json('data'), 'id'));
        // 08.00 Jarkom is cancelled and 08.00–09.40 PM has ended.
        $res->assertJsonPath('nextSessionId', 's-strukdat-today')
            ->assertJsonPath('data.0.isFollowed', false)
            ->assertJsonPath('data.0.lecturer.isFollowed', true);
    }

    // ---- "Simulasi" + masa simpan notifikasi ----------------------------------

    public function test_app_config_reports_simulated_data_and_retention(): void
    {
        $this->getJson('/api/app-config')->assertStatus(401);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($nadia)->getJson('/api/app-config')->assertOk()
            ->assertExactJson(['data' => ['simulatedData' => true, 'notificationRetentionDays' => 30]]);

        config(['ruangin.simulated_data' => false, 'ruangin.notification_retention_days' => 0]);
        $this->tok($nadia)->getJson('/api/app-config')->assertOk()
            ->assertExactJson(['data' => ['simulatedData' => false, 'notificationRetentionDays' => null]]);
    }

    private function notificationAgedDays(string $userId, string $id, int $days, ?Carbon $readAt = null): void
    {
        AppNotification::create([
            'id' => $id,
            'recipient_id' => $userId,
            'class_session_id' => 's-mobile-today',
            'kind' => 'sessionChanged',
            'title' => "Umur {$days} hari",
            'body' => '',
            'read_at' => $readAt,
            'created_at' => now()->subDays($days),
        ]);
    }

    public function test_notifications_older_than_retention_are_hidden(): void
    {
        $this->notificationAgedDays('a-nadia', 'n-old', 31);
        $this->notificationAgedDays('a-nadia', 'n-edge', 30); // exactly at the cutoff: kept
        $this->notificationAgedDays('a-nadia', 'n-new', 29);
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');

        $res = $this->tok($nadia)->getJson('/api/me/notifications')->assertOk()
            ->assertJsonPath('unreadCount', 2)
            ->assertJsonPath('retentionDays', 30);
        $this->assertSame(['n-new', 'n-edge'], array_column($res->json('data'), 'id'));
        $this->tok($nadia)->getJson('/api/me/notifications?unread=1')->assertJsonCount(2, 'data');
        $this->tok($nadia)->getJson('/api/me/today')->assertJsonPath('unreadCount', 2);

        config(['ruangin.notification_retention_days' => 0]);
        $this->tok($nadia)->getJson('/api/me/notifications')->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('unreadCount', 3)
            ->assertJsonPath('retentionDays', null);
    }

    private function notificationAt(string $id, Carbon $createdAt, ?Carbon $seenAt, string $userId = 'a-nadia'): void
    {
        AppNotification::create([
            'id' => $id,
            'recipient_id' => $userId,
            'class_session_id' => 's-mobile-today',
            'kind' => 'sessionChanged',
            'title' => $id,
            'body' => '',
            'seen_at' => $seenAt,
            'created_at' => $createdAt,
        ]);
    }

    public function test_prune_keeps_seen_notifications_from_test_run_days(): void
    {
        // A mode-uji test run on Wed 14 Oct 2026 (40 days ago), 10.00–10.05.
        $testDay = Carbon::parse('2026-10-14 10:00:00', 'Asia/Jakarta');
        \App\Models\TestRun::create([
            'user_id' => 'a-nadia', 'participant_code' => 'P01', 'task' => 'cari ruang', 'method' => 'ruangin',
            'started_at' => $testDay, 'finished_at' => $testDay->copy()->addMinutes(5),
        ]);
        $otherDay = Carbon::parse('2026-10-15 10:00:00', 'Asia/Jakarta');

        $this->notificationAt('n-test-seen', $testDay->copy()->addMinute(), $testDay->copy()->addMinute()->addSeconds(7));
        $this->notificationAt('n-test-seen-late', $testDay->copy()->setTime(23, 50), $testDay->copy()->setTime(23, 59), 'a-raka');
        $this->notificationAt('n-test-unseen', $testDay->copy()->addMinutes(2), null);
        $this->notificationAt('n-other-seen', $otherDay, $otherDay->copy()->addSeconds(3));
        $this->notificationAt('n-other-unseen', $otherDay, null);
        $this->notificationAt('n-recent-unseen', now()->subDays(2), null);

        $this->artisan('ruangin:prune-notifications')->assertSuccessful();

        $this->assertEqualsCanonicalizing(
            ['n-test-seen', 'n-test-seen-late', 'n-recent-unseen'],
            AppNotification::pluck('id')->all(),
        );
        // Kept for the report, but still hidden from the user's own list (older than 30 days).
        $this->as('nadia@demo.ruangin.id')->getJson('/api/me/notifications')
            ->assertJsonPath('data.0.id', 'n-recent-unseen')->assertJsonCount(1, 'data');

        // The latency report for the test day still has its data after the prune.
        $this->as('hendra@demo.ruangin.id')->getJson('/api/test/notification-latency?date=2026-10-14')->assertOk()
            ->assertJsonPath('summary.all.n', 2)
            ->assertJsonPath('data.1.notificationId', 'n-test-seen')
            ->assertJsonPath('data.1.latencySeconds', 7);
        $this->getJson('/api/test/notification-latency?date=2026-10-15')->assertOk()->assertJsonPath('summary.all.n', 0);
    }

    public function test_prune_without_test_runs_deletes_seen_and_unseen_old_rows(): void
    {
        $old = now()->subDays(31);
        $this->notificationAt('n-old-seen', $old, $old->copy()->addSeconds(5));
        $this->notificationAt('n-old-unseen', $old, null);
        $this->notificationAt('n-new-seen', now()->subDay(), now()->subDay());

        $this->artisan('ruangin:prune-notifications')->assertSuccessful();
        $this->assertSame(['n-new-seen'], AppNotification::pluck('id')->all());
    }

    public function test_prune_command_deletes_only_expired_notifications(): void
    {
        $this->notificationAgedDays('a-nadia', 'n-old', 45);
        $this->notificationAgedDays('a-raka', 'n-old-read', 31, now());
        $this->notificationAgedDays('a-nadia', 'n-new', 3);

        config(['ruangin.notification_retention_days' => 0]);
        $this->artisan('ruangin:prune-notifications')->assertSuccessful();
        $this->assertSame(3, AppNotification::count());

        config(['ruangin.notification_retention_days' => 30]);
        $this->artisan('ruangin:prune-notifications')->assertSuccessful();
        $this->assertSame(['n-new'], AppNotification::pluck('id')->all());

        $this->artisan('schedule:list')->expectsOutputToContain('ruangin:prune-notifications')->assertSuccessful();
    }
}
