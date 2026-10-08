import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../errors.dart';
import '../plan/limits.dart';
import 'purchase_gateway.dart';

class StorePurchaseGateway implements PurchaseGateway {
  StorePurchaseGateway({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};

  @override
  Future<void> start(Future<void> Function(PurchaseEvent event) onEvent) async {
    await _subscription?.cancel();
    _subscription = _store.purchaseStream.listen(
      (purchases) {
        unawaited(_deliver(purchases, onEvent));
      },
      onError: (Object _) {
        unawaited(onEvent(const PurchaseEvent.error('購入処理でエラーが起きました。')));
      },
    );
  }

  Future<void> _deliver(
    List<PurchaseDetails> purchases,
    Future<void> Function(PurchaseEvent event) onEvent,
  ) async {
    for (final purchase in purchases) {
      final ours = PlanLimits.isPremiumProduct(purchase.productID);
      if (ours) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            await onEvent(const PurchaseEvent.pending());
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final expires = await _expirationFor(purchase);
            if (expires != null && expires.isAfter(DateTime.now())) {
              await onEvent(
                PurchaseEvent.unlocked(
                  productId: purchase.productID,
                  expiresAt: expires,
                  restored: purchase.status == PurchaseStatus.restored,
                ),
              );
            } else {
              await onEvent(
                const PurchaseEvent.error(
                  '有効な契約は見つかりませんでした。期限が切れている場合は、月額または年額を開始してください。',
                ),
              );
            }
          case PurchaseStatus.error:
            await onEvent(
              PurchaseEvent.error(purchase.error?.message ?? '購入に失敗しました。'),
            );
          case PurchaseStatus.canceled:
            await onEvent(const PurchaseEvent.canceled());
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  @override
  Future<List<StoreProduct>> loadProducts() async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(
      PlanLimits.premiumProductIds,
    );
    for (final details in response.productDetails) {
      _products[details.id] = details;
    }
    final result = <StoreProduct>[];
    for (final id in [
      PlanLimits.monthlyProductId,
      PlanLimits.yearlyProductId,
    ]) {
      final details = _products[id];
      if (details == null) continue;
      result.add(
        StoreProduct(
          id: id,
          priceLabel: details.price,
          title: details.title,
          trialLabel: await _trialEligible(id)
              ? PlanLimits.freeTrialLabel
              : null,
        ),
      );
    }
    return result;
  }

  Future<bool> _trialEligible(String productId) async {
    try {
      return await SK2Product.isIntroductoryOfferEligible(productId);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> buy(String productId) async {
    if (!PlanLimits.isPremiumProduct(productId)) {
      throw const StoreUnavailable('この商品は購入できません。');
    }
    if (!await _store.isAvailable()) {
      throw const StoreUnavailable(
        'この端末ではApp Storeに接続できません。実機で、App Storeにサインインした状態でお試しください。',
      );
    }
    final details = _products[productId] ?? await _query(productId);
    if (details == null) {
      throw StoreUnavailable(
        '商品が見つかりません。App Store Connect に「$productId」があるか確認してください。',
      );
    }
    // Auto-renewable subscriptions use the same StoreKit purchase call
    // as non-consumables in the in_app_purchase plugin.
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started) {
      throw const StoreUnavailable('購入を開始できませんでした。');
    }
  }

  @override
  Future<void> restore() async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailable(
        'この端末ではApp Storeに接続できません。実機で、同じApple IDでお試しください。',
      );
    }
    await _store.restorePurchases();
  }

  @override
  Future<List<StoreSubscription>?> currentSubscriptions() async {
    try {
      final transactions = await SK2Transaction.transactions();
      return [
        for (final transaction in transactions)
          if (PlanLimits.isPremiumProduct(transaction.productId))
            StoreSubscription(
              productId: transaction.productId,
              expiresAt:
                  _epoch(transaction.expirationDate) ??
                  PlanLimits.periodEnd(
                    transaction.productId,
                    _epoch(transaction.purchaseDate) ?? DateTime.now(),
                  ),
              purchasedAt: _epoch(transaction.purchaseDate),
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<ProductDetails?> _query(String productId) async {
    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return null;
    final details = response.productDetails.first;
    _products[details.id] = details;
    return details;
  }

  Future<DateTime?> _expirationFor(PurchaseDetails purchase) async {
    final known = await currentSubscriptions();
    if (known != null) {
      final match = activeSubscription(known, DateTime.now());
      if (match != null) return match.expiresAt;
    }
    final purchasedAt = _epoch(purchase.transactionDate) ?? DateTime.now();
    return PlanLimits.periodEnd(purchase.productID, purchasedAt);
  }

  DateTime? _epoch(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final millis = int.tryParse(raw);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
