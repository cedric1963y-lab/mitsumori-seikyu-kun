import '../plan/limits.dart';

enum PurchaseEventKind { unlocked, pending, canceled, error }

class PurchaseEvent {
  const PurchaseEvent.unlocked({
    required this.productId,
    required this.expiresAt,
    this.restored = false,
  }) : kind = PurchaseEventKind.unlocked,
       message = null;

  const PurchaseEvent.pending()
    : kind = PurchaseEventKind.pending,
      message = null,
      productId = null,
      expiresAt = null,
      restored = false;

  const PurchaseEvent.canceled()
    : kind = PurchaseEventKind.canceled,
      message = null,
      productId = null,
      expiresAt = null,
      restored = false;

  const PurchaseEvent.error(this.message)
    : kind = PurchaseEventKind.error,
      productId = null,
      expiresAt = null,
      restored = false;

  final PurchaseEventKind kind;
  final String? message;
  final String? productId;
  final DateTime? expiresAt;
  final bool restored;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.priceLabel,
    required this.title,
    this.trialLabel,
  });

  final String id;
  final String priceLabel;
  final String title;

  /// For example `1週間`. Set only when the App Store says this Apple ID can
  /// still get the introductory free trial.
  final String? trialLabel;
}

class StoreSubscription {
  const StoreSubscription({
    required this.productId,
    required this.expiresAt,
    this.purchasedAt,
  });

  final String productId;
  final DateTime expiresAt;
  final DateTime? purchasedAt;
}

/// The subscription that still covers [now], preferring the latest expiry.
StoreSubscription? activeSubscription(
  Iterable<StoreSubscription> records,
  DateTime now,
) {
  StoreSubscription? best;
  for (final record in records) {
    if (!PlanLimits.isPremiumProduct(record.productId)) continue;
    if (!record.expiresAt.isAfter(now)) continue;
    final purchased = record.purchasedAt;
    if (purchased != null && purchased.isAfter(now)) continue;
    if (best == null || record.expiresAt.isAfter(best.expiresAt)) {
      best = record;
    }
  }
  return best;
}

/// StoreKit boundary. Tests use a fake. The app uses [StorePurchaseGateway].
abstract class PurchaseGateway {
  Future<void> start(Future<void> Function(PurchaseEvent event) onEvent);

  Future<List<StoreProduct>> loadProducts();

  Future<void> buy(String productId);

  Future<void> restore();

  /// Null when the store could not be asked. An empty list means the store
  /// answered and there is no premium transaction.
  Future<List<StoreSubscription>?> currentSubscriptions();

  void dispose();
}

/// Shown before the store sheet returns localized prices.
List<StoreProduct> get fallbackPremiumProducts => const [
  StoreProduct(
    id: PlanLimits.monthlyProductId,
    priceLabel: PlanLimits.monthlyPriceLabel,
    title: 'プレミアム（月額）',
  ),
  StoreProduct(
    id: PlanLimits.yearlyProductId,
    priceLabel: PlanLimits.yearlyPriceLabel,
    title: 'プレミアム（年額）',
  ),
];
