<?php

// Business rules from PRD §12 that are still marked [Asumsi]. Kept in config
// so the team can change them without touching code.
return [
    // Shared secret for POST /api/sync/attendance (simulated campus feed).
    'sync_key' => env('RUANGIN_SYNC_KEY'),

    // Students may report an empty room from N minutes before start until end.
    'report_window_before_minutes' => (int) env('RUANGIN_REPORT_WINDOW_BEFORE_MINUTES', 15),

    // Max empty-room reports per student per day.
    'report_daily_limit' => (int) env('RUANGIN_REPORT_DAILY_LIMIT', 5),

    // Points for a report that a lecturer/officer confirms (P10).
    'report_points' => (int) env('RUANGIN_REPORT_POINTS', 10),

    // A session still unconfirmed this many minutes after it started triggers
    // an early warning to followers of the lecturer's later sessions (P11).
    'early_warning_grace_minutes' => (int) env('RUANGIN_EARLY_WARNING_GRACE_MINUTES', 15),

    // Demo panel endpoints (/api/demo/*). Turn off outside demos.
    'demo_mode' => (bool) env('RUANGIN_DEMO_MODE', true),

    // P07 push (FCM HTTP v1). Empty = push disabled, in-app only.
    'fcm' => [
        'project_id' => env('FCM_PROJECT_ID'),
        // Path to the Firebase service-account JSON (keep it out of git).
        'credentials' => env('FCM_CREDENTIALS'),
    ],

    'schedule_source' => 'Jadwal prodi (data sintetis)',
    'attendance_source' => 'Sinkron absensi (simulasi)',
];
