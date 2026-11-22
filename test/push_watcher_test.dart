import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetrip/app/push_watcher.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/core/services/push_service.dart';
import 'package:swipetrip/main_providers.dart';

class _FakePush extends PushService {
  final registered = <String>[];

  @override
  Future<void> start({
    required void Function(String route) onOpen,
    required void Function(String title, String body, String? route)
        onForeground,
  }) async {}

  @override
  Future<void> register(String uid, String lang) async => registered.add(uid);
}

void main() {
  testWidgets('logging out and back in registers the device again',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final push = _FakePush();
    final account = StreamController<({String uid, bool isGuest})?>();
    addTearDown(account.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        pushServiceProvider.overrideWithValue(push),
        currentAccountProvider.overrideWith((ref) => account.stream),
        myTripsProvider.overrideWith((ref) => Stream.value([
              GroupModel(groupId: 'g', members: const ['u1'])
            ])),
      ],
      child: const MaterialApp(home: PushWatcher(child: SizedBox())),
    ));

    Future<void> signIn(({String uid, bool isGuest})? value) async {
      account.add(value);
      await tester.pumpAndSettle();
    }

    await signIn((uid: 'u1', isGuest: false));
    expect(push.registered, ['u1']);
    // Logout ends in a guest session; the token was deleted.
    await signIn((uid: 'guest', isGuest: true));
    await signIn((uid: 'u1', isGuest: false));
    expect(push.registered, ['u1', 'u1']);
  });
}
