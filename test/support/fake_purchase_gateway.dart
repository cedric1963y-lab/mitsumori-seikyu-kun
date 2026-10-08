import 'package:mitsumori_seikyu/services/purchase_gateway.dart';

class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({this.products, this.subscriptions});

  List<StoreProduct>? products;

  /// Null means the store could not be asked. An empty list means it answered
  /// and there is no subscription.
  List<StoreSubscription>? subscriptions;
  int buys = 0;
  String? lastProductId;
  int restores = 0;
  Future<void> Function(PurchaseEvent event)? listener;

  @override
  Future<void> start(Future<void> Function(PurchaseEvent event) onEvent) async {
    listener = onEvent;
  }

  @override
  Future<List<StoreProduct>> loadProducts() async {
    return products ?? fallbackPremiumProducts;
  }

  @override
  Future<void> buy(String productId) async {
    buys += 1;
    lastProductId = productId;
  }

  @override
  Future<void> restore() async {
    restores += 1;
  }

  @override
  Future<List<StoreSubscription>?> currentSubscriptions() async {
    return subscriptions;
  }

  @override
  void dispose() {}

  Future<void> emit(PurchaseEvent event) async {
    await listener?.call(event);
  }
}
