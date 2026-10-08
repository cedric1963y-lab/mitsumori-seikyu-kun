import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../errors.dart';
import '../format.dart';
import '../ids.dart';
import '../logic/csv.dart';
import '../logic/totals.dart';
import '../models/models.dart';
import '../plan/entitlement.dart';
import '../plan/limits.dart';
import '../services/pdf_document.dart';
import '../services/purchase_gateway.dart';

enum PurchasePhase { idle, pending, error }

enum DocFilter { all, estimates, invoices }

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.purchases,
    Future<ByteData> Function()? loadFont,
    Future<ByteData> Function()? loadBoldFont,
    DateTime Function()? now,
    this.demoPremium = false,
  }) : _loadFont = loadFont ?? _loadBundledFont,
       _loadBoldFont = loadBoldFont ?? _loadBundledBoldFont,
       _now = now ?? DateTime.now;

  final Repository repository;
  final PurchaseGateway purchases;
  final Future<ByteData> Function() _loadFont;
  final Future<ByteData> Function() _loadBoldFont;
  final DateTime Function() _now;

  /// Debug builds only: shows the premium state for store screenshots.
  final bool demoPremium;

  BusinessProfile profile = const BusinessProfile();
  List<Customer> customers = [];
  List<Item> items = [];
  List<Doc> documents = [];
  Uint8List? seal;
  Entitlement entitlement = const Entitlement();
  PurchasePhase purchasePhase = PurchasePhase.idle;
  String? purchaseError;
  List<StoreProduct> storeProducts = [];

  /// Last number used per `PREFIX-YEAR`, for example `{'INV-2026': 12}`.
  Map<String, int> _counters = {};

  /// New documents created per month (`YYYY-MM`). Deleting a document does
  /// not give the free allowance back.
  Map<String, int> _created = {};
  ByteData? _font;
  ByteData? _boldFont;

  DateTime get now => _now();

  bool get premium => demoPremium || entitlement.isActiveAt(_now());

  bool get canAddCustomer =>
      PlanLimits.canAddCustomer(premium: premium, count: customers.length);

  bool get canAddItem =>
      PlanLimits.canAddItem(premium: premium, count: items.length);

  String get _monthKey => dayKey(_now()).substring(0, 7);

  int get documentsCreatedThisMonth => _created[_monthKey] ?? 0;

  /// Free documents left this month, or null on premium.
  int? get freeDocumentsLeft => premium
      ? null
      : (PlanLimits.freeDocumentsPerMonth - documentsCreatedThisMonth).clamp(
          0,
          PlanLimits.freeDocumentsPerMonth,
        );

  bool get canCreateDocument => PlanLimits.canCreateDocument(
    premium: premium,
    createdThisMonth: documentsCreatedThisMonth,
  );

  String priceFor(String productId) {
    for (final product in storeProducts) {
      if (product.id == productId) return product.priceLabel;
    }
    return PlanLimits.priceLabelFor(productId);
  }

  /// `1週間` when the App Store offers this Apple ID the free trial.
  String? trialFor(String productId) {
    for (final product in storeProducts) {
      if (product.id == productId) return product.trialLabel;
    }
    return null;
  }

  Future<void> load() async {
    await repository.init();
    customers = await repository.loadCustomers();
    items = await repository.loadItems();
    documents = await repository.loadDocuments();
    seal = await repository.loadSeal();
    entitlement = await repository.loadEntitlement();
    final settings = await repository.loadSettings();
    profile = BusinessProfile.fromJson(settings['profile']);
    _counters = _intMap(settings['counters']);
    _created = _intMap(settings['created']);
    try {
      await purchases.start(_onPurchase);
      await _applyStoreSubscriptions();
    } catch (_) {
      // Documents still work when StoreKit cannot start.
    }
    notifyListeners();
  }

  static Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }

  Future<void> _applyStoreSubscriptions() async {
    final found = await purchases.currentSubscriptions();
    if (found == null) return;
    final active = activeSubscription(found, _now());
    entitlement = active == null
        ? const Entitlement()
        : Entitlement(productId: active.productId, expiresAt: active.expiresAt);
    await repository.saveEntitlement(entitlement);
  }

  Future<void> _saveSettings() {
    return repository.saveSettings({
      'profile': profile.toJson(),
      'counters': _counters,
      'created': _created,
    });
  }

  // ---------------------------------------------------------------- profile

  Future<void> saveProfile(BusinessProfile draft) async {
    final number = normalizeRegistrationNumber(draft.registrationNumber);
    if (number == null) {
      throw const InvalidInput('登録番号は「T」と13桁の数字で入力してください（例: T1234567890123）。');
    }
    profile = BusinessProfile(
      name: _requiredLine(draft.name, '屋号または氏名', 40),
      postalCode: _optionalLine(draft.postalCode, 10),
      address: _optionalText(draft.address, 80, maxLines: 2),
      phone: _optionalLine(draft.phone, 20),
      email: _optionalLine(draft.email, 60),
      bank: _optionalText(draft.bank, 120, maxLines: 3),
      registrationNumber: number,
    );
    await _saveSettings();
    notifyListeners();
  }

  /// 印影 / ロゴ is a premium feature. [png] is already downscaled.
  Future<void> setSeal(Uint8List png) async {
    if (!premium) throw const LimitReached(LimitKind.seal);
    if (png.isEmpty) throw const InvalidInput('画像を読み込めませんでした。');
    await repository.saveSeal(png);
    seal = png;
    notifyListeners();
  }

  Future<void> removeSeal() async {
    await repository.saveSeal(null);
    seal = null;
    notifyListeners();
  }

  // -------------------------------------------------------------- customers

  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Customer> addCustomer({
    required String name,
    String honorific = '御中',
    String address = '',
  }) async {
    if (!canAddCustomer) throw const LimitReached(LimitKind.customers);
    final customer = Customer(
      id: createId(),
      name: _requiredLine(name, '取引先名', 40),
      honorific: honorific == '様' ? '様' : '御中',
      address: _optionalText(address, 80, maxLines: 2),
      createdAt: _now(),
    );
    customers = [...customers, customer];
    await repository.saveCustomers(customers);
    notifyListeners();
    return customer;
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    String honorific = '御中',
    String address = '',
  }) async {
    final index = customers.indexWhere((c) => c.id == id);
    if (index < 0) throw const InvalidInput('取引先が見つかりません。');
    customers = [...customers]
      ..[index] = customers[index].copyWith(
        name: _requiredLine(name, '取引先名', 40),
        honorific: honorific == '様' ? '様' : '御中',
        address: _optionalText(address, 80, maxLines: 2),
      );
    await repository.saveCustomers(customers);
    notifyListeners();
  }

  /// Documents keep their own copy of the customer name and stay.
  Future<void> deleteCustomer(String id) async {
    customers = customers.where((c) => c.id != id).toList();
    await repository.saveCustomers(customers);
    notifyListeners();
  }

  int documentCountForCustomer(String id) =>
      documents.where((d) => d.customerId == id).length;

  // ------------------------------------------------------------------ items

  Future<Item> addItem({
    required String name,
    required String unit,
    required int unitPrice,
    TaxRate taxRate = TaxRate.ten,
  }) async {
    if (!canAddItem) throw const LimitReached(LimitKind.items);
    final item = Item(
      id: createId(),
      name: _requiredLine(name, '品目名', 40),
      unit: _requiredLine(unit, '単位', 6),
      unitPrice: _price(unitPrice),
      taxRate: taxRate,
      createdAt: _now(),
    );
    items = [...items, item];
    await repository.saveItems(items);
    notifyListeners();
    return item;
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required String unit,
    required int unitPrice,
    required TaxRate taxRate,
  }) async {
    final index = items.indexWhere((i) => i.id == id);
    if (index < 0) throw const InvalidInput('品目が見つかりません。');
    items = [...items]
      ..[index] = items[index].copyWith(
        name: _requiredLine(name, '品目名', 40),
        unit: _requiredLine(unit, '単位', 6),
        unitPrice: _price(unitPrice),
        taxRate: taxRate,
      );
    await repository.saveItems(items);
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    items = items.where((i) => i.id != id).toList();
    await repository.saveItems(items);
    notifyListeners();
  }

  // -------------------------------------------------------------- documents

  Doc? documentById(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  static int _byNewest(Doc a, Doc b) {
    final date = b.issueDate.compareTo(a.issueDate);
    if (date != 0) return date;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Oldest issue date the free plan lists (start of last month).
  DateTime get _freeHistoryStart =>
      addMonths(firstOfMonth(_now()), 1 - PlanLimits.freeHistoryMonths);

  /// Whether the free plan lists [doc]. Unpaid invoices always show.
  bool isVisible(Doc doc) {
    if (premium || doc.isUnpaid) return true;
    return !doc.issued.isBefore(_freeHistoryStart);
  }

  /// Count of documents the free plan hides as 過去の履歴.
  int get hiddenDocumentCount =>
      premium ? 0 : documents.where((d) => !isVisible(d)).length;

  /// Newest first. [query] (premium) matches number, customer, 件名 and
  /// line names.
  List<Doc> listDocuments({
    DocFilter filter = DocFilter.all,
    String query = '',
  }) {
    final q = collapseWhitespace(query).toLowerCase();
    if (q.isNotEmpty && !premium) throw const LimitReached(LimitKind.history);
    final result = documents.where((d) {
      if (filter == DocFilter.estimates && d.kind != DocKind.estimate) {
        return false;
      }
      if (filter == DocFilter.invoices && d.kind != DocKind.invoice) {
        return false;
      }
      if (!isVisible(d)) return false;
      if (q.isEmpty) return true;
      final haystack = [
        d.number,
        d.customerName,
        d.title,
        d.note,
        for (final l in d.lines) l.name,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList()..sort(_byNewest);
    return result;
  }

  /// Unpaid invoices, earliest due date first.
  List<Doc> get unpaidInvoices {
    final list = documents.where((d) => d.isUnpaid).toList();
    list.sort((a, b) {
      final da = a.dueDate ?? '9999-12-31';
      final db = b.dueDate ?? '9999-12-31';
      final c = da.compareTo(db);
      return c != 0 ? c : a.issueDate.compareTo(b.issueDate);
    });
    return list;
  }

  int get unpaidTotal =>
      unpaidInvoices.fold(0, (sum, d) => sum + totalsFor(d).total);

  int get overdueCount =>
      unpaidInvoices.where((d) => d.isOverdue(_now())).length;

  /// 請求書 total issued this month.
  int get invoicedThisMonth => documents
      .where((d) => d.isInvoice && isSameMonth(d.issued, _now()))
      .fold(0, (sum, d) => sum + totalsFor(d).total);

  DocTotals totalsFor(Doc doc) => computeTotals(doc.lines);

  /// A blank draft for the editor. Throws when the free allowance is used.
  Doc newDraft(DocKind kind) {
    if (!canCreateDocument) throw const LimitReached(LimitKind.documents);
    final today = dateOnly(_now());
    return Doc(
      id: '',
      kind: kind,
      number: '',
      customerId: '',
      customerName: '',
      honorific: '御中',
      customerAddress: '',
      title: '',
      issueDate: dayKey(today),
      dueDate: dayKey(
        kind == DocKind.invoice
            ? endOfNextMonth(today)
            : today.add(const Duration(days: 30)),
      ),
      lines: const [],
      note: '',
      status: DocStatus.unsent,
      createdAt: _now(),
    );
  }

  String _nextNumber(DocKind kind, DateTime issued) {
    final key = '${kind.prefix}-${issued.year}';
    final next = (_counters[key] ?? 0) + 1;
    _counters = {..._counters, key: next};
    return '$key-${next.toString().padLeft(3, '0')}';
  }

  Doc _validated(Doc draft) {
    final customer = customerById(draft.customerId);
    if (customer == null && draft.customerName.isEmpty) {
      throw const InvalidInput('取引先を選んでください。');
    }
    if (draft.lines.isEmpty) {
      throw const InvalidInput('明細を1行以上追加してください。');
    }
    for (final line in draft.lines) {
      _validLine(line);
    }
    final due = draft.due;
    if (due != null && due.isBefore(draft.issued)) {
      throw InvalidInput('${draft.kind.dueLabel}は発行日以降にしてください。');
    }
    return draft.copyWith(
      customerName: customer?.name ?? draft.customerName,
      honorific: customer?.honorific ?? draft.honorific,
      customerAddress: customer?.address ?? draft.customerAddress,
      title: _optionalLine(draft.title, 40),
      note: _optionalText(draft.note, 300, maxLines: 8),
    );
  }

  DocLine _validLine(DocLine line) {
    if (collapseWhitespace(line.name).isEmpty) {
      throw const InvalidInput('品目名を入力してください。');
    }
    if (line.quantity <= 0 || line.quantity > 100000) {
      throw const InvalidInput('数量は0より大きく、100,000以下で入力してください。');
    }
    _price(line.unitPrice);
    return line;
  }

  /// Saves a new or edited document and returns the stored copy.
  Future<Doc> saveDocument(Doc draft) async {
    final isNew = draft.id.isEmpty;
    if (isNew && !canCreateDocument) {
      throw const LimitReached(LimitKind.documents);
    }
    var doc = _validated(draft);
    if (isNew) {
      doc = Doc(
        id: createId(),
        kind: doc.kind,
        number: _nextNumber(doc.kind, doc.issued),
        customerId: doc.customerId,
        customerName: doc.customerName,
        honorific: doc.honorific,
        customerAddress: doc.customerAddress,
        title: doc.title,
        issueDate: doc.issueDate,
        dueDate: doc.dueDate,
        lines: doc.lines,
        note: doc.note,
        status: DocStatus.unsent,
        createdAt: _now(),
      );
      _created = {..._created, _monthKey: documentsCreatedThisMonth + 1};
      documents = [...documents, doc];
    } else {
      final index = documents.indexWhere((d) => d.id == doc.id);
      if (index < 0) throw const InvalidInput('書類が見つかりません。');
      documents = [...documents]..[index] = doc;
    }
    await repository.saveDocuments(documents);
    if (isNew) await _saveSettings();
    notifyListeners();
    return doc;
  }

  /// One tap 見積書 -> 請求書. Free on every plan and not counted in the
  /// monthly allowance. Returns the new 請求書, or the one made before.
  Future<Doc> convertToInvoice(String estimateId) async {
    final estimate = documentById(estimateId);
    if (estimate == null || estimate.kind != DocKind.estimate) {
      throw const InvalidInput('見積書が見つかりません。');
    }
    final existing = estimate.convertedId == null
        ? null
        : documentById(estimate.convertedId!);
    if (existing != null) return existing;
    final today = dateOnly(_now());
    final invoice = Doc(
      id: createId(),
      kind: DocKind.invoice,
      number: _nextNumber(DocKind.invoice, today),
      customerId: estimate.customerId,
      customerName: estimate.customerName,
      honorific: estimate.honorific,
      customerAddress: estimate.customerAddress,
      title: estimate.title,
      issueDate: dayKey(today),
      dueDate: dayKey(endOfNextMonth(today)),
      lines: estimate.lines,
      note: estimate.note,
      status: DocStatus.unsent,
      createdAt: _now(),
      sourceId: estimate.id,
    );
    documents = [
      for (final d in documents)
        if (d.id == estimate.id)
          d.copyWith(
            convertedId: invoice.id,
            status: d.status == DocStatus.unsent ? DocStatus.sent : d.status,
          )
        else
          d,
      invoice,
    ];
    await repository.saveDocuments(documents);
    await _saveSettings();
    notifyListeners();
    return invoice;
  }

  Future<void> setStatus(String id, DocStatus status) async {
    final index = documents.indexWhere((d) => d.id == id);
    if (index < 0) throw const InvalidInput('書類が見つかりません。');
    final doc = documents[index];
    if (status == DocStatus.paid && !doc.isInvoice) {
      throw const InvalidInput('入金済にできるのは請求書だけです。');
    }
    documents = [...documents]
      ..[index] = doc.copyWith(
        status: status,
        paidDate: status == DocStatus.paid ? dayKey(_now()) : null,
        clearPaidDate: status != DocStatus.paid,
      );
    await repository.saveDocuments(documents);
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    documents = [
      for (final d in documents)
        if (d.id != id)
          if (d.convertedId == id)
            d.copyWith(clearConvertedId: true)
          else if (d.sourceId == id)
            d.copyWith(clearSourceId: true)
          else
            d,
    ];
    await repository.saveDocuments(documents);
    notifyListeners();
  }

  // ---------------------------------------------------------------- outputs

  /// A4 portrait PDF. The free plan adds a small footer and leaves out the
  /// 印影 / ロゴ.
  Future<Uint8List> pdfBytesFor(Doc doc) async {
    return buildDocumentPdf(
      fontData: await _fontData(),
      boldFontData: _boldFont ??= await _loadBoldFont(),
      doc: doc,
      totals: totalsFor(doc),
      profile: profile,
      seal: premium ? seal : null,
      footer: premium ? null : PlanLimits.freeFooter,
    );
  }

  String fileNameFor(Doc doc, String extension) => documentFileName(
    kindLabel: doc.kind.label,
    number: doc.number,
    customer: doc.customerName,
    extension: extension,
  );

  Future<String> exportPdf(Doc doc) async {
    final bytes = await pdfBytesFor(doc);
    return repository.writeExport(fileNameFor(doc, 'pdf'), bytes);
  }

  /// Every document as CSV (premium).
  Future<String> exportCsv() async {
    if (!premium) throw const LimitReached(LimitKind.csv);
    final sorted = [...documents]..sort(_byNewest);
    final csv = documentsAsCsv(sorted);
    final stamp = dayKey(_now()).replaceAll('-', '');
    return repository.writeExport(
      '見積請求一覧_$stamp.csv',
      Uint8List.fromList(utf8.encode(csv)),
    );
  }

  // -------------------------------------------------------------- purchases

  Future<void> refreshProduct() async {
    try {
      storeProducts = await purchases.loadProducts();
    } catch (_) {
      storeProducts = [];
    }
    notifyListeners();
  }

  Future<void> buyPlan(String productId) async {
    if (purchasePhase == PurchasePhase.pending) return;
    if (!PlanLimits.isPremiumProduct(productId)) return;
    if (entitlement.isActiveAt(_now()) && entitlement.productId == productId) {
      return;
    }
    purchasePhase = PurchasePhase.pending;
    purchaseError = null;
    notifyListeners();
    try {
      await purchases.buy(productId);
    } on StoreUnavailable catch (error) {
      purchasePhase = PurchasePhase.error;
      purchaseError = error.message;
      notifyListeners();
    } catch (_) {
      purchasePhase = PurchasePhase.error;
      purchaseError = '購入を開始できませんでした。通信状況を確認してください。';
      notifyListeners();
    }
  }

  Future<void> restorePremium() async {
    if (purchasePhase == PurchasePhase.pending) return;
    purchasePhase = PurchasePhase.pending;
    purchaseError = null;
    notifyListeners();
    final already = premium;
    try {
      await purchases.restore();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (purchasePhase == PurchasePhase.pending && !premium && !already) {
        purchasePhase = PurchasePhase.error;
        purchaseError = '復元できる契約は見つかりませんでした。契約したApple IDでサインインしているか確認してください。';
      } else if (purchasePhase == PurchasePhase.pending) {
        purchasePhase = PurchasePhase.idle;
      }
    } on StoreUnavailable catch (error) {
      purchasePhase = PurchasePhase.error;
      purchaseError = error.message;
    } catch (_) {
      purchasePhase = PurchasePhase.error;
      purchaseError = '復元できませんでした。通信状況を確認してください。';
    }
    notifyListeners();
  }

  Future<void> _onPurchase(PurchaseEvent event) async {
    switch (event.kind) {
      case PurchaseEventKind.unlocked:
        final productId = event.productId;
        final expiresAt = event.expiresAt;
        if (productId == null ||
            expiresAt == null ||
            !PlanLimits.isPremiumProduct(productId) ||
            !expiresAt.isAfter(_now())) {
          purchasePhase = PurchasePhase.error;
          purchaseError = '有効な契約は見つかりませんでした。期限が切れている場合は、月額または年額を開始してください。';
          break;
        }
        entitlement = Entitlement(productId: productId, expiresAt: expiresAt);
        purchasePhase = PurchasePhase.idle;
        purchaseError = null;
        try {
          await repository.saveEntitlement(entitlement);
        } catch (_) {
          purchasePhase = PurchasePhase.error;
          purchaseError = '契約は確認できましたが、端末への保存に失敗しました。この画面を開いたまま、もう一度お試しください。';
        }
      case PurchaseEventKind.pending:
        purchasePhase = PurchasePhase.pending;
        purchaseError = null;
      case PurchaseEventKind.canceled:
        if (purchasePhase == PurchasePhase.pending) {
          purchasePhase = PurchasePhase.idle;
        }
      case PurchaseEventKind.error:
        purchasePhase = PurchasePhase.error;
        purchaseError = event.message ?? '購入できませんでした。';
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- helpers

  Future<ByteData> _fontData() async => _font ??= await _loadFont();

  static Future<ByteData> _loadBundledFont() {
    return rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
  }

  static Future<ByteData> _loadBundledBoldFont() {
    return rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
  }

  String _requiredLine(String input, String label, int max) {
    final text = collapseWhitespace(input.replaceAll('\n', ' '));
    if (text.isEmpty) throw InvalidInput('$labelを入力してください。');
    if (text.length > max) throw InvalidInput('$labelは$max文字までです。');
    return text;
  }

  String _optionalLine(String input, int max) {
    final text = collapseWhitespace(input.replaceAll('\n', ' '));
    if (text.length > max) throw InvalidInput('$max文字までにしてください。');
    return text;
  }

  String _optionalText(String input, int max, {required int maxLines}) {
    final lines = input.split('\n').map(collapseWhitespace).toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    while (lines.isNotEmpty && lines.first.isEmpty) {
      lines.removeAt(0);
    }
    final text = lines.join('\n');
    if (text.length > max) throw InvalidInput('$max文字までにしてください。');
    if (lines.length > maxLines) {
      throw InvalidInput('$maxLines行までにしてください。');
    }
    return text;
  }

  int _price(int value) {
    if (value < -10000000 || value > 100000000) {
      throw const InvalidInput('単価は-10,000,000〜100,000,000円で入力してください。');
    }
    return value;
  }

  @override
  void dispose() {
    purchases.dispose();
    super.dispose();
  }
}
