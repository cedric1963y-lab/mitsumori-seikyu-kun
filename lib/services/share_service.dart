import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Opens the iOS share sheet with plain text (LINE, メッセージ, メモ…).
Future<void> shareText(String text, {String? subject, Rect? origin}) {
  return SharePlus.instance.share(
    ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
  );
}

/// Opens the iOS share sheet with one file.
Future<void> shareFile({
  required String path,
  required String fileName,
  required String mimeType,
  String? subject,
  Rect? origin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      subject: subject,
      sharePositionOrigin: origin,
    ),
  );
}
