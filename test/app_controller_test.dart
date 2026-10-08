import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/errors.dart';
import 'package:mitsumori_seikyu/format.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/plan/limits.dart';
import 'package:mitsumori_seikyu/services/purchase_gateway.dart';
import 'package:mitsumori_seikyu/state/app_controller.dart';

import 'support/fake_purchase_gateway.dart';
import 'support/harness.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mitsumori_test_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Matcher limit(LimitKind kind) =>
      throwsA(isA<LimitReached>().having((e) => e.kind, 'kind', kind));

  test('free plan: 2 customers and 10 items', () async {
    final c = await openController(directory);
    await c.addCustomer(name: '山田工務店');
    await c.addCustomer(name: '佐藤 一郎', honorific: '様');
    expect(c.canAddCustomer, isFalse);
    expect(() => c.addCustomer(name: '三人目'), limit(LimitKind.customers));
    for (var i = 0; i < PlanLimits.freeItemLimit; i++) {
      await c.addItem(name: '品目$i', unit: '式', unitPrice: 1000);
    }
    expect(
      () => c.addItem(name: '11件目', unit: '式', unitPrice: 1),
      limit(LimitKind.items),
    );
  });

  test('premium has no limits', () async {
    final c = await openController(directory, premium: true);
    for (var i = 0; i < 5; i++) {
      await c.addCustomer(name: '取引先$i');
    }
    for (var i = 0; i < 4; i++) {
      await seedEstimate(c);
    }
    expect(c.customers, hasLength(5));
    expect(c.freeDocumentsLeft, isNull);
  });

  test(
    '3 new documents a month; conversion is free; delete does not refund',
    () async {
      final c = await openController(directory);
      final first = await seedEstimate(c);
      await seedEstimate(c);
      expect(c.freeDocumentsLeft, 1);
      final invoice = await c.convertToInvoice(first.id);
      expect(invoice.kind, DocKind.invoice);
      expect(c.freeDocumentsLeft, 1);
      final third = await seedEstimate(c);
      expect(c.canCreateDocument, isFalse);
      expect(() => c.newDraft(DocKind.invoice), limit(LimitKind.documents));
      await c.deleteDocument(third.id);
      expect(c.canCreateDocument, isFalse);
      // Editing an existing document is always allowed.
      final edited = await c.saveDocument(first.copyWith(title: '変更後'));
      expect(edited.title, '変更後');
    },
  );

  test('allowance resets next month', () async {
    var now = testNow();
    final c = await openController(directory, now: () => now);
    for (var i = 0; i < 3; i++) {
      await seedEstimate(c);
    }
    expect(c.canCreateDocument, isFalse);
    now = DateTime(2026, 11, 2, 9);
    expect(c.canCreateDocument, isTrue);
    expect(c.freeDocumentsLeft, 3);
  });

  test('numbers count up per kind and year', () async {
    final c = await openController(directory, premium: true);
    final a = await seedEstimate(c);
    final b = await seedEstimate(c);
    final inv = await c.convertToInvoice(a.id);
    expect(a.number, 'Q-2026-001');
    expect(b.number, 'Q-2026-002');
    expect(inv.number, 'INV-2026-001');
    final draft = c
        .newDraft(DocKind.estimate)
        .copyWith(
          customerId: c.customers.first.id,
          issueDate: '2027-01-04',
          dueDate: '2027-02-03',
          lines: a.lines,
        );
    expect((await c.saveDocument(draft)).number, 'Q-2027-001');
  });

  test('saving copies the customer and validates input', () async {
    final c = await openController(directory);
    final customer = await c.addCustomer(name: '山田工務店', address: '横浜市');
    final empty = c.newDraft(DocKind.invoice);
    expect(() => c.saveDocument(empty), throwsA(isA<InvalidInput>()));
    final noLines = empty.copyWith(customerId: customer.id);
    expect(() => c.saveDocument(noLines), throwsA(isA<InvalidInput>()));
    final badDue = noLines.copyWith(
      dueDate: '2026-10-01',
      lines: const [
        DocLine(
          name: '作業',
          quantity: 1,
          unit: '式',
          unitPrice: 1000,
          taxRate: TaxRate.ten,
        ),
      ],
    );
    expect(() => c.saveDocument(badDue), throwsA(isA<InvalidInput>()));
    final badQty = noLines.copyWith(
      lines: const [
        DocLine(
          name: '作業',
          quantity: 0,
          unit: '式',
          unitPrice: 1000,
          taxRate: TaxRate.ten,
        ),
      ],
    );
    expect(() => c.saveDocument(badQty), throwsA(isA<InvalidInput>()));
    final saved = await c.saveDocument(badDue.copyWith(dueDate: '2026-11-30'));
    expect(saved.customerName, '山田工務店');
    expect(saved.customerAddress, '横浜市');
    expect(saved.status, DocStatus.unsent);
    // Renaming or deleting the customer keeps the printed name.
    await c.updateCustomer(id: customer.id, name: '山田建設');
    await c.deleteCustomer(customer.id);
    expect(c.documentById(saved.id)!.customerName, '山田工務店');
  });

  test('new drafts default the due date', () async {
    final c = await openController(directory);
    expect(c.newDraft(DocKind.invoice).dueDate, '2026-11-30');
    expect(c.newDraft(DocKind.estimate).dueDate, '2026-11-07');
  });

  test('convert links both ways and only once', () async {
    final c = await openController(directory);
    final estimate = await seedEstimate(c);
    final invoice = await c.convertToInvoice(estimate.id);
    expect(invoice.sourceId, estimate.id);
    expect(invoice.lines.length, estimate.lines.length);
    expect(invoice.dueDate, '2026-11-30');
    final updated = c.documentById(estimate.id)!;
    expect(updated.convertedId, invoice.id);
    expect(updated.status, DocStatus.sent);
    final again = await c.convertToInvoice(estimate.id);
    expect(again.id, invoice.id);
    expect(c.documents.where((d) => d.isInvoice), hasLength(1));
    await c.deleteDocument(invoice.id);
    expect(c.documentById(estimate.id)!.convertedId, isNull);
  });

  test('status, paid date and the unpaid list', () async {
    var now = testNow();
    final c = await openController(directory, premium: true, now: () => now);
    final e1 = await seedEstimate(c);
    final e2 = await seedEstimate(c);
    final i1 = await c.convertToInvoice(e1.id);
    final i2 = await c.saveDocument(
      c
          .newDraft(DocKind.invoice)
          .copyWith(
            customerId: c.customers.first.id,
            dueDate: '2026-10-20',
            lines: e2.lines,
          ),
    );
    expect(c.unpaidInvoices.map((d) => d.id), [i2.id, i1.id]);
    final total1 = c.totalsFor(i1).total;
    expect(c.unpaidTotal, total1 * 2);
    expect(
      () => c.setStatus(e1.id, DocStatus.paid),
      throwsA(isA<InvalidInput>()),
    );
    await c.setStatus(i1.id, DocStatus.paid);
    expect(c.documentById(i1.id)!.paidDate, '2026-10-08');
    expect(c.unpaidInvoices.map((d) => d.id), [i2.id]);
    await c.setStatus(i1.id, DocStatus.sent);
    expect(c.documentById(i1.id)!.paidDate, isNull);
    now = DateTime(2026, 10, 21);
    expect(c.overdueCount, 1);
    expect(c.documentById(i2.id)!.isOverdue(now), isTrue);
  });

  test(
    'free plan lists two months plus unpaid invoices; search is premium',
    () async {
      var now = DateTime(2026, 7, 10, 9);
      final c = await openController(directory, now: () => now);
      final old = await seedEstimate(c);
      final oldInvoice = await c.convertToInvoice(old.id);
      now = DateTime(2026, 10, 8, 9);
      final recent = await seedEstimate(c);
      final listed = c.listDocuments().map((d) => d.id).toList();
      expect(listed, contains(recent.id));
      expect(listed, contains(oldInvoice.id));
      expect(listed, isNot(contains(old.id)));
      expect(c.hiddenDocumentCount, 1);
      expect(() => c.listDocuments(query: '山田'), limit(LimitKind.history));
      await c.setStatus(oldInvoice.id, DocStatus.paid);
      expect(c.hiddenDocumentCount, 2);
      expect(c.listDocuments(filter: DocFilter.invoices), isEmpty);
    },
  );

  test('premium search matches number, customer, title and lines', () async {
    final c = await openController(directory, premium: true);
    final a = await seedEstimate(c);
    final b = await c.saveDocument(
      c
          .newDraft(DocKind.estimate)
          .copyWith(
            customerId: (await c.addCustomer(name: '佐藤 一郎', honorific: '様')).id,
            title: '外構 フェンス',
            lines: const [
              DocLine(
                name: 'アルミフェンス',
                quantity: 12,
                unit: 'm',
                unitPrice: 8500,
                taxRate: TaxRate.ten,
              ),
            ],
          ),
    );
    expect(c.listDocuments(query: 'フェンス').map((d) => d.id), [b.id]);
    expect(c.listDocuments(query: '山田').map((d) => d.id), [a.id]);
    expect(c.listDocuments(query: 'q-2026-002').map((d) => d.id), [b.id]);
    expect(c.listDocuments(query: 'クロス').map((d) => d.id), [a.id]);
    expect(c.listDocuments(filter: DocFilter.invoices), isEmpty);
  });

  test('profile validates the registration number', () async {
    final c = await openController(directory);
    expect(
      () => c.saveProfile(
        const BusinessProfile(name: '鈴木内装', registrationNumber: 'T123'),
      ),
      throwsA(isA<InvalidInput>()),
    );
    expect(
      () => c.saveProfile(const BusinessProfile()),
      throwsA(isA<InvalidInput>()),
    );
    await c.saveProfile(
      const BusinessProfile(
        name: ' 鈴木内装 ',
        address: '横浜市港北区\n\n',
        bank: '○○銀行 港北支店\n普通 1234567',
        registrationNumber: 'ｔ１２３４５６７８９０１２３',
      ),
    );
    expect(c.profile.name, '鈴木内装');
    expect(c.profile.address, '横浜市港北区');
    expect(c.profile.registrationNumber, 'T1234567890123');
    final reopened = await openController(directory);
    expect(reopened.profile.bank, '○○銀行 港北支店\n普通 1234567');
  });

  test('seal is premium only and survives a restart', () async {
    final free = await openController(directory);
    final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
    expect(() => free.setSeal(png), limit(LimitKind.seal));
    final premium = await openController(directory, premium: true);
    await premium.setSeal(png);
    final reopened = await openController(directory, premium: true);
    expect(reopened.seal, png);
    await reopened.removeSeal();
    expect((await openController(directory)).seal, isNull);
  });

  test('PDF renders for both kinds; CSV is premium', () async {
    final c = await openController(directory);
    await c.saveProfile(
      const BusinessProfile(
        name: '鈴木内装',
        bank: '○○銀行',
        registrationNumber: 'T1234567890123',
      ),
    );
    final estimate = await seedEstimate(c);
    final invoice = await c.convertToInvoice(estimate.id);
    for (final doc in [estimate, invoice]) {
      final bytes = await c.pdfBytesFor(doc);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    }
    final path = await c.exportPdf(invoice);
    expect(path, endsWith('請求書_INV-2026-001_山田工務店.pdf'));
    expect(File(path).existsSync(), isTrue);
    expect(() => c.exportCsv(), limit(LimitKind.csv));

    final p = await openController(directory, premium: true);
    final csvPath = await p.exportCsv();
    final raw = File(csvPath).readAsBytesSync();
    expect(raw.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final csv = utf8.decode(raw.sublist(3));
    expect(csv, startsWith('種類,番号,発行日'));
    expect(
      csv,
      contains(
        '請求書,INV-2026-001,2026/10/08,山田工務店 御中,事務所 内装改修,117000,11700,0,0,0,128700,未送付,2026/11/30,',
      ),
    );
  });

  test('a long document still renders', () async {
    final c = await openController(directory, premium: true);
    final customer = await c.addCustomer(name: '山田工務店');
    final doc = await c.saveDocument(
      c
          .newDraft(DocKind.invoice)
          .copyWith(
            customerId: customer.id,
            lines: [
              for (var i = 0; i < 60; i++)
                DocLine(
                  name: '材料 $i',
                  quantity: 1,
                  unit: '個',
                  unitPrice: 100 + i,
                  taxRate: i.isEven ? TaxRate.ten : TaxRate.eight,
                ),
            ],
            note: '振込手数料はご負担ください。',
          ),
    );
    final bytes = await c.pdfBytesFor(doc);
    expect(bytes.length, greaterThan(1000));
  });

  test('everything persists across a restart', () async {
    final c = await openController(directory);
    final e = await seedEstimate(c);
    await c.convertToInvoice(e.id);
    final reopened = await openController(directory);
    expect(reopened.documents, hasLength(2));
    expect(reopened.customers, hasLength(1));
    expect(reopened.items, hasLength(1));
    expect(reopened.documentsCreatedThisMonth, 1);
    final next = await seedEstimate(reopened);
    expect(next.number, 'Q-2026-002');
  });

  test('purchase events unlock and restore reports nothing found', () async {
    final gateway = FakePurchaseGateway(subscriptions: const []);
    final c = await openController(directory, purchases: gateway);
    expect(c.premium, isFalse);
    await c.buyPlan(PlanLimits.yearlyProductId);
    expect(gateway.lastProductId, PlanLimits.yearlyProductId);
    await gateway.emit(
      PurchaseEvent.unlocked(
        productId: PlanLimits.yearlyProductId,
        expiresAt: testNow().add(const Duration(days: 365)),
      ),
    );
    expect(c.premium, isTrue);
    expect(c.canAddCustomer, isTrue);

    final other = await Directory.systemTemp.createTemp('mitsumori_restore_');
    addTearDown(() => other.delete(recursive: true));
    final c2 = await openController(
      other,
      purchases: FakePurchaseGateway(subscriptions: const []),
    );
    await c2.restorePremium();
    expect(c2.purchasePhase, PurchasePhase.error);
    expect(c2.purchaseError, contains('見つかりません'));
  });

  test('store products carry the trial label only when eligible', () async {
    final gateway = FakePurchaseGateway(
      products: const [
        StoreProduct(
          id: PlanLimits.monthlyProductId,
          priceLabel: '¥100',
          title: '月額',
          trialLabel: '1週間',
        ),
        StoreProduct(
          id: PlanLimits.yearlyProductId,
          priceLabel: '¥1,200',
          title: '年額',
        ),
      ],
    );
    final c = await openController(directory, purchases: gateway);
    await c.refreshProduct();
    expect(c.trialFor(PlanLimits.monthlyProductId), '1週間');
    expect(c.trialFor(PlanLimits.yearlyProductId), isNull);
    expect(c.priceFor(PlanLimits.yearlyProductId), '¥1,200');
    expect(formatYen(PlanLimits.yearlyPriceYen), PlanLimits.yearlyPriceLabel);
  });
}
