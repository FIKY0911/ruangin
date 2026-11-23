<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Per-request cache of the signed-in user's followed session ids, so list
 * endpoints can expose "isFollowed" without one query per session.
 */
final class Viewer
{
    /** @var array<string, true>|null */
    private ?array $followed = null;

    private function __construct(private readonly ?string $userId) {}

    public static function of(Request $request): self
    {
        $viewer = $request->attributes->get(self::class);
        if (! $viewer instanceof self) {
            $viewer = new self($request->user()?->id);
            $request->attributes->set(self::class, $viewer);
        }

        return $viewer;
    }

    public function follows(string $sessionId): bool
    {
        if ($this->userId === null) {
            return false;
        }
        $this->followed ??= array_fill_keys(
            DB::table('follows')->where('user_id', $this->userId)->pluck('class_session_id')->all(),
            true,
        );

        return isset($this->followed[$sessionId]);
    }
}
