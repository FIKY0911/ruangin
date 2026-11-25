import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/result.dart';
import '../local/key_value_store.dart';

/// A failure returned by the Laravel API (`{message, code, errors}`), or a
/// network problem (statusCode 0). [message] is the server's own text so the
/// UI can show it as-is.
class ApiFailure extends AppFailure {
  const ApiFailure(
    super.message, {
    required this.statusCode,
    this.code,
    this.fieldErrors = const {},
    super.cause,
  });

  /// 0 when the server could not be reached.
  final int statusCode;

  /// Server error code, e.g. `wrongPassword`, `staleVersion`, `forbidden`.
  final String? code;

  /// First message per field from `errors`.
  final Map<String, String> fieldErrors;

  bool get isNetwork => statusCode == 0;

  /// 409: the session was changed by someone else; reload before editing.
  bool get isStaleVersion => statusCode == 409 || code == 'staleVersion';

  /// 401 for an expired/missing token (not a failed login).
  bool get isUnauthenticated => statusCode == 401 && code == 'unauthenticated';
}

/// Persists the Sanctum bearer token (and the last known account JSON so the
/// app can open offline with stale data).
class TokenStore {
  TokenStore(this._store);

  static const tokenKey = 'auth.token';
  static const accountKey = 'auth.account';

  final KeyValueStore _store;

  String? get token => _store.getString(tokenKey);
  Future<void> saveToken(String token) => _store.setString(tokenKey, token);

  Map<String, dynamic>? get cachedAccount {
    final raw = _store.readJson(accountKey);
    return raw is Map<String, dynamic> ? raw : null;
  }

  Future<void> saveAccount(Map<String, dynamic> json) =>
      _store.writeJson(accountKey, json);

  Future<void> clear() async {
    await _store.remove(tokenKey);
    await _store.remove(accountKey);
  }
}

/// Thin JSON client: base URL, `Accept: application/json`, bearer token, and
/// mapping of the error format to [ApiFailure]. Every method throws
/// [ApiFailure]; repositories wrap calls with [guard] to get a [Result].
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required String baseUrl,
    required this.tokens,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient,
       _base = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  final http.Client _http;
  final String _base;
  final TokenStore tokens;
  final Duration timeout;

  /// Called when an authenticated request returns 401 `unauthenticated`
  /// (token revoked/expired). The auth controller signs the user out.
  void Function()? onUnauthenticated;

  String get baseUrl => _base;

  Uri uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? const <String, String?>{}).entries)
        if (e.value != null) e.key: e.value!,
    };
    return Uri.parse('$_base$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
  }) async {
    final token = tokens.token;
    final request = http.Request(method, uri(path, query))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      );
    } on TimeoutException catch (e) {
      throw ApiFailure(
        'Server tidak merespons. Periksa koneksi lalu coba lagi.',
        statusCode: 0,
        cause: e,
      );
    } catch (e) {
      throw ApiFailure(
        'Tidak bisa terhubung ke server ($_base). Periksa koneksi atau '
        'alamat server.',
        statusCode: 0,
        cause: e,
      );
    }

    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final failure = _failure(response.statusCode, decoded);
    if (failure.isUnauthenticated && token != null) {
      await tokens.clear();
      onUnauthenticated?.call();
    }
    throw failure;
  }

  static dynamic _decode(http.Response r) {
    if (r.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static ApiFailure _failure(int status, dynamic body) {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final errors = <String, String>{};
    final rawErrors = map['errors'];
    if (rawErrors is Map) {
      for (final e in rawErrors.entries) {
        final v = e.value;
        final first = v is List && v.isNotEmpty ? v.first : v;
        if (first != null) errors['${e.key}'] = '$first';
      }
    }
    final message =
        map['message'] is String && (map['message'] as String).isNotEmpty
        ? map['message'] as String
        : _fallbackMessage(status);
    return ApiFailure(
      message,
      statusCode: status,
      code: map['code'] as String?,
      fieldErrors: errors,
    );
  }

  static String _fallbackMessage(int status) => switch (status) {
    401 => 'Sesi login berakhir. Silakan masuk lagi.',
    403 => 'Anda tidak berhak melakukan aksi ini.',
    404 => 'Data tidak ditemukan.',
    409 => 'Data sudah diubah orang lain. Muat ulang lalu coba lagi.',
    429 => 'Terlalu banyak percobaan. Coba lagi sebentar lagi.',
    >= 500 => 'Server sedang bermasalah ($status). Coba lagi nanti.',
    _ => 'Permintaan gagal ($status).',
  };
}

/// Helpers for reading Laravel resource envelopes (`{data: ...}`).
Map<String, dynamic> dataObject(dynamic body) {
  if (body is Map<String, dynamic>) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
  throw const ApiFailure('Respons server tidak dikenali.', statusCode: 200);
}

List<Map<String, dynamic>> dataList(dynamic body) {
  final data = body is Map<String, dynamic> ? body['data'] : body;
  if (data is List) return data.cast<Map<String, dynamic>>();
  throw const ApiFailure('Respons server tidak dikenali.', statusCode: 200);
}
