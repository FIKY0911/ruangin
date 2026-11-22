import 'package:flutter/foundation.dart';

@immutable
class Lecturer {
  const Lecturer({
    required this.id,
    required this.name,
    required this.prodi,
    required this.faculty,
  });

  final String id;
  final String name;

  /// Prodi asal (home study program) of the lecturer.
  final String prodi;
  final String faculty;

  factory Lecturer.fromJson(Map<String, dynamic> json) => Lecturer(
        id: json['id'] as String,
        name: json['name'] as String,
        prodi: json['prodi'] as String,
        faculty: json['faculty'] as String,
      );

  @override
  bool operator ==(Object other) => other is Lecturer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
