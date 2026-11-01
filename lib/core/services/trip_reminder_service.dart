import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A local notification to show at [at].
typedef TripReminder = ({
  String groupId,
  DateTime at,
  String title,
  String body
});

/// Local notifications the app schedules on the device itself: the
/// check-in reminder on a trip's first day. Also shows pushes that arrive
/// while the app is open (Android shows none of its own then).
class TripReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _init;

  /// Called with the route to open when a notification is tapped.
  void Function(String route)? onOpen;

  static const _updates = AndroidNotificationDetails(
    'trip_updates',
    'Trip updates',
    importance: Importance.high,
  );

  Future<void> _ensureInit() => _init ??= () async {
        tz_data.initializeTimeZones();
        await _plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // Asked for in [requestPermission], not at app start.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (r) => _open(r.payload),
        );
        // Pushes from the server name this channel.
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              'trip_updates',
              'Trip updates',
              importance: Importance.high,
            ));
        // The app was started by tapping a reminder.
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _open(launch!.notificationResponse?.payload);
        }
      }();

  /// Reminders carry a trip id, pushes a route.
  void _open(String? payload) {
    if (payload == null || payload.isEmpty) return;
    onOpen?.call(payload.startsWith('/') ? payload : '/trip/$payload');
  }

  /// Shows a push that arrived while the app is in the foreground.
  Future<void> show(String title, String body, String? route) async {
    await _ensureInit();
    await _plugin.show(
      // Distinct ids so several updates stack instead of replacing.
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 1000,
      title,
      body,
      const NotificationDetails(android: _updates),
      payload: route,
    );
  }

  Future<void> start() => _ensureInit();

  /// Asks once; the system remembers the answer.
  Future<void> requestPermission() async {
    await _ensureInit();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Replaces every scheduled reminder with [reminders].
  Future<void> sync(List<TripReminder> reminders) async {
    await _ensureInit();
    // Only the scheduled ones: cancelAll would also clear shown pushes.
    for (final p in await _plugin.pendingNotificationRequests()) {
      await _plugin.cancel(p.id);
    }
    for (final (i, r) in reminders.indexed) {
      try {
        await _plugin.zonedSchedule(
          i,
          r.title,
          r.body,
          // shortcut: fixed instant in the phone's zone at scheduling time;
          // after flying into another zone it fires at home-time 10:00.
          tz.TZDateTime.from(r.at, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'trip_reminders',
              'Trip reminders',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: r.groupId,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Scheduling reminder ${r.groupId} failed: $e');
      }
    }
  }
}
