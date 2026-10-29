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

/// Local notifications the app schedules on the device itself (no server,
/// no push): the check-in reminder on a trip's first day.
class TripReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _init;

  /// Called with the trip id when a reminder is tapped.
  void Function(String groupId)? onOpen;

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
        // The app was started by tapping a reminder.
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _open(launch!.notificationResponse?.payload);
        }
      }();

  void _open(String? groupId) {
    if (groupId != null && groupId.isNotEmpty) onOpen?.call(groupId);
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
    await _plugin.cancelAll();
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
