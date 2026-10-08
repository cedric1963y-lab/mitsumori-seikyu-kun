import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mitsumori_seikyu/data/repository.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/plan/entitlement.dart';
import 'package:mitsumori_seikyu/plan/limits.dart';
import 'package:mitsumori_seikyu/services/purchase_gateway.dart';
import 'package:mitsumori_seikyu/state/app_controller.dart';

import 'fake_purchase_gateway.dart';

Future<ByteData> loadTestFont() async {
  final bytes = await File('assets/fonts/NotoSansJP-Regular.ttf').readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<ByteData> loadTestBoldFont() async {
  final bytes = await File('assets/fonts/NotoSansJP-Bold.ttf').readAsBytes();
  return ByteData.sublistView(bytes);
}

/// Fixed clock: Thursday 8 October 2026, 09:00.
DateTime testNow() => DateTime(2026, 10, 8, 9);

Future<AppController> openController(
  Directory directory, {
  bool premium = false,
  PurchaseGateway? purchases,
  DateTime Function()? now,
}) async {
  final repository = Repository(directory);
  await repository.init();
  final clock = now ?? testNow;
  if (premium) {
    await repository.saveEntitlement(
      Entitlement(
        productId: PlanLimits.monthlyProductId,
        expiresAt: clock().add(const Duration(days: 30)),
      ),
    );
  }
  final controller = AppController(
    repository: repository,
    purchases: purchases ?? FakePurchaseGateway(),
    loadFont: loadTestFont,
    loadBoldFont: loadTestBoldFont,
    now: clock,
  );
  await controller.load();
  return controller;
}

/// Customer + two items + one saved 見積書.
Future<Doc> seedEstimate(AppController c, {String customer = '山田工務店'}) async {
  final cust = c.customers.isEmpty
      ? await c.addCustomer(name: customer, address: '横浜市港北区新横浜1-2-3')
      : c.customers.first;
  final labor = c.items.isEmpty
      ? await c.addItem(name: '内装工事 職人', unit: '人工', unitPrice: 22000)
      : c.items.first;
  final draft = c
      .newDraft(DocKind.estimate)
      .copyWith(
        customerId: cust.id,
        title: '事務所 内装改修',
        lines: [
          DocLine.fromItem(labor, 3),
          const DocLine(
            name: 'クロス張替え',
            quantity: 42.5,
            unit: 'm²',
            unitPrice: 1200,
            taxRate: TaxRate.ten,
          ),
        ],
      );
  return c.saveDocument(draft);
}
