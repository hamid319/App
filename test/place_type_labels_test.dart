import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/place_type_labels.dart';
import 'package:swipetrip/l10n/app_localizations_de.dart';
import 'package:swipetrip/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();

  test('Google place types become readable translated labels', () {
    expect(placeTypeLabel(en, 'tourist_attraction'), 'Sight');
    expect(placeTypeLabel(de, 'tourist_attraction'), 'Sehenswürdigkeit');
    expect(placeTypeLabel(de, 'park'), 'Park');
    expect(placeTypeLabel(de, 'outdoors'), 'Draußen');
  });

  test('unknown types are humanized instead of shown as snake_case', () {
    expect(placeTypeLabel(en, 'rooftop_bar'), 'Rooftop bar');
  });

  test('generic types are hidden and duplicates collapse', () {
    expect(
      placeTypeLabels(en, [
        'point_of_interest',
        'landmark',
        'cultural_landmark',
        'establishment',
        'museum',
      ]),
      ['Landmark', 'Museum'],
    );
  });
}
