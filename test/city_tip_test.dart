import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/features/home/data/city_tip_repository.dart';
import 'package:swipetrip/features/home/logic/city_tip_controller.dart';

void main() {
  test('banner shows when never paused or after the pause', () {
    final now = DateTime(2026, 11, 8);
    expect(cityTipBannerDue(null, now), isTrue);
    expect(cityTipBannerDue(now.add(const Duration(days: 1)), now), isFalse);
    expect(cityTipBannerDue(now, now), isTrue);
    expect(cityTipPauseAfterTip, const Duration(days: 30));
  });

  test('a tip is stored under its author, trimmed', () async {
    final db = FakeFirebaseFirestore();
    final repo = CityTipRepository(firestore: db);
    await repo.submitTip(
      uid: 'u1',
      cityId: 'de_berlin',
      place: '  Café Kreuzberg ',
      note: ' Best cake ',
      language: 'de',
    );
    final tips =
        await db.collection('users').doc('u1').collection('cityTips').get();
    expect(tips.docs.single.data(), containsPair('place', 'Café Kreuzberg'));
    expect(tips.docs.single.data(), containsPair('note', 'Best cake'));
    expect(tips.docs.single.data(), containsPair('cityId', 'de_berlin'));
  });

  test('empty or too long tips are rejected before writing', () {
    final repo = CityTipRepository(firestore: FakeFirebaseFirestore());
    Future<void> submit(String place, [String note = '']) => repo.submitTip(
        uid: 'u1',
        cityId: 'de_berlin',
        place: place,
        note: note,
        language: 'en');
    expect(() => submit('   '), throwsArgumentError);
    expect(() => submit('x' * 81), throwsArgumentError);
    expect(() => submit('ok', 'y' * 281), throwsArgumentError);
  });
}
