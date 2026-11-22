import 'dart:async';

import '../../core/result.dart';
import '../../core/view_state.dart';
import '../../data/models/lecturer.dart';
import '../../data/repositories/repositories.dart';

class LecturerSearchController extends AsyncController<List<Lecturer>> {
  LecturerSearchController(this._repo, super.clock,
      {this.debounce = const Duration(milliseconds: 250)});

  final LecturerRepository _repo;
  final Duration debounce;
  String _query = '';
  Timer? _timer;

  String get query => _query;

  @override
  Future<Result<List<Lecturer>>> fetch() => _repo.search(_query);

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
