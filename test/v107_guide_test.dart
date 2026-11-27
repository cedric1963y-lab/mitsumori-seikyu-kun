import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/app_shell.dart';
import 'package:mitsumori_seikyu/data/repository.dart';
import 'package:mitsumori_seikyu/state/app_controller.dart';

import 'support/fake_purchase_gateway.dart';

Future<AppController> fresh(Directory dir) async {
  final c = AppController(
    repository: Repository(dir),
    purchases: FakePurchaseGateway(),
  );
  await c.load();
  return c;
}

void main() {
  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('mitsu_guide_'),
  );
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  testWidgets('guide shows once on first launch, swipes, and is skippable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = (await tester.runAsync(() => fresh(dir)))!;
    await tester.pumpWidget(AppShell(controller: c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('見積書をつくる'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('guide-pages')),
      const Offset(-600, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1タップで請求書に'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PDFをLINEやメールで送る'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-skip')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('guide-pages')), findsNothing);
    expect(c.guideSeen, isTrue);
    // Persisting: a controller that marks the guide seen is remembered.
    final c1 = (await tester.runAsync(() => fresh(dir)))!;
    await tester.runAsync(c1.markGuideSeen);
    c1.dispose();

    // Second launch: not shown again.
    final c2 = (await tester.runAsync(() => fresh(dir)))!;
    expect(c2.guideSeen, isTrue);
    await tester.pumpWidget(AppShell(controller: c2, key: UniqueKey()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('guide-pages')), findsNothing);
    c.dispose();
    c2.dispose();
  });

  testWidgets('? buttons open a short explanation on each tab', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = (await tester.runAsync(() => fresh(dir)))!;
    c.guideSeen = true;
    await tester.pumpWidget(AppShell(controller: c));
    await tester.pump(const Duration(milliseconds: 500));
    for (final entry in {
      'tab-documents': 'help-documents',
      'tab-unpaid': 'help-unpaid',
      'tab-master': 'help-master',
      'tab-settings': 'help-settings',
    }.entries) {
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(Key(entry.value)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('help-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('help-close')));
      await tester.pump(const Duration(milliseconds: 400));
    }
    c.dispose();
  });
}
