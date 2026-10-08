import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in Safari. Returns false when iOS refused to open it.
Future<bool> openExternal(String url) async {
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
