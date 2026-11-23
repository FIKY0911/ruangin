<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainError;
use App\Http\Controllers\Controller;
use App\Http\Resources\AccountResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * Register / login / logout. Error codes and field names match
 * AuthErrorCode / AuthField in app/lib/domain/auth_service.dart.
 */
class AuthController extends Controller
{
    private const EMAIL_REGEX = '/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/';

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'max:255', 'regex:'.self::EMAIL_REGEX],
            'password' => ['required', 'string', 'min:8', 'max:255'],
            'confirmPassword' => ['required', 'string', 'same:password'],
        ], [
            'email.required' => 'Email wajib diisi.',
            'email.regex' => 'Format email tidak valid.',
            'password.required' => 'Password wajib diisi.',
            'password.min' => 'Password minimal 8 karakter.',
            'confirmPassword.required' => 'Konfirmasi password wajib diisi.',
            'confirmPassword.same' => 'Konfirmasi password tidak sama.',
        ]);

        $email = mb_strtolower(trim($data['email']));
        if (User::where('email', $email)->exists()) {
            throw new DomainError('Email sudah terdaftar.', 'emailTaken', 422, ['email' => ['Email sudah terdaftar.']]);
        }

        // Role is always "mahasiswa" for self-registration (PRD §7: role from server).
        $local = explode('@', $email)[0];
        $user = User::create([
            'name' => $local !== '' ? $local : $email,
            'email' => $email,
            'password' => $data['password'],
            'subtitle' => 'Mahasiswa',
        ]);

        return (new AccountResource($user->refresh()))->response()->setStatusCode(201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'max:255', 'regex:'.self::EMAIL_REGEX],
            'password' => ['required', 'string', 'max:255'],
            'deviceName' => ['nullable', 'string', 'max:100'],
        ], [
            'email.required' => 'Email wajib diisi.',
            'email.regex' => 'Format email tidak valid.',
            'password.required' => 'Password wajib diisi.',
        ]);

        $user = User::where('email', mb_strtolower(trim($data['email'])))->first();
        if (! $user) {
            throw new DomainError(
                'Akun tidak ditemukan. Periksa email atau daftar akun baru.',
                'accountNotFound',
                401,
                ['email' => ['Akun tidak ditemukan.']],
            );
        }
        if (! Hash::check($data['password'], $user->password)) {
            throw new DomainError('Password salah.', 'wrongPassword', 401, ['password' => ['Password salah.']]);
        }

        $token = $user->createToken($data['deviceName'] ?? 'ruangin-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'tokenType' => 'Bearer',
            'account' => new AccountResource($user),
        ]);
    }

    public function me(Request $request): AccountResource
    {
        return new AccountResource($request->user());
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(null, 204);
    }
}
