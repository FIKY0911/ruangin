import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'result.dart';

/// The four screen states required by the PRD (+ stale data).
sealed class ViewState<T> {
  const ViewState();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty(this.fetchedAt);
  final DateTime fetchedAt;
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);
  final String message;
}

final class ViewData<T> extends ViewState<T> {
  const ViewData(this.data, this.fetchedAt, {this.staleReason});

  final T data;
  final DateTime fetchedAt;

  /// Non-null when a refresh failed and [data] is the last good copy.
  final String? staleReason;

  bool get isStale => staleReason != null;
}

/// Base controller: loads via [fetch], keeps the last good value so a failed
/// refresh shows stale data (with its timestamp) instead of an error.
abstract class AsyncController<T> extends ChangeNotifier {
  AsyncController(this.clock);

  final Clock clock;
  ViewState<T> _state = const ViewLoading();
  T? _last;
  DateTime? _lastAt;
  bool _disposed = false;
  int _generation = 0;

  ViewState<T> get state => _state;
  T? get value => _last;

  @protected
  Future<Result<T>> fetch();

  @protected
  bool isEmpty(T value) => value is Iterable && value.isEmpty;

  Future<void> load() async {
    final gen = ++_generation;
    if (_last == null) _set(const ViewLoading());
    final result = await fetch();
    if (_disposed || gen != _generation) return;
    switch (result) {
      case Success(:final value):
        _last = value;
        _lastAt = clock.now();
        _set(isEmpty(value) ? ViewEmpty(_lastAt!) : ViewData(value, _lastAt!));
      case Failure(:final failure):
        final last = _last;
        if (last != null && !isEmpty(last)) {
          _set(ViewData(last, _lastAt!, staleReason: failure.message));
        } else {
          _set(ViewError(failure.message));
        }
    }
  }

  /// Forget cached data (e.g. when the query changes).
  @protected
  void resetCache() {
    _last = null;
    _lastAt = null;
  }

  void _set(ViewState<T> s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
