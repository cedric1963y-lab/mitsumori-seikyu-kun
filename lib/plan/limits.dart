/// Free tier and the App Store subscription products.
/// Prices are set in App Store Connect. The labels are the Japan fallbacks.
abstract final class PlanLimits {
  static const freeCustomerLimit = 2;
  static const freeItemLimit = 10;

  /// New documents per calendar month on the free plan. Turning a 見積書
  /// into a 請求書 does not count.
  static const freeDocumentsPerMonth = 3;

  /// Free plan sees documents issued this month and last month, plus every
  /// invoice that is still unpaid.
  static const freeHistoryMonths = 2;

  static const freeFooter = 'かんたん見積・請求くんで作成';

  static const monthlyProductId = 'jp.mitsumori.app.premium.monthly';
  static const yearlyProductId = 'jp.mitsumori.app.premium.yearly';
  static const subscriptionGroupName = 'かんたん見積・請求くん Premium';
  static const monthlyPriceYen = 100;
  static const yearlyPriceYen = 1200;
  static const monthlyPriceLabel = '¥100';
  static const yearlyPriceLabel = '¥1,200';
  static const bundleId = 'jp.mitsumori.app';

  /// Introductory offer set in App Store Connect for both products.
  static const freeTrialLabel = '1週間';

  static const premiumProductIds = {monthlyProductId, yearlyProductId};

  static bool isPremiumProduct(String productId) {
    return premiumProductIds.contains(productId);
  }

  static String priceLabelFor(String productId) {
    if (productId == yearlyProductId) return yearlyPriceLabel;
    return monthlyPriceLabel;
  }

  static String planName(String? productId) {
    if (productId == yearlyProductId) return '年額';
    if (productId == monthlyProductId) return '月額';
    return 'プレミアム';
  }

  /// Used only when StoreKit does not send an expiration date.
  static DateTime periodEnd(String productId, DateTime purchasedAt) {
    final local = purchasedAt.toLocal();
    final months = productId == yearlyProductId ? 12 : 1;
    return DateTime(
      local.year,
      local.month + months,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  static bool canAddCustomer({required bool premium, required int count}) {
    return premium || count < freeCustomerLimit;
  }

  static bool canAddItem({required bool premium, required int count}) {
    return premium || count < freeItemLimit;
  }

  static bool canCreateDocument({
    required bool premium,
    required int createdThisMonth,
  }) {
    return premium || createdThisMonth < freeDocumentsPerMonth;
  }
}

abstract final class AppInfo {
  static const name = 'かんたん見積・請求くん';
  static const shortName = '見積・請求くん';
  static const version = '1.0.0';
}

abstract final class AppLinks {
  static const base = 'https://cedric1963y-lab.github.io/mitsumori-seikyu-kun/';
  static const support = base;
  static const privacy = '${base}privacy.html';
  static const terms = '${base}terms.html';

  /// Apple standard Terms of Use (EULA).
  static const appleEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const manageSubscriptions =
      'https://apps.apple.com/account/subscriptions';
}
