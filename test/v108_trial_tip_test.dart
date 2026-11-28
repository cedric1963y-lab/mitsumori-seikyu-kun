import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/app_shell.dart';
import 'package:mitsumori_seikyu/plan/entitlement.dart';
import 'package:mitsumori_seikyu/plan/limits.dart';
import 'package:mitsumori_seikyu/plan/trial_tip.dart';

import 'support/harness.dart';

Entitlement ent(DateTime start, Duration length) => Entitlement(
  productId: PlanLimits.monthlyProductId,
  purchasedAt: start,
  expiresAt: start.add(length),
);

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final now = DateTime(2026, 12, 3, 9);

  test('tip only for a week-long first period, not at the very start', () {
    bool show(Entitlement e, {bool shown = false}) =>
        TrialTip.shouldShow(entitlement: e, now: now, alreadyShown: shown);
    expect(
      show(ent(now.subtract(const Duration(days: 3)), const Duration(days: 7))),
      isTrue,
    );
    expect(
      show(
        ent(now.subtract(const Duration(hours: 2)), const Duration(days: 7)),
      ),
      isFalse,
    );
    expect(
      show(
        ent(now.subtract(const Duration(days: 3)), const Duration(days: 7)),
        shown: true,
      ),
      isFalse,
    );
    expect(
      show(
        ent(now.subtract(const Duration(days: 3)), const Duration(days: 31)),
      ),
      isFalse,
    );
    expect(
      show(
        ent(now.subtract(const Duration(days: 3)), const Duration(days: 365)),
      ),
      isFalse,
    );
    expect(
      show(
        ent(now.subtract(const Duration(days: 10)), const Duration(days: 7)),
      ),
      isFalse,
    );
    expect(show(const Entitlement()), isFalse);
    expect(
      show(
        Entitlement(
          productId: PlanLimits.monthlyProductId,
          expiresAt: now.add(const Duration(days: 3)),
        ),
      ),
      isFalse,
    );
  });

  test('purchasedAt survives save and load', () {
    final e = ent(now, const Duration(days: 7));
    final back = Entitlement.fromJson(e.toJson());
    expect(back.purchasedAt, e.purchasedAt);
    expect(Entitlement.fromJson({'version': 1}).purchasedAt, isNull);
  });

  testWidgets('trial user sees the tip once and never again', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('mitsu_tip_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = (await tester.runAsync(
      () => openController(dir, now: () => now),
    ))!;
    c.entitlement = ent(
      now.subtract(const Duration(days: 3)),
      const Duration(days: 7),
    );
    await tester.pumpWidget(AppShell(controller: c));
    await frames(tester);
    expect(find.textContaining('お試し中のヒント'), findsOneWidget);
    expect(c.trialTipShown, isTrue);
    expect(c.shouldShowTrialTip, isFalse);

    await tester.pumpWidget(AppShell(controller: c, key: UniqueKey()));
    await frames(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('お試し中のヒント'), findsNothing);
    c.dispose();
  });

  testWidgets('free and paid users never see the tip', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('mitsu_tip2_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = (await tester.runAsync(
      () => openController(dir, premium: true, now: () => now),
    ))!;
    await tester.pumpWidget(AppShell(controller: c));
    await frames(tester);
    expect(find.textContaining('お試し中のヒント'), findsNothing);
    c.dispose();
  });
}
