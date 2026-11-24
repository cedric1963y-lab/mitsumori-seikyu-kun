import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/plan/limits.dart';
import 'package:mitsumori_seikyu/services/purchase_gateway.dart';

import 'support/harness.dart';

void main() {
  test('settings version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version: ([0-9.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(AppInfo.version, match.group(1));
    expect(AppInfo.version, '1.0.6');
  });

  test('fallback prices include the 1-week free trial', () {
    expect(fallbackPremiumProducts, hasLength(2));
    for (final product in fallbackPremiumProducts) {
      expect(product.trialLabel, PlanLimits.freeTrialLabel);
      expect(product.trialLabel, '1週間');
    }
  });

  test('trial text is shown before StoreKit products load', () async {
    final directory = await Directory.systemTemp.createTemp('mitsumori_v103_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final controller = await openController(directory);
    expect(controller.storeProducts, isEmpty);
    expect(controller.priceFor(PlanLimits.monthlyProductId), '¥100');
    expect(controller.priceFor(PlanLimits.yearlyProductId), '¥1,200');
    expect(controller.trialFor(PlanLimits.monthlyProductId), '1週間');
    expect(controller.trialFor(PlanLimits.yearlyProductId), '1週間');
    controller.dispose();
  });
}
