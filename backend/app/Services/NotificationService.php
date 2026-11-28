<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\ClassSession;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/** Fans session events out as stored in-app notifications (P06). */
class NotificationService
{
    public function __construct(private readonly PushService $push) {}

    /**
     * Notifies everyone who follows $session or its lecturer, once each,
     * except $excludeUserId.
     *
     * @return int number of notifications created
     */
    public function notifyFollowers(
        ClassSession $session,
        string $kind,
        string $title,
        string $body,
        ?string $excludeUserId = null,
    ): int {
        return $this->notifyUsers($this->followerIds($session, $excludeUserId), $session, $kind, $title, $body);
    }

    /** @return list<string> ids of session followers + lecturer followers, without duplicates */
    public function followerIds(ClassSession $session, ?string $excludeUserId = null): array
    {
        $sessionFollowers = DB::table('follows')
            ->where('class_session_id', $session->id)
            ->pluck('user_id');
        $lecturerFollowers = DB::table('lecturer_follows')
            ->where('lecturer_id', $session->lecturer_id)
            ->pluck('user_id');

        return $sessionFollowers->merge($lecturerFollowers)
            ->unique()
            ->reject(fn ($id) => $excludeUserId !== null && $id === $excludeUserId)
            ->values()
            ->all();
    }

    /**
     * @param  list<string>  $userIds
     * @return int number of notifications created
     */
    public function notifyUsers(array $userIds, ClassSession $session, string $kind, string $title, string $body): int
    {
        $userIds = array_values(array_unique($userIds));
        if ($userIds === []) {
            return 0;
        }

        $now = now();
        $rows = array_map(fn (string $userId) => [
            'id' => AppNotification::ID_PREFIX.'-'.Str::lower((string) Str::ulid()),
            'recipient_id' => $userId,
            'class_session_id' => $session->id,
            'kind' => $kind,
            'title' => Str::limit($title, 495),
            'body' => $body,
            'seen_at' => null,
            'read_at' => null,
            'created_at' => $now,
        ], $userIds);

        AppNotification::insert($rows);

        // P07: push after the transaction commits and after the HTTP response
        // is sent, so FCM latency never slows down the edit itself.
        if ($this->push->enabled()) {
            $data = ['sessionId' => $session->id, 'kind' => $kind];
            // terminating() callbacks are never removed, so guard against
            // re-running in long-lived processes (tests, workers).
            $done = false;
            DB::afterCommit(fn () => app()->terminating(function () use (&$done, $userIds, $title, $body, $data) {
                if ($done) {
                    return;
                }
                $done = true;
                $this->push->sendToUsers($userIds, $title, $body, $data);
            }));
        }

        return count($rows);
    }
}
