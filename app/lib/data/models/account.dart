import 'package:flutter/foundation.dart';

enum UserRole {
  mahasiswa('Mahasiswa'),
  dosen('Dosen'),
  petugas('Petugas akademik');

  const UserRole(this.label);
  final String label;

  static UserRole parse(String raw) => UserRole.values.firstWhere(
    (r) => r.name == raw,
    orElse: () => throw FormatException('Role tidak dikenal: $raw'),
  );
}

/// Signed-in account. The role always comes from the server (`/auth/login`,
/// `/auth/me`) and can never be chosen in-app.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.subtitle,
    this.lecturerId,
    this.scopeProdi = const [],
    this.points = 0,
  });

  final String id;
  final String name;

  /// Normalised (trimmed, lower-case) login email.
  final String email;
  final UserRole role;
  final String subtitle;

  /// Set for [UserRole.dosen]: the lecturer this account represents.
  final String? lecturerId;

  /// Set for [UserRole.petugas]: prodi within the officer's scope.
  final List<String> scopeProdi;

  /// P10: points from confirmed empty-room reports.
  final int points;

  bool get isEditor => role != UserRole.mahasiswa;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: '${json['id']}',
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.parse(json['role'] as String),
    subtitle: json['subtitle'] as String? ?? '',
    lecturerId: json['lecturerId'] as String?,
    scopeProdi: List<String>.unmodifiable(
      (json['scopeProdi'] as List<dynamic>? ?? const []).cast<String>(),
    ),
    points: (json['points'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'subtitle': subtitle,
    'lecturerId': lecturerId,
    'scopeProdi': scopeProdi,
    'points': points,
  };

  @override
  bool operator ==(Object other) =>
      other is Account && other.id == id && other.points == points;

  @override
  int get hashCode => Object.hash(id, points);
}
