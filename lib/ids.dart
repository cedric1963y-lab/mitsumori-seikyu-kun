import 'dart:math';

final _random = Random();

/// Local id. Not a secret and not shown in the UI.
String createId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = _random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
  return '$time$salt';
}
