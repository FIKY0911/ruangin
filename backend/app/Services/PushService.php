<?php

namespace App\Services;

use App\Models\DeviceToken;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * P07 push notifications through Firebase Cloud Messaging (HTTP v1 API).
 *
 * Disabled (no-op) until FCM_PROJECT_ID and FCM_CREDENTIALS (path to a
 * Firebase service-account JSON file) are set. In-app notifications in the
 * database stay the source of truth, so every P0 flow works without push.
 */
class PushService
{
    public function enabled(): bool
    {
        $path = (string) config('ruangin.fcm.credentials');

        return config('ruangin.fcm.project_id') && $path !== '' && is_file($path);
    }

    /**
     * @param  list<string>  $userIds
     * @param  array<string, string>  $data  delivered to the app (e.g. sessionId, kind)
     * @return int messages accepted by FCM
     */
    public function sendToUsers(array $userIds, string $title, string $body, array $data = []): int
    {
        if ($userIds === [] || ! $this->enabled()) {
            return 0;
        }

        $tokens = DeviceToken::whereIn('user_id', $userIds)->orderBy('id')->pluck('token')->all();
        if ($tokens === []) {
            return 0;
        }

        try {
            $accessToken = $this->accessToken();
        } catch (Throwable $e) {
            Log::warning('FCM: gagal mengambil access token', ['error' => $e->getMessage()]);

            return 0;
        }

        $url = 'https://fcm.googleapis.com/v1/projects/'.config('ruangin.fcm.project_id').'/messages:send';
        $sent = 0;
        foreach ($tokens as $token) {
            $response = Http::withToken($accessToken)->timeout(5)->post($url, ['message' => [
                'token' => $token,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => array_map('strval', $data),
                'android' => ['priority' => 'high'],
            ]]);

            if ($response->successful()) {
                $sent++;
            } elseif (in_array($response->status(), [400, 404], true)
                && (str_contains($response->body(), 'UNREGISTERED') || str_contains($response->body(), 'registration token'))) {
                // Token no longer valid (app uninstalled / token rotated).
                DeviceToken::where('token', $token)->delete();
            } else {
                Log::warning('FCM: kirim gagal', ['status' => $response->status(), 'body' => $response->body()]);
            }
        }

        return $sent;
    }

    /** OAuth2 access token from the service account (JWT bearer grant), cached ~55 min. */
    private function accessToken(): string
    {
        return Cache::remember('ruangin.fcm.access_token', 3300, function () {
            $sa = json_decode((string) file_get_contents(config('ruangin.fcm.credentials')), true, flags: JSON_THROW_ON_ERROR);
            $now = time();
            $b64 = fn (string $s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
            $header = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $b64(json_encode([
                'iss' => $sa['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => $sa['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            $signature = '';
            if (! openssl_sign("{$header}.{$claims}", $signature, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
                throw new \RuntimeException('Gagal menandatangani JWT service account.');
            }

            return Http::asForm()->timeout(10)->post($sa['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => "{$header}.{$claims}.".$b64($signature),
            ])->throw()->json('access_token');
        });
    }
}
