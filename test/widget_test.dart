import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/app_shell.dart';
import 'package:mitsumori_seikyu/app_scope.dart';
import 'package:mitsumori_seikyu/screens/editor_screen.dart';
import 'package:mitsumori_seikyu/screens/premium_screen.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/state/app_controller.dart';
import 'package:mitsumori_seikyu/theme.dart';

import 'support/harness.dart';

/// iPhone 6.1" portrait.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget host(AppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: buildTheme(), home: child),
  );
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mitsumori_ui_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('empty app asks for business info and explains the free plan', (
    tester,
  ) async {
    phoneSize(tester);
    final controller = await tester.runAsync(() => openController(directory));
    await tester.pumpWidget(AppShell(controller: controller!));
    await frames(tester);

    expect(find.byKey(const Key('setup-profile')), findsOneWidget);
    expect(find.textContaining('今月あと3件作成できます'), findsOneWidget);
    expect(find.textContaining('まだ書類がありません'), findsOneWidget);
    expect(find.text('¥0'), findsWidgets);
    controller.dispose();
  });

  testWidgets('list shows unpaid invoices with the due date', (tester) async {
    phoneSize(tester);
    final controller = await tester.runAsync(() async {
      final c = await openController(directory);
      final e = await seedEstimate(c);
      await c.convertToInvoice(e.id);
      return c;
    });
    await tester.pumpWidget(AppShell(controller: controller!));
    await frames(tester);

    expect(find.text('¥128,700'), findsWidgets);
    expect(find.textContaining('未入金・支払期限 11/30'), findsOneWidget);
    expect(find.text('請求書を作成済み'), findsOneWidget);
    expect(find.text('1件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-unpaid')));
    await frames(tester);
    expect(find.text('入金済にする'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('free search opens the paywall', (tester) async {
    phoneSize(tester);
    final controller = await tester.runAsync(() => openController(directory));
    await tester.pumpWidget(AppShell(controller: controller!));
    await frames(tester);
    await tester.tap(find.byKey(const Key('search')));
    await frames(tester);
    expect(find.text('過去の書類の表示と検索はプレミアムの機能です。'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('editor adds a line from the item master with a quantity', (
    tester,
  ) async {
    phoneSize(tester);
    late Doc draft;
    final controller = await tester.runAsync(() async {
      final c = await openController(directory);
      final customer = await c.addCustomer(name: '山田工務店');
      await c.addItem(name: 'クロス張替え', unit: 'm²', unitPrice: 1200);
      draft = c
          .newDraft(DocKind.estimate)
          .copyWith(customerId: customer.id, customerName: customer.name);
      return c;
    });
    await tester.pumpWidget(host(controller!, EditorScreen(initial: draft)));
    await frames(tester);

    expect(find.text('見積書を作成'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-from-items')));
    await frames(tester);
    await tester.tap(find.text('クロス張替え'));
    await frames(tester);
    await tester.enterText(find.byKey(const Key('quantity')), '42.5');
    await tester.tap(find.byKey(const Key('quantity-save')));
    await frames(tester);

    expect(find.text('42.5 m² × ¥1,200'), findsOneWidget);
    expect(find.text('¥56,100'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('paywall shows price, period, trial, restore and legal links', (
    tester,
  ) async {
    phoneSize(tester);
    final controller = await tester.runAsync(() => openController(directory));
    await tester.pumpWidget(host(controller!, const PremiumScreen()));
    await frames(tester);

    expect(find.text('¥100'), findsOneWidget);
    expect(find.text('/ 1か月（自動更新）'), findsOneWidget);
    expect(find.text('¥1,200'), findsOneWidget);
    expect(find.text('/ 1年（自動更新）'), findsOneWidget);
    expect(find.textContaining('無料で月額をはじめる'), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('restore')), 200);
    expect(find.byKey(const Key('restore')), findsOneWidget);
    expect(find.byKey(const Key('link-terms')), findsOneWidget);
    expect(find.byKey(const Key('link-privacy')), findsOneWidget);
    expect(find.textContaining('自動更新され'), findsOneWidget);
    controller.dispose();
  });
}
