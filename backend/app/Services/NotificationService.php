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
     * Notifies every follower of $session except $excludeUserId.
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
        $ids = DB::table('follows')
            ->where('class_session_id', $session->id)
            ->when($excludeUserId, fn ($q) => $q->where('user_id', '!=', $excludeUserId))
            ->pluck('user_id')
            ->all();

        return $this->notifyUsers($ids, $session, $kind, $title, $body);
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
