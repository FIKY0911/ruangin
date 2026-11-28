import 'package:flutter/foundation.dart';

import 'lecturer.dart';
import 'session.dart';

/// `GET /search?q=`: lecturers by name + sessions (coming week) by course or
/// room.
@immutable
class SearchResults {
  const SearchResults({
    required this.query,
    required this.lecturers,
    this.sessions = const [],
  });

  final String query;
  final List<Lecturer> lecturers;

  /// Sorted by start; empty when the query was empty (lecturer list only).
  final List<Session> sessions;

  bool get isEmpty => lecturers.isEmpty && sessions.isEmpty;
}
