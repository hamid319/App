import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/config/env.dart';

void main() {
  test('demo config trims required API keys and uses configured model', () {
    dotenv.loadFromString(envString: '''
GOOGLE_PLACES_API_KEY=  places-value  
GEMINI_API_KEY=  gemini-value  
GEMINI_MODEL=  gemini-test-model  
''');

    expect(Env.googlePlacesApiKey, 'places-value');
    expect(Env.geminiApiKey, 'gemini-value');
    expect(Env.geminiModel, 'gemini-test-model');
    expect(Env.missingDemoVariables, isEmpty);
  });

  test('missing variables are named without exposing configured values', () {
    dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=   ');

    expect(
      Env.missingDemoVariables,
      containsAll(<String>['GOOGLE_PLACES_API_KEY', 'GEMINI_API_KEY']),
    );
    expect(Env.missingDemoVariables.join(','), isNot(contains('value')));
  });

  test('blank Gemini model uses the demo fallback', () {
    dotenv.loadFromString(envString: 'GEMINI_MODEL=   ');

    expect(Env.geminiModel, 'gemini-2.5-flash');
  });
}
