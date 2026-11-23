<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Same shape as AppNotification.fromJson in app/lib/data/models/app_notification.dart. */
class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'recipientId' => $this->recipient_id,
            'sessionId' => $this->class_session_id,
            'kind' => $this->kind,
            'title' => $this->title,
            'body' => $this->body,
            'createdAt' => $this->created_at->toIso8601String(),
            'isRead' => $this->read_at !== null,
            'seenAt' => $this->seen_at?->toIso8601String(),
        ];
    }
}
