import '../format.dart';

/// 消費税の区分。Prices are entered without tax (外税).
enum TaxRate {
  ten('ten', 10, '10%'),
  eight('eight', 8, '8%（軽減）'),
  exempt('exempt', 0, '非課税');

  const TaxRate(this.key, this.percent, this.label);

  final String key;
  final int percent;
  final String label;

  static TaxRate fromKey(Object? key) {
    for (final rate in values) {
      if (rate.key == key) return rate;
    }
    return TaxRate.ten;
  }
}

enum DocKind {
  estimate('estimate', '見積書', '見積', 'Q'),
  invoice('invoice', '請求書', '請求', 'INV');

  const DocKind(this.key, this.label, this.shortLabel, this.prefix);

  final String key;
  final String label;
  final String shortLabel;
  final String prefix;

  /// 有効期限 for a 見積書, 支払期限 for a 請求書.
  String get dueLabel => this == DocKind.estimate ? '有効期限' : '支払期限';

  static DocKind fromKey(Object? key) =>
      key == 'invoice' ? DocKind.invoice : DocKind.estimate;
}

enum DocStatus {
  unsent('unsent', '未送付'),
  sent('sent', '送付済'),
  paid('paid', '入金済');

  const DocStatus(this.key, this.label);

  final String key;
  final String label;

  static DocStatus fromKey(Object? key) {
    for (final status in values) {
      if (status.key == key) return status;
    }
    return DocStatus.unsent;
  }
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime _time(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// 自社情報, printed on every document.
class BusinessProfile {
  const BusinessProfile({
    this.name = '',
    this.postalCode = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.bank = '',
    this.registrationNumber = '',
  });

  /// 屋号または氏名.
  final String name;
  final String postalCode;
  final String address;
  final String phone;
  final String email;

  /// 振込先, free text over several lines.
  final String bank;

  /// 適格請求書発行事業者 登録番号 (`T` + 13 digits), or ''.
  final String registrationNumber;

  bool get isEmpty => name.isEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'postalCode': postalCode,
    'address': address,
    'phone': phone,
    'email': email,
    'bank': bank,
    'registrationNumber': registrationNumber,
  };

  static BusinessProfile fromJson(Object? json) {
    if (json is! Map) return const BusinessProfile();
    return BusinessProfile(
      name: _string(json['name']),
      postalCode: _string(json['postalCode']),
      address: _string(json['address']),
      phone: _string(json['phone']),
      email: _string(json['email']),
      bank: _string(json['bank']),
      registrationNumber: _string(json['registrationNumber']),
    );
  }
}

/// 取引先.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.honorific,
    required this.address,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// `御中` for companies, `様` for people.
  final String honorific;
  final String address;
  final DateTime createdAt;

