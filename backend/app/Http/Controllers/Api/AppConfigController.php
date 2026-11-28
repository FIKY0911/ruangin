<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * Server facts the app shows as labels:
 * - simulatedData: every schedule/attendance record is synthetic or comes from
 *   the simulated attendance feed (the "Simulasi" chips in the designs);
 * - notificationRetentionDays: "Notifikasi otomatis dihapus setelah N hari"
 *   (null = notifications are kept).
 */
class AppConfigController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $days = (int) config('ruangin.notification_retention_days');

        return response()->json(['data' => [
            'simulatedData' => (bool) config('ruangin.simulated_data'),
            'notificationRetentionDays' => $days > 0 ? $days : null,
        ]]);
    }
}
