import 'package:flutter/services.dart';

/// Tells iOS that a 見積書/請求書 PDF was shared. After the third share the
/// native side shows Apple's rating dialog (SKStoreReviewController), at most
/// once per app version. Counting and the once-per-version flag live in
/// UserDefaults (see ReviewAsk in AppDelegate.swift).
class ReviewAsk {
  const ReviewAsk();

  static const _channel = MethodChannel('jp.mitsumori.app/review_ask');

  Future<void> pdfShared() async {
    try {
      await _channel.invokeMethod<void>('pdfShared');
    } catch (_) {
      // Not available in tests; the dialog is optional.
    }
  }
}
