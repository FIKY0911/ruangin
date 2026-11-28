import 'dart:async';

import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/search_results.dart';
import '../../data/repositories/repositories.dart';

/// "Cari sesi, dosen, atau mata kuliah". A blank query lists all lecturers;
/// otherwise lecturers by name plus sessions of the coming week by course or
/// room (`GET /search`).
class SearchResultsController extends AsyncController<SearchResults> {
  SearchResultsController(
    this._repo,
    super.clock, {
    this.debounce = const Duration(milliseconds: 250),
  });

  final SearchRepository _repo;
  final Duration debounce;
  String _query = '';
  Timer? _timer;

  String get query => _query;

  @override
  bool isEmpty(SearchResults value) => value.isEmpty;

  @override
  Future<Result<SearchResults>> fetch() => _repo.search(_query);

  void onQueryChanged(String value) {
    _query = value;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      resetCache();
      load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
