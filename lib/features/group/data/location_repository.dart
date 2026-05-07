import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationRepository {
  final String _username = 'demo'; // Replace with a real geonames username if needed, or use a generic one

  Future<List<Map<String, String>>> getCountries() async {
    try {
    final url = Uri.parse('http://api.geonames.org/countryInfoJSON?username=$_username');
    final response = await http.get(url).timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List geonames = data['geonames'] ?? [];
      if (geonames.isNotEmpty) {
        return geonames.map((c) => {
          'countryCode': c['countryCode'].toString(),
          'countryName': c['countryName'].toString(),
        }).toList();
      }
    }
    } catch (e) {
      print('Error fetching countries: $e');
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
        'http://api.geonames.org/searchJSON?country=$countryCode&featureClass=P&orderby=population&maxRows=50&username=$_username');
    final response = await http.get(url).timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List geonames = data['geonames'] ?? [];
      if (geonames.isNotEmpty) {
        return geonames.map((c) => {
          'cityId': c['geonameId'].toString(),
          'cityName': c['name'].toString(),
          'lat': double.tryParse(c['lat'].toString()) ?? 0.0,
          'lng': double.tryParse(c['lng'].toString()) ?? 0.0,
        }).toList();
      }
    }
    } catch (e) {
      print('Error fetching cities: $e');
    }
    // Fallback to mock data
    return [
      {'cityId': '1', 'cityName': 'Mock City 1', 'lat': 0.0, 'lng': 0.0},
      {'cityId': '2', 'cityName': 'Mock City 2', 'lat': 0.0, 'lng': 0.0},
      {'cityId': '3', 'cityName': 'Mock City 3', 'lat': 0.0, 'lng': 0.0},
    ];
  }
}
