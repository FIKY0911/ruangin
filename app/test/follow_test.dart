import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/data/local/key_value_store.dart';
import 'package:ruangin/data/repositories/local_repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LocalFollowRepository> repo() async =>
      LocalFollowRepository(SharedPreferencesStore(await SharedPreferences.getInstance()));

  test('follow is idempotent', () async {
    final r = await repo();
    await r.follow('u1', 's1');
    await r.follow('u1', 's1');
    expect((await r.followedSessionIds('u1')).valueOrNull, {'s1'});
    expect((await r.followersOf('s1')).valueOrNull, {'u1'});
  });

  test('unfollow when not following is safe', () async {
    final r = await repo();
    expect((await r.unfollow('u1', 'nope')).isSuccess, isTrue);
    await r.follow('u1', 's1');
    await r.unfollow('u1', 's1');
    await r.unfollow('u1', 's1');
    expect((await r.followedSessionIds('u1')).valueOrNull, isEmpty);
  });

  test('follows persist across repository instances (shared_preferences)', () async {
    await (await repo()).follow('u1', 's1');
    await (await repo()).follow('u2', 's1');
    final fresh = await repo();
    expect((await fresh.followedSessionIds('u1')).valueOrNull, {'s1'});
    expect((await fresh.followersOf('s1')).valueOrNull, {'u1', 'u2'});
  });
}
