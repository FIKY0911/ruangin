<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\User;
use App\Services\EarlyWarningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * End-to-end checks of the PRD §8 demo scenario and the P0 business rules,
 * against the synthetic seed (dates relative to the frozen "now").
 */
class RuanginApiTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    protected function setUp(): void
    {
        // Monday 23 Nov 2026, 09:45 WIB: Rina's "Pemrograman Mobile" (07.30–10.00) is running.
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
        return $this->postJson('/api/auth/login', ['email' => $email, 'password' => 'ruangin123'])
            ->assertOk()
            ->json('token');
    }

    /** Switch user: Sanctum caches the resolved user per guard between test requests. */
    private function tok(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    private function as(string $email): static
    {
        return $this->tok($this->tokenFor($email));
    }

    private function version(string $sessionId): int
    {
        return ClassSession::findOrFail($sessionId)->version;
    }

    public function test_login_returns_token_and_server_role(): void
    {
        $this->postJson('/api/auth/login', ['email' => ' HENDRA@demo.ruangin.id ', 'password' => 'ruangin123'])
            ->assertOk()
            ->assertJsonPath('account.role', 'petugas')
            ->assertJsonPath('account.scopeProdi', ['Teknik Informatika', 'Sistem Informasi'])
            ->assertJsonStructure(['token', 'tokenType', 'account' => ['id', 'name', 'email', 'role', 'subtitle', 'lecturerId', 'scopeProdi', 'points']]);
    }

    public function test_login_errors_match_app_codes(): void
    {
        $this->postJson('/api/auth/login', ['email' => 'nobody@demo.ruangin.id', 'password' => 'x'])
            ->assertStatus(401)->assertJsonPath('code', 'accountNotFound')->assertJsonPath('errors.email.0', 'Akun tidak ditemukan.');
        $this->postJson('/api/auth/login', ['email' => 'nadia@demo.ruangin.id', 'password' => 'salah'])
            ->assertStatus(401)->assertJsonPath('code', 'wrongPassword');
        $this->postJson('/api/auth/login', ['email' => 'bukan-email', 'password' => ''])
            ->assertStatus(422)->assertJsonPath('code', 'invalidInput')
            ->assertJsonPath('errors.email.0', 'Format email tidak valid.')
            ->assertJsonPath('errors.password.0', 'Password wajib diisi.');
    }

    public function test_register_always_creates_mahasiswa_and_rejects_duplicates(): void
    {
        $this->postJson('/api/auth/register', [
            'email' => 'Budi.Baru@kampus.ac.id', 'password' => 'rahasia123', 'confirmPassword' => 'rahasia123', 'role' => 'petugas',
        ])->assertCreated()->assertJsonPath('data.role', 'mahasiswa')->assertJsonPath('data.name', 'budi.baru')
            ->assertJsonPath('data.email', 'budi.baru@kampus.ac.id');

        $this->postJson('/api/auth/register', [
            'email' => 'budi.baru@kampus.ac.id', 'password' => 'rahasia123', 'confirmPassword' => 'rahasia123',
        ])->assertStatus(422)->assertJsonPath('code', 'emailTaken');

        $this->postJson('/api/auth/register', ['email' => 'x@y.id', 'password' => 'pendek', 'confirmPassword' => 'beda'])
            ->assertStatus(422)
            ->assertJsonPath('errors.password.0', 'Password minimal 8 karakter.')
            ->assertJsonPath('errors.confirmPassword.0', 'Konfirmasi password tidak sama.');
    }

    public function test_endpoints_require_token_and_logout_revokes_it(): void
    {
        $this->getJson('/api/lecturers')->assertStatus(401)->assertJsonPath('code', 'unauthenticated');

        $token = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($token)->getJson('/api/auth/me')->assertOk()->assertJsonPath('data.id', 'a-nadia');
        $this->tok($token)->postJson('/api/auth/logout')->assertNoContent();
        $this->app['auth']->forgetGuards();
        $this->tok($token)->getJson('/api/auth/me')->assertStatus(401);
    }

    public function test_search_is_case_insensitive_partial_and_shows_prodi(): void
    {
        // "RINA" matches "Dr. Rina Kartika" and "Ahmad Rinaldi" (sorted by name).
        $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers?q=RINA')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', 'l-rinaldi')
            ->assertJsonPath('data.1.id', 'l-rina')
            ->assertJsonPath('data.1.prodi', 'Teknik Informatika');
        $this->getJson('/api/lecturers?q=kartika')->assertJsonCount(1, 'data');

        $this->getJson('/api/lecturers')->assertJsonCount(6, 'data');
        $this->getJson('/api/lecturers?q=%25')->assertJsonCount(0, 'data');
    }

    public function test_timeline_is_cross_prodi_sorted_with_derived_status(): void
    {
        $res = $this->as('nadia@demo.ruangin.id')->getJson('/api/lecturers/l-rina/timeline?date=2026-11-23')->assertOk();

        $this->assertSame(['s-mobile-today', 's-ai-today', 's-basdat-today'], array_column($res->json('data'), 'id'));
        $this->assertSame(['Teknik Informatika', 'Sistem Informasi'], array_values(array_unique(array_column($res->json('data'), 'prodi'))));
        $res->assertJsonPath('data.0.status', 'tercatat')
            ->assertJsonPath('data.0.statusLabel', 'Tercatat · Sinkron absensi 07.34')
            ->assertJsonPath('data.0.start', '2026-11-23T07:30:00+07:00')
            ->assertJsonPath('data.2.status', 'belumTerkonfirmasi');

        $this->getJson('/api/sessions/s-jarkom-today')->assertJsonPath('data.status', 'batal');
    }

    /** PRD §8 steps 1–5. */
    public function test_demo_scenario_move_room_notifies_follower(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $hendra = $this->tokenFor('hendra@demo.ruangin.id');

        $this->tok($nadia)->putJson('/api/sessions/s-mobile-today/follow')->assertOk();
        $this->tok($nadia)->putJson('/api/sessions/s-mobile-today/follow')->assertOk(); // idempotent
        $this->assertSame(1, User::find('a-nadia')->followedSessions()->count());

        $v = $this->version('s-mobile-today');
        $this->tok($hendra)->postJson('/api/sessions/s-mobile-today/room', ['version' => $v, 'room' => 'Ruang 402'])
            ->assertOk()
            ->assertJsonPath('data.room', 'Ruang 402')
            ->assertJsonPath('data.version', $v + 1)
            ->assertJsonPath('data.source', 'Petugas akademik · Hendra Gunawan')
            ->assertJsonPath('data.history.2.description', 'Ruang dipindah: Ruang 306 → Ruang 402');

        $notes = $this->tok($nadia)->getJson('/api/me/notifications')->assertOk()
            ->assertJsonPath('unreadCount', 1)
            ->assertJsonPath('data.0.kind', 'sessionChanged')
            ->assertJsonPath('data.0.sessionId', 's-mobile-today')
            ->assertJsonPath('data.0.title', 'Pemrograman Mobile: Pindah ruang: Ruang 306 → Ruang 402')
            ->json('data');
        $this->assertStringContainsString('Senin, 23 Nov 2026 · 07.30–10.00 · Ruang 402', $notes[0]['body']);

        $this->tok($nadia)->postJson("/api/notifications/{$notes[0]['id']}/read")->assertJsonPath('data.isRead', true);
        $this->tok($nadia)->getJson('/api/sessions/s-mobile-today')
            ->assertJsonPath('data.room', 'Ruang 402')->assertJsonPath('data.isFollowed', true);

        // Someone else cannot read Nadia's notification.
        $this->tok($hendra)->postJson("/api/notifications/{$notes[0]['id']}/read")->assertNotFound();
    }

    public function test_edit_permissions_follow_role_and_scope(): void
    {
        $v = $this->version('s-pm-today'); // Manajemen: outside Hendra's scope
        $this->as('hendra@demo.ruangin.id')->postJson('/api/sessions/s-pm-today/room', ['version' => $v, 'room' => 'X'])
            ->assertForbidden()->assertJsonPath('code', 'forbidden');

        $this->as('nadia@demo.ruangin.id')->postJson('/api/sessions/s-basdat-today/cancel', ['version' => 1])->assertForbidden();

        // Rina may edit her own session even in another prodi, but not Andi's.
        $this->as('rina@demo.ruangin.id')->postJson('/api/sessions/s-basdat-today/attendance', ['version' => $this->version('s-basdat-today')])
            ->assertOk()->assertJsonPath('data.status', 'tercatat')->assertJsonPath('data.attendance.source', 'Dicatat dosen');
        $this->postJson('/api/sessions/s-strukdat-today/cancel', ['version' => $this->version('s-strukdat-today')])->assertForbidden();

        $this->getJson('/api/sessions?date=2026-11-23&editable=1')->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_stale_version_is_rejected_with_409(): void
    {
        $hendra = $this->tokenFor('hendra@demo.ruangin.id');
        $v = $this->version('s-strukdat-today');

        $this->tok($hendra)->postJson('/api/sessions/s-strukdat-today/room', ['version' => $v, 'room' => 'Ruang 500'])->assertOk();
        $this->tok($hendra)->postJson('/api/sessions/s-strukdat-today/room', ['version' => $v, 'room' => 'Ruang 600'])
            ->assertStatus(409)->assertJsonPath('code', 'staleVersion');
        $this->assertSame('Ruang 500', ClassSession::find('s-strukdat-today')->room);
    }

    public function test_edit_rules_match_app(): void
    {
        $hendra = $this->tokenFor('hendra@demo.ruangin.id');
        $id = 's-strukdat-today';

        $this->tok($hendra)->postJson("/api/sessions/{$id}/time", [
            'version' => $this->version($id), 'start' => '2026-11-23T14:00:00+07:00', 'end' => '2026-11-23T13:00:00+07:00',
        ])->assertStatus(422)->assertJsonPath('message', 'Jam selesai harus setelah jam mulai.');

        $this->tok($hendra)->postJson("/api/sessions/{$id}/time", [
            'version' => $this->version($id), 'start' => '2026-11-23T13:30:00+07:00', 'end' => '2026-11-23T15:10:00+07:00',
        ])->assertOk()->assertJsonPath('data.start', '2026-11-23T13:30:00+07:00');

        $this->tok($hendra)->postJson("/api/sessions/{$id}/room", ['version' => $this->version($id), 'room' => 'Ruang 306'])
            ->assertStatus(422)->assertJsonPath('message', 'Ruang tidak berubah.');

        $this->tok($hendra)->postJson("/api/sessions/{$id}/cancel", ['version' => $this->version($id)])->assertOk()
            ->assertJsonPath('data.status', 'batal');
        $this->tok($hendra)->postJson("/api/sessions/{$id}/attendance", ['version' => $this->version($id)])
            ->assertStatus(422)->assertJsonPath('message', 'Sesi batal tidak bisa dicatat hadir.');
    }

    /** PRD §8 step 8 + P10 points. */
    public function test_empty_room_report_flow_confirm_cancels_and_awards_points(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $raka = $this->tokenFor('raka@demo.ruangin.id');
        $hendra = $this->tokenFor('hendra@demo.ruangin.id');
        $id = 's-mobile-today';

        $this->tok($raka)->putJson("/api/sessions/{$id}/follow");
        $this->tok($nadia)->putJson('/api/sessions/s-ai-today/follow'); // later session of Rina today

        $reportId = $this->tok($nadia)->postJson("/api/sessions/{$id}/reports")->assertCreated()
            ->assertJsonPath('data.status', 'pending')->json('data.id');
        $this->tok($nadia)->postJson("/api/sessions/{$id}/reports")->assertOk()->assertJsonPath('data.id', $reportId); // one per user

        // Report never changes the status.
        $this->assertSame('tercatat', ClassSession::find($id)->status());
        $this->tok($raka)->getJson('/api/me/notifications')
            ->assertJsonPath('data.0.kind', 'emptyRoomReport')
            ->assertJsonPath('data.0.title', 'Pemrograman Mobile: laporan ruang kosong (belum dikonfirmasi)');
        // P11: follower of Rina's later session gets an early warning.
        $this->tok($nadia)->getJson('/api/me/notifications')
            ->assertJsonPath('data.0.kind', 'earlyWarning')
            ->assertJsonPath('data.0.sessionId', 's-ai-today');

        $this->tok($hendra)->postJson("/api/sessions/{$id}/reports")->assertForbidden();
        $this->tok($raka)->getJson('/api/reports')->assertForbidden();

        $this->tok($hendra)->getJson('/api/reports')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.reporterName', 'Nadia Putri');
        $this->travel(1)->minutes(); // so the newest notification sorts first
        $this->tok($hendra)->postJson("/api/reports/{$reportId}/confirm")->assertOk()
            ->assertJsonPath('data.status', 'confirmed')->assertJsonPath('data.pointsAwarded', 10)
            ->assertJsonPath('data.session.status', 'batal');
        $this->tok($hendra)->postJson("/api/reports/{$reportId}/confirm")->assertStatus(422)->assertJsonPath('code', 'alreadyResolved');

        $this->assertSame(10, User::find('a-nadia')->points);
        $this->tok($raka)->getJson('/api/me/notifications')->assertJsonPath('data.0.kind', 'sessionChanged')
            ->assertJsonPath('data.0.title', 'Pemrograman Mobile: Sesi dibatalkan (laporan ruang kosong dikonfirmasi)');
        $this->tok($nadia)->getJson('/api/me/notifications')->assertJsonPath('data.0.kind', 'reportResolved');
    }

    public function test_report_window_and_reject(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');

        $this->tok($nadia)->postJson('/api/sessions/s-basdat-today/reports') // 13.00, window opens 12.45
            ->assertStatus(422)->assertJsonPath('code', 'outsideWindow');

        $reportId = $this->tok($nadia)->postJson('/api/sessions/s-apb-today/reports')->assertCreated()->json('data.id');
        $this->as('rina@demo.ruangin.id')->postJson("/api/reports/{$reportId}/reject")->assertForbidden(); // not her session
        $this->as('hendra@demo.ruangin.id')->postJson("/api/reports/{$reportId}/reject")->assertOk()
            ->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.session.status', 'tercatat');
        $this->assertSame(0, User::find('a-nadia')->points);
    }

    public function test_attendance_sync_by_key_is_idempotent_and_notifies(): void
    {
        config(['ruangin.sync_key' => 'test-key']);
        $this->as('raka@demo.ruangin.id')->putJson('/api/sessions/s-pm-today/follow');
        $this->app['auth']->forgetGuards();

        $payload = ['records' => [
            ['externalId' => 'ABS-PM-TODAY', 'recordedAt' => '2026-11-23T08:04:00+07:00'],
            ['externalId' => 'ABS-JARKOM-TODAY'],
            ['externalId' => 'ABS-TIDAK-ADA'],
        ]];

        $this->withHeaders(['X-Sync-Key' => 'salah'])->postJson('/api/sync/attendance', $payload)->assertStatus(401);

        $this->withHeaders(['X-Sync-Key' => 'test-key'])->postJson('/api/sync/attendance', $payload)->assertOk()
            ->assertJsonPath('recorded', 1)
            ->assertJsonPath('results.0.status', 'recorded')
            ->assertJsonPath('results.1.status', 'cancelled')
            ->assertJsonPath('results.2.status', 'notFound');
        $this->withHeaders(['X-Sync-Key' => 'test-key'])->postJson('/api/sync/attendance', $payload)
            ->assertJsonPath('results.0.status', 'alreadyRecorded');

        $session = ClassSession::find('s-pm-today');
        $this->assertSame('Tercatat · Sinkron absensi 08.04', $session->statusLabel());
        $this->assertSame(1, AppNotification::where('recipient_id', 'a-raka')->where('title', 'Pengantar Manajemen: Kelas tercatat berjalan · 08.04')->count());
    }

    public function test_attendance_sync_by_officer_respects_scope(): void
    {
        $this->as('hendra@demo.ruangin.id')->postJson('/api/sync/attendance', ['records' => [
            ['sessionId' => 's-strukdat-today'],
            ['sessionId' => 's-pm-today'],
        ]])->assertOk()
            ->assertJsonPath('results.0.status', 'recorded')
            ->assertJsonPath('results.1.status', 'forbidden');
    }

    public function test_early_warning_job_warns_followers_of_later_sessions_once(): void
    {
        // Andi has no unconfirmed earlier session (08.00 is cancelled); Budi has no later one.
        // Make Rina's morning session unconfirmed to trigger a warning for her 10.30 / 13.00 sessions.
        ClassSession::whereKey('s-mobile-today')->update(['attendance_recorded_at' => null]);
        $this->as('raka@demo.ruangin.id')->putJson('/api/sessions/s-basdat-today/follow');

        $service = app(EarlyWarningService::class);
        $this->assertSame(1, $service->run());
        $this->assertSame(0, $service->run()); // once only

        $this->getJson('/api/me/notifications')
            ->assertJsonPath('data.0.kind', 'earlyWarning')
            ->assertJsonPath('data.0.title', 'Basis Data Lanjut: peringatan dini');
        $this->artisan('ruangin:early-warnings')->assertSuccessful();
    }

    public function test_follows_list_and_unfollow_is_idempotent(): void
    {
        $nadia = $this->tokenFor('nadia@demo.ruangin.id');
        $this->tok($nadia)->putJson('/api/sessions/s-ai-today/follow');
        $this->tok($nadia)->getJson('/api/me/follows')->assertJsonPath('sessionIds', ['s-ai-today'])
            ->assertJsonPath('data.0.isFollowed', true);
        $this->tok($nadia)->deleteJson('/api/sessions/s-ai-today/follow')->assertOk();
        $this->tok($nadia)->deleteJson('/api/sessions/s-ai-today/follow')->assertOk();
        $this->tok($nadia)->getJson('/api/me/follows')->assertJsonPath('sessionIds', []);
        $this->tok($nadia)->putJson('/api/sessions/tidak-ada/follow')->assertNotFound()->assertJsonPath('code', 'notFound');
    }
}
