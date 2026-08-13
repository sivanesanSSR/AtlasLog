import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Schedules on-device local notifications 3 days before a member's
/// plan expires. Since there's no backend/cron, this fires only if
/// scheduled from this device and the app hasn't been force-stopped.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
  }

  /// Uses a stable integer ID derived from the member's UUID so we can
  /// reliably cancel/reschedule the same notification later.
  int _notificationIdFor(String memberId) => memberId.hashCode & 0x7fffffff;

  Future<void> scheduleExpiryReminder({
    required String memberId,
    required String memberName,
    required DateTime endDate,
  }) async {
    final reminderDate = endDate.subtract(const Duration(days: 3));

    // Don't schedule reminders in the past.
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledTime = tz.TZDateTime.from(
      DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9, 0),
      tz.local,
    );

    const androidDetails = AndroidNotificationDetails(
      'plan_expiry_channel',
      'Plan Expiry Reminders',
      channelDescription: 'Reminds you 3 days before a member\'s plan expires',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _plugin.zonedSchedule(
      _notificationIdFor(memberId),
      'Plan expiring soon',
      '$memberName\'s plan expires in 3 days. Remind them to renew.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelExpiryReminder(String memberId) async {
    await _plugin.cancel(_notificationIdFor(memberId));
  }
}
