import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/core/config/env.dart';

void main() {
  test('trims the optional local Places key', () {
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=  places-value  ');
    expect(Env.googlePlacesApiKey, 'places-value');
  });

  test('a blank key is empty', () {
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=   ');
    expect(Env.googlePlacesApiKey, '');
  });
}
