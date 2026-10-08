import '../plan/limits.dart';
import 'purchase_gateway.dart';

/// Debug screenshot runs only (see main.dart). Shows the Japan storefront
/// prices and the 1-week trial configured in App Store Connect, because the
/// simulator otherwise talks to the US sandbox storefront. Never buys.
class ScreenshotPurchaseGateway implements PurchaseGateway {
  @override
  Future<void> start(
    Future<void> Function(PurchaseEvent event) onEvent,
  ) async {}

  @override
  Future<List<StoreProduct>> loadProducts() async => const [
    StoreProduct(
      id: PlanLimits.monthlyProductId,
      priceLabel: PlanLimits.monthlyPriceLabel,
      title: 'プレミアム（月額）',
      trialLabel: PlanLimits.freeTrialLabel,
    ),
    StoreProduct(
      id: PlanLimits.yearlyProductId,
      priceLabel: PlanLimits.yearlyPriceLabel,
      title: 'プレミアム（年額）',
      trialLabel: PlanLimits.freeTrialLabel,
    ),
  ];

  @override
  Future<void> buy(String productId) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<List<StoreSubscription>?> currentSubscriptions() async => null;

  @override
  void dispose() {}
}
