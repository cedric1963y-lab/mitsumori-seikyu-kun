/// User-facing validation failure. [message] is Japanese and safe to show.
class InvalidInput implements Exception {
  const InvalidInput(this.message);

  final String message;

  @override
  String toString() => message;
}

enum LimitKind { customers, items, documents, seal, history, csv }

/// A free-plan cap was hit. The UI answers with the premium screen.
class LimitReached implements Exception {
  const LimitReached(this.kind);

  final LimitKind kind;

  @override
  String toString() => 'LimitReached($kind)';
}

/// App Store could not start or finish a purchase.
class StoreUnavailable implements Exception {
  const StoreUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
