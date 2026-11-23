<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Models\ClassSession;
use App\Support\Fmt;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * P12 "salin usulan pesan": a polite message to the lecturer proposing a
 * concrete time and place (right after the class ends, in its room).
 * The app only copies it; Ruangin never sends messages or shows contacts.
 */
class MessageDraftController extends Controller
{
    public function __invoke(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['purpose' => ['nullable', 'string', 'max:200']]);
        $session = ClassSession::with('lecturer')->findOrFail($id);
        if ($session->is_cancelled) {
            throw DomainError::invalid('Sesi ini dibatalkan. Pilih sesi lain untuk menemui dosen.');
        }

        $user = $request->user();
        $hour = (int) now()->format('G');
        $greeting = match (true) {
            $hour < 11 => 'Selamat pagi',
            $hour < 15 => 'Selamat siang',
            $hour < 18 => 'Selamat sore',
            default => 'Selamat malam',
        };
        $purpose = trim($data['purpose'] ?? '') ?: '[tuliskan keperluan Anda]';
        $end = Fmt::time($session->end_at);

        // Names often end with a title like "M.T." — avoid "M.T..".
        $lecturer = rtrim($session->lecturer->name, '.');
        $text = "{$greeting}, Bapak/Ibu {$lecturer}.\n\n"
            ."Mohon maaf mengganggu waktunya. Saya {$user->name} ({$user->subtitle}). "
            ."Saya ingin {$purpose}.\n\n"
            .'Apakah saya diperkenankan menemui Bapak/Ibu sebentar setelah kelas '
            ."{$session->course_name} selesai, {$this->day($session)} pukul {$end} di {$session->room}?\n\n"
            .'Terima kasih atas waktu dan perhatian Bapak/Ibu.';

        return response()->json([
            'sessionId' => $session->id,
            'text' => $text,
            'proposedTime' => $session->end_at->toIso8601String(),
            'proposedPlace' => $session->room,
            'note' => 'Jadwal mengajar bukan jaminan dosen bisa ditemui. Cek status sesi sebelum berangkat.',
        ]);
    }

    private function day(ClassSession $s): string
    {
        $today = now()->startOfDay();

        return match (true) {
            $s->start_at->isSameDay($today) => 'hari ini',
            $s->start_at->isSameDay($today->copy()->addDay()) => 'besok',
            default => Fmt::date($s->start_at),
        };
    }
}
