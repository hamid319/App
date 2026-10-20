import 'package:url_launcher/url_launcher.dart';

class LinkLauncher {
  /// Opens a web link in the browser. Only http(s) is allowed, since the
  /// links come from place data.
  static Future<void> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw Exception('Unsupported link: $url');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open $url');
  }
}
