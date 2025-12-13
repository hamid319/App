import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class MapsLauncher {
  static Future<void> openInMaps(double lat, double lng, String name) async {
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$name';
    final String appleMapsUrl = 'https://maps.apple.com/?ll=$lat,$lng&q=$name';
    final url = Platform.isIOS ? appleMapsUrl : googleMapsUrl;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps');
    }
  }
}
