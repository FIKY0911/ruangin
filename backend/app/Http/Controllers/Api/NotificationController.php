<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\NotificationResource;
use App\Models\AppNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** P06: in-app notifications of the signed-in user. */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $data = $request->validate(['unread' => ['nullable', 'boolean']]);
        $user = $request->user();

        $items = $user->appNotifications()
            ->when($data['unread'] ?? false, fn ($q) => $q->whereNull('read_at'))
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit(100)
            ->get();

        return NotificationResource::collection($items)->additional([
            'unreadCount' => $user->appNotifications()->whereNull('read_at')->count(),
        ]);
    }

    public function markRead(Request $request, string $id): NotificationResource
    {
        $notification = AppNotification::where('recipient_id', $request->user()->id)->findOrFail($id);
        if ($notification->read_at === null) {
            $notification->update(['read_at' => now(), 'seen_at' => $notification->seen_at ?? now()]);
        }

        return new NotificationResource($notification);
    }

    /**
     * Mode uji: the app reports which notifications were just shown on screen
     * (list or banner). Only the first time counts, so re-sending is harmless.
     */
    public function markSeen(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1', 'max:200'],
            'ids.*' => ['string', 'max:64'],
        ]);

        $updated = $request->user()->appNotifications()
            ->whereIn('id', $data['ids'])
            ->whereNull('seen_at')
            ->update(['seen_at' => now()]);

        return response()->json(['updated' => $updated]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $now = now();
        $user = $request->user();
        $user->appNotifications()->whereNull('seen_at')->update(['seen_at' => $now]);
        $updated = $user->appNotifications()->whereNull('read_at')->update(['read_at' => $now]);

        return response()->json(['updated' => $updated]);
    }
}
