import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class LocationRepository {
  final String _username =
      'demo'; // Replace with a real geonames username if needed, or use a generic one

  Future<List<Map<String, String>>> getCountries() async {
    try {
      final url = Uri.parse(
          'https://secure.geonames.org/countryInfoJSON?username=$_username');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List geonames = data['geonames'] ?? [];
        if (geonames.isNotEmpty) {
          return geonames
              .map((c) => {
                    'countryCode': c['countryCode'].toString(),
                    'countryName': c['countryName'].toString(),
                  })
              .toList();
        }
      }
    } catch (e) {
      developer.log('Error fetching countries', error: e);
    }
    // Fallback to mock data
    return [
      {'countryCode': 'US', 'countryName': 'United States'},
      {'countryCode': 'GB', 'countryName': 'United Kingdom'},
      {'countryCode': 'DE', 'countryName': 'Germany'},
      {'countryCode': 'FR', 'countryName': 'France'},
      {'countryCode': 'TR', 'countryName': 'Turkey'},
      {'countryCode': 'IT', 'countryName': 'Italy'},
    ];
  }

  Future<List<Map<String, dynamic>>> getCities(String countryCode) async {
    try {
      final url = Uri.parse(
          'https://secure.geonames.org/searchJSON?country=$countryCode&featureClass=P&orderby=population&maxRows=50&username=$_username');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List geonames = data['geonames'] ?? [];
        if (geonames.isNotEmpty) {
          return geonames
              .map((c) => {
                    'cityId': c['geonameId'].toString(),
                    'cityName': c['name'].toString(),
                    'lat': double.tryParse(c['lat'].toString()) ?? 0.0,
                    'lng': double.tryParse(c['lng'].toString()) ?? 0.0,
                  })
              .toList();
        }
      }
    } catch (e) {
      developer.log('Error fetching cities', error: e);
    }
    // Fallback to mock data
    return [
      {'cityId': '1', 'cityName': 'Paris', 'lat': 48.8566, 'lng': 2.3522},
      {'cityId': '2', 'cityName': 'London', 'lat': 51.5074, 'lng': -0.1278},
      {'cityId': '3', 'cityName': 'Tokyo', 'lat': 35.6762, 'lng': 139.6503},
      {'cityId': '4', 'cityName': 'New York', 'lat': 40.7128, 'lng': -74.0060},
      {'cityId': '5', 'cityName': 'Rome', 'lat': 41.9028, 'lng': 12.4964},
      {'cityId': '6', 'cityName': 'Berlin', 'lat': 52.5200, 'lng': 13.4050},
      {'cityId': '7', 'cityName': 'Madrid', 'lat': 40.4168, 'lng': -3.7038},
      {'cityId': '8', 'cityName': 'Sydney', 'lat': -33.8688, 'lng': 151.2093},
      {'cityId': '9', 'cityName': 'Toronto', 'lat': 43.6510, 'lng': -79.3470},
      {'cityId': '10', 'cityName': 'Dubai', 'lat': 25.2048, 'lng': 55.2708},
    ];
  }
}
