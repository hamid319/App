import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/user_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';
import 'package:swipetrip/features/group/logic/group_controller.dart';
import 'package:swipetrip/main_providers.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

/// Rejects every code except [validCode].
class _FakeRepository extends GroupRepository {
  _FakeRepository()
      : super(_MockFirestoreService(), firestore: FakeFirebaseFirestore());

  static const validCode = 'TRAON7';

  @override
  Future<String> joinGroupByCodeOnly(String code, String userId) async {
    if (code != validCode) throw Exception('Invalid invite code');
    return 'trip~1';
  }
}

class _SignedIn extends AuthController {
  @override
  Future<UserModel?> build() async =>
      UserModel(uid: 'u1', email: 'a@b.c', createdAt: DateTime(2026));
}

void main() {
  test('a successful join after a wrong code reports no error', () async {
    final container = ProviderContainer(overrides: [
      groupRepositoryProvider.overrideWithValue(_FakeRepository()),
      authControllerProvider.overrideWith(_SignedIn.new),
      myTripsProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final controller = container.read(groupControllerProvider.notifier);

    await controller.joinByInviteCodeOnly('ZZZZZ9');
    expect(container.read(groupControllerProvider).hasError, isTrue);

    await controller.joinByInviteCodeOnly(_FakeRepository.validCode);
    expect(container.read(groupControllerProvider).hasError, isFalse);
    expect(container.read(selectedGroupIdProvider), 'trip~1');
  });
}
