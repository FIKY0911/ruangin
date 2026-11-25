import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruangin/app.dart';
import 'package:ruangin/core/clock.dart';
import 'package:ruangin/data/local/key_value_store.dart';

import 'fake_backend.dart';

/// Pumps the real app (real ApiClient + repositories) against [backend].
Future<void> pumpApp(
  WidgetTester tester,
  FakeBackend backend,
  KeyValueStore store,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RuanginApp(
      key: UniqueKey(),
      dependencies: buildDependencies(
        store: store,
        httpClient: backend.client,
        baseUrl: testBaseUrl,
        clock: FixedClock(backend.now),
        notificationPoll: null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Finder field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);
