<?php

namespace Tests\Feature;

use App\Models\AppNotification;
use App\Models\ClassSession;
use App\Models\DeviceToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** Demo panel, mode uji, P07 push, P12 message draft, "Hari ini" card. */
class SystemFeaturesTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    protected function setUp(): void
    {
        // Monday 23 Nov 2026, 09:45 WIB (same frozen clock as RuanginApiTest).
        Carbon::setTestNow(Carbon::parse('2026-11-23 09:45:00', 'Asia/Jakarta'));
        parent::setUp();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function tok(string $email): static
    {
        $this->app['auth']->forgetGuards();
        $token = $this->postJson('/api/auth/login', ['email' => $email, 'password' => 'ruangin123'])->assertOk()->json('token');
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }

    public function test_today_card_lists_followed_sessions_and_next_one(): void
    {
        $this->tok('nadia@demo.ruangin.id');
        $this->putJson('/api/sessions/s-basdat-today/follow');
        $this->putJson('/api/sessions/s-mobile-today/follow');
        $this->putJson('/api/sessions/s-mobile-tomorrow/follow');

        $this->getJson('/api/me/today')->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', 's-mobile-today')
            ->assertJsonPath('nextSessionId', 's-mobile-today') // still running until 10.00
            ->assertJsonPath('date', '2026-11-23')
            ->assertJsonPath('points', 0);
    }

    public function test_message_draft_proposes_end_time_and_room(): void
    {
        $this->tok('nadia@demo.ruangin.id');

        $res = $this->getJson('/api/sessions/s-mobile-today/message-draft?purpose=meminta arahan lomba')->assertOk()
            ->assertJsonPath('proposedPlace', 'Ruang 306')
            ->assertJsonPath('proposedTime', '2026-11-23T10:00:00+07:00');
        $text = $res->json('text');
        $this->assertStringStartsWith('Selamat pagi, Bapak/Ibu Dr. Rina Kartika, M.Kom.', $text);
        $this->assertStringContainsString('Saya Nadia Putri (Mahasiswa Manajemen). Saya ingin meminta arahan lomba.', $text);
        $this->assertStringContainsString('kelas Pemrograman Mobile selesai, hari ini pukul 10.00 di Ruang 306?', $text);

        $this->getJson('/api/sessions/s-jarkom-today/message-draft')->assertStatus(422);
    }

    public function test_demo_attendance_batch_records_started_sessions_in_scope(): void
    {
        $this->tok('hendra@demo.ruangin.id');

        // Started today, in TI/SI scope, unrecorded, not cancelled: none of Rina's later ones, not Budi's (Manajemen).
        $this->postJson('/api/demo/attendance-batch')->assertOk()->assertJsonPath('recorded', 0);

        ClassSession::whereKey('s-mobile-today')->update(['attendance_recorded_at' => null]);
        $this->postJson('/api/demo/attendance-batch')->assertOk()
            ->assertJsonPath('recorded', 1)
            ->assertJsonPath('results.0.sessionId', 's-mobile-today');
        $this->assertSame('Tercatat · Sinkron absensi 07.34', ClassSession::find('s-mobile-today')->statusLabel());

        $this->postJson('/api/demo/attendance-batch', ['sessionIds' => ['s-ai-today', 's-pm-today']])->assertOk()
            ->assertJsonPath('recorded', 1) // s-pm-today is outside scope and simply not matched
            ->assertJsonCount(1, 'results');
        // Session not started yet: recorded at "now", never in the future.
        $this->assertSame('09.45', ClassSession::find('s-ai-today')->attendance_recorded_at->format('H.i'));

        $this->postJson('/api/demo/early-warnings')->assertOk()->assertJsonStructure(['sent']);

        $this->tok('nadia@demo.ruangin.id')->postJson('/api/demo/attendance-batch')->assertForbidden();
        config(['ruangin.demo_mode' => false]);
        $this->tok('hendra@demo.ruangin.id')->postJson('/api/demo/early-warnings')->assertNotFound();
    }

    public function test_mode_uji_times_tasks_and_checks_answers(): void
    {
        $this->tok('nadia@demo.ruangin.id');

        $id = $this->postJson('/api/test-runs', [
            'participantCode' => 'P01', 'task' => 'Cari jadwal & ruang terbaru dosen Rina', 'method' => 'ruangin',
            'targetSessionId' => 's-mobile-today',
        ])->assertCreated()->json('data.id');

        $this->travel(42)->seconds();
        $this->postJson("/api/test-runs/{$id}/finish", ['answerRoom' => 'ruang 306', 'answerEndTime' => '10:00'])->assertOk()
            ->assertJsonPath('data.durationSeconds', 42)
            ->assertJsonPath('data.isCorrect', true)
            ->assertJsonPath('data.expectedEndTime', '10.00');
        $this->postJson("/api/test-runs/{$id}/finish")->assertStatus(422)->assertJsonPath('code', 'alreadyFinished');

        $id2 = $this->postJson('/api/test-runs', ['participantCode' => 'P01', 'task' => 'Cari jadwal', 'method' => 'biasa', 'targetSessionId' => 's-mobile-today'])
            ->json('data.id');
        $this->travel(150)->seconds();
        $this->postJson("/api/test-runs/{$id2}/finish", ['answerRoom' => 'Ruang 402', 'answerEndTime' => '10.00'])
            ->assertJsonPath('data.isCorrect', false);

        $this->getJson('/api/test-runs')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/test-runs/export')->assertForbidden();

        $this->tok('hendra@demo.ruangin.id');
        $this->getJson('/api/test-runs')->assertOk()
            ->assertJsonPath('summary.ruangin.finished', 1)
            ->assertJsonPath('summary.ruangin.correctRate', 1)
            ->assertJsonPath('summary.biasa.durationSeconds.mean', 150)
            ->assertJsonPath('summary.biasa.correctRate', 0);
        $csv = $this->get('/api/test-runs/export')->assertOk()->streamedContent();
        $this->assertStringContainsString('participant_code', $csv);
        $this->assertStringContainsString('"Cari jadwal & ruang terbaru dosen Rina",ruangin', $csv);
    }

    public function test_notification_latency_from_save_to_seen(): void
    {
        $this->tok('nadia@demo.ruangin.id')->putJson('/api/sessions/s-mobile-today/follow');
        $this->tok('hendra@demo.ruangin.id')->postJson('/api/sessions/s-mobile-today/room', [
            'version' => ClassSession::find('s-mobile-today')->version, 'room' => 'Ruang 402',
        ])->assertOk();

        $this->travel(7)->seconds();
        $this->tok('nadia@demo.ruangin.id');
        $id = $this->getJson('/api/me/notifications')->json('data.0.id');
        $this->postJson('/api/me/notifications/seen', ['ids' => [$id]])->assertJsonPath('updated', 1);
        $this->travel(5)->seconds();
        $this->postJson('/api/me/notifications/seen', ['ids' => [$id]])->assertJsonPath('updated', 0); // first time only

        $this->getJson('/api/test/notification-latency')->assertForbidden();
        $this->tok('hendra@demo.ruangin.id')->getJson('/api/test/notification-latency')->assertOk()
            ->assertJsonPath('data.0.latencySeconds', 7)
            ->assertJsonPath('summary.all.n', 1)
            ->assertJsonPath('summary.byKind.sessionChanged.median', 7);
    }

    public function test_device_registration_is_idempotent_and_push_is_noop_without_fcm(): void
    {
        $this->tok('nadia@demo.ruangin.id');
        $this->postJson('/api/me/devices', ['token' => 'tok-1'])->assertOk();
        $this->postJson('/api/me/devices', ['token' => 'tok-1'])->assertOk();
        $this->assertSame(1, DeviceToken::count());

        // Same device, other account: token moves.
        $this->tok('raka@demo.ruangin.id')->postJson('/api/me/devices', ['token' => 'tok-1', 'platform' => 'android'])->assertOk();
        $this->assertSame('a-raka', DeviceToken::first()->user_id);

        Http::fake();
        $this->putJson('/api/sessions/s-mobile-today/follow');
        $this->tok('hendra@demo.ruangin.id')->postJson('/api/sessions/s-mobile-today/cancel', [
            'version' => ClassSession::find('s-mobile-today')->version,
        ])->assertOk();
        Http::assertNothingSent();
        $this->assertSame(1, AppNotification::where('recipient_id', 'a-raka')->count());

        $this->tok('raka@demo.ruangin.id')->deleteJson('/api/me/devices', ['token' => 'tok-1'])->assertOk();
        $this->assertSame(0, DeviceToken::count());
    }

    public function test_push_is_sent_through_fcm_when_configured(): void
    {
        // Windows PHP builds need an explicit openssl.cnf to generate keys.
        $opts = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA];
        $cnf = dirname(PHP_BINARY).'/extras/ssl/openssl.cnf';
        if (! getenv('OPENSSL_CONF') && is_file($cnf)) {
            $opts['config'] = $cnf;
        }
        $key = openssl_pkey_new($opts);
        if ($key === false) {
            $this->markTestSkipped('OpenSSL tidak bisa membuat kunci RSA di environment ini.');
        }
        openssl_pkey_export($key, $pem, null, isset($opts['config']) ? ['config' => $opts['config']] : []);
        $path = tempnam(sys_get_temp_dir(), 'sa');
        file_put_contents($path, json_encode([
            'client_email' => 'push@ruangin-demo.iam.gserviceaccount.com',
            'private_key' => $pem,
            'token_uri' => 'https://oauth2.googleapis.com/token',
        ]));
        config(['ruangin.fcm.project_id' => 'ruangin-demo', 'ruangin.fcm.credentials' => $path]);
        cache()->forget('ruangin.fcm.access_token');

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test']),
            'fcm.googleapis.com/*' => Http::sequence()
                ->push(['name' => 'projects/ruangin-demo/messages/1'])
                ->push(['error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404),
        ]);

        $this->tok('nadia@demo.ruangin.id');
        $this->postJson('/api/me/devices', ['token' => 'good-token']);
        $this->postJson('/api/me/devices', ['token' => 'stale-token']);
        $this->putJson('/api/sessions/s-mobile-today/follow');

        $this->tok('hendra@demo.ruangin.id')->postJson('/api/sessions/s-mobile-today/room', [
            'version' => ClassSession::find('s-mobile-today')->version, 'room' => 'Ruang 402',
        ])->assertOk();

        Http::assertSent(fn ($req) => str_contains($req->url(), 'fcm.googleapis.com/v1/projects/ruangin-demo/messages:send')
            && $req['message']['notification']['title'] === 'Pemrograman Mobile: Pindah ruang: Ruang 306 → Ruang 402'
            && $req['message']['data']['sessionId'] === 's-mobile-today'
            && $req->hasHeader('Authorization', 'Bearer ya29.test'));
        $this->assertSame(['good-token'], DeviceToken::pluck('token')->all()); // stale token removed

        unlink($path);
    }
}
