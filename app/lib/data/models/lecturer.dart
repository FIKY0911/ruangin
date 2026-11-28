import 'package:flutter/foundation.dart';

@immutable
class Lecturer {
  const Lecturer({
    required this.id,
    required this.name,
    required this.prodi,
    required this.faculty,
    this.isFollowed = false,
  });

  final String id;
  final String name;

  /// Prodi asal (home study program) of the lecturer.
  final String prodi;
  final String faculty;

  /// The signed-in user follows this lecturer: notifications for all of
  /// their sessions, which also show in "Sesi hari ini".
  final bool isFollowed;

  Lecturer copyWith({bool? isFollowed}) => Lecturer(
    id: id,
    name: name,
    prodi: prodi,
    faculty: faculty,
    isFollowed: isFollowed ?? this.isFollowed,
  );

  factory Lecturer.fromJson(Map<String, dynamic> json) => Lecturer(
    id: json['id'] as String,
    name: json['name'] as String,
    prodi: json['prodi'] as String,
    faculty: json['faculty'] as String,
    isFollowed: json['isFollowed'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) => other is Lecturer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
