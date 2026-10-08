import 'limits.dart';

/// Local cache of the App Store subscription. Customers, items and documents are stored
/// separately and are not removed when this lapses.
class Entitlement {
  const Entitlement({this.productId, this.expiresAt});

  final String? productId;
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) {
    final expires = expiresAt;
    final product = productId;
    if (expires == null || product == null) return false;
    if (!PlanLimits.isPremiumProduct(product)) return false;
    return expires.isAfter(now);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      if (productId != null) 'productId': productId,
      if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
    };
  }

  static Entitlement fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Entitlement();
    final product = json['productId'];
    final raw = json['expiresAt'];
    DateTime? expires;
    if (raw is int) {
      expires = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        expires = DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return Entitlement(
      productId: product is String ? product : null,
      expiresAt: expires,
    );
  }
}
