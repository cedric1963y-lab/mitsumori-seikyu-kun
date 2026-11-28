import 'entitlement.dart';

/// One short tip for people in the free trial. Shown at most once, never as
/// a push notification, and never at the moment the trial starts.
abstract final class TrialTip {
  static const message = 'お試し中のヒント：見積書を開くと、1タップで請求書にできます。PDFもそのまま送れます。';

  /// The introductory trial is 1 week; allow a day of slack.
  static const maxTrialLength = Duration(days: 8);

  /// Wait a little after the trial starts so the tip is not the first thing
  /// a new subscriber sees.
  static const minTimeInTrial = Duration(hours: 12);

  /// True when [entitlement] is still the first, short (trial-length)
  /// period of a subscription.
  static bool isTrial(Entitlement entitlement, DateTime now) {
    final started = entitlement.purchasedAt;
    final ends = entitlement.expiresAt;
    if (started == null || ends == null) return false;
    if (!entitlement.isActiveAt(now)) return false;
    return ends.difference(started) <= maxTrialLength;
  }

  static bool shouldShow({
    required Entitlement entitlement,
    required DateTime now,
    required bool alreadyShown,
  }) {
    if (alreadyShown) return false;
    if (!isTrial(entitlement, now)) return false;
    return now.difference(entitlement.purchasedAt!) >= minTimeInTrial;
  }
}