  Customer copyWith({String? name, String? honorific, String? address}) {
    return Customer(
      id: id,
      name: name ?? this.name,
      honorific: honorific ?? this.honorific,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'honorific': honorific,
    'address': address,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static Customer fromJson(Map<String, dynamic> json) => Customer(
    id: _string(json['id']),
    name: _string(json['name']),
    honorific: json['honorific'] == '様' ? '様' : '御中',
    address: _string(json['address']),
    createdAt: _time(json['createdAt']),
  );
}

/// 品目マスタ.
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 式 / 人工 / m² / 個 …
  final String unit;
  final int unitPrice;
  final TaxRate taxRate;
  final DateTime createdAt;

  Item copyWith({
    String? name,
    String? unit,
    int? unitPrice,
    TaxRate? taxRate,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'unitPrice': unitPrice,
    'taxRate': taxRate.key,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static Item fromJson(Map<String, dynamic> json) => Item(
    id: _string(json['id']),
    name: _string(json['name']),
    unit: _string(json['unit']),
    unitPrice: _int(json['unitPrice']),
    taxRate: TaxRate.fromKey(json['taxRate']),
    createdAt: _time(json['createdAt']),
  );
}

/// One row of a 見積書 or 請求書. A copy, so editing the item master later
/// never changes a document that was already sent.
class DocLine {
  const DocLine({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
  });

  final String name;
  final double quantity;
  final String unit;
  final int unitPrice;
  final TaxRate taxRate;

  /// 数量 × 単価, rounded to the yen per line.
  int get amount => (quantity * unitPrice).round();

  DocLine copyWith({
    String? name,
    double? quantity,
    String? unit,
    int? unitPrice,
    TaxRate? taxRate,
  }) {
    return DocLine(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'taxRate': taxRate.key,
  };

  static DocLine fromJson(Map<String, dynamic> json) => DocLine(
    name: _string(json['name']),
    quantity: _double(json['quantity']),
    unit: _string(json['unit']),
    unitPrice: _int(json['unitPrice']),
    taxRate: TaxRate.fromKey(json['taxRate']),
  );

  static DocLine fromItem(Item item, double quantity) => DocLine(
    name: item.name,
    quantity: quantity,
    unit: item.unit,
    unitPrice: item.unitPrice,
    taxRate: item.taxRate,
  );
}

/// 見積書 or 請求書.
class Doc {
  const Doc({
    required this.id,
    required this.kind,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.honorific,
    required this.customerAddress,
    required this.title,
    required this.issueDate,
    required this.dueDate,
    required this.lines,
    required this.note,
    required this.status,
    required this.createdAt,
    this.paidDate,
    this.sourceId,
    this.convertedId,
  });

  final String id;
  final DocKind kind;

  /// `Q-2026-001` / `INV-2026-001`.
  final String number;
  final String customerId;

  /// Copied from the customer when saved, so the document still prints the
  /// same after the customer is edited or deleted.
  final String customerName;
  final String honorific;
  final String customerAddress;

  /// 件名.
  final String title;

  /// [dayKey] strings.
  final String issueDate;
  final String? dueDate;
  final List<DocLine> lines;

  /// 備考.
  final String note;
  final DocStatus status;
  final DateTime createdAt;
  final String? paidDate;

  /// For a 請求書 made from a 見積書: the 見積書 id.
  final String? sourceId;

  /// For a 見積書 turned into a 請求書: the 請求書 id.
  final String? convertedId;

  DateTime get issued => parseDayKey(issueDate);

  DateTime? get due => dueDate == null ? null : parseDayKey(dueDate!);

  bool get isInvoice => kind == DocKind.invoice;

  bool get isUnpaid => isInvoice && status != DocStatus.paid;

  bool isOverdue(DateTime now) {
    final d = due;
    if (!isUnpaid || d == null) return false;
    return dateOnly(now).isAfter(d);
  }

  Doc copyWith({
    String? number,
    String? customerId,
    String? customerName,
    String? honorific,
    String? customerAddress,
    String? title,
    String? issueDate,
    String? dueDate,
    bool clearDueDate = false,
    List<DocLine>? lines,
    String? note,
    DocStatus? status,
    String? paidDate,
    bool clearPaidDate = false,
    String? convertedId,
    bool clearConvertedId = false,
    bool clearSourceId = false,
  }) {
    return Doc(
      id: id,
      kind: kind,
      number: number ?? this.number,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      honorific: honorific ?? this.honorific,
      customerAddress: customerAddress ?? this.customerAddress,
      title: title ?? this.title,
      issueDate: issueDate ?? this.issueDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      lines: lines ?? this.lines,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      sourceId: clearSourceId ? null : sourceId,
      convertedId: clearConvertedId ? null : (convertedId ?? this.convertedId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.key,
    'number': number,
    'customerId': customerId,
    'customerName': customerName,
    'honorific': honorific,
    'customerAddress': customerAddress,
    'title': title,
    'issueDate': issueDate,
    'dueDate': ?dueDate,
    'lines': [for (final l in lines) l.toJson()],
    'note': note,
    'status': status.key,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'paidDate': ?paidDate,
    'sourceId': ?sourceId,
    'convertedId': ?convertedId,
  };

  static Doc fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    String? optional(Object? v) => v is String && v.isNotEmpty ? v : null;
    return Doc(
      id: _string(json['id']),
      kind: DocKind.fromKey(json['kind']),
      number: _string(json['number']),
      customerId: _string(json['customerId']),
      customerName: _string(json['customerName']),
      honorific: json['honorific'] == '様' ? '様' : '御中',
      customerAddress: _string(json['customerAddress']),
      title: _string(json['title']),
      issueDate: _string(json['issueDate']),
      dueDate: optional(json['dueDate']),
      lines: [
        if (rawLines is List)
          for (final line in rawLines)
            if (line is Map) DocLine.fromJson(Map<String, dynamic>.from(line)),
      ],
      note: _string(json['note']),
      status: DocStatus.fromKey(json['status']),
      createdAt: _time(json['createdAt']),
      paidDate: optional(json['paidDate']),
      sourceId: optional(json['sourceId']),
      convertedId: optional(json['convertedId']),
    );
  }
}
