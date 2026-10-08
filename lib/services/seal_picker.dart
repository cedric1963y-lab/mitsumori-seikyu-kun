import 'package:flutter/services.dart';

/// Picks one image with the system photo picker (PHPickerViewController).
/// The picker runs out of process and needs no photo library permission, so
/// Info.plist has no NSPhotoLibraryUsageDescription. Returns a PNG no larger
/// than 600 px, or null when the user cancels.
class SealPicker {
  const SealPicker();

  static const _channel = MethodChannel('jp.mitsumori.app/seal_picker');

  Future<Uint8List?> pick() async {
    final result = await _channel.invokeMethod<Uint8List>('pick');
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
