import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
    debugPrint('✅ NotificationService initialized');

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_enabled') ?? false;
    if (enabled) {
      final hour = prefs.getInt('notif_hour') ?? 20;
      final minute = prefs.getInt('notif_minute') ?? 0;
      await scheduleDailyReminder(hour, minute);
    }
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      await _plugin.cancelAll();

      const androidDetails = AndroidNotificationDetails(
        'daily_reminder',
        'Nhắc học hàng ngày',
        channelDescription: 'Nhắc nhở bạn ôn tập flashcard mỗi ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      final scheduledTime = _nextInstanceOfTime(hour, minute);

      await _plugin.zonedSchedule(
        id: 0,
        title: 'Đến giờ ôn tập rồi! 📚',
        body: 'Hãy dành vài phút để ôn flashcard nhé!',
        scheduledDate: scheduledTime,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', true);
      await prefs.setInt('notif_hour', hour);
      await prefs.setInt('notif_minute', minute);

      debugPrint(
        '✅ Daily reminder scheduled at $hour:${minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('❌ scheduleDailyReminder error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', false);
      debugPrint('✅ Notifications cancelled');
    } catch (e) {
      debugPrint('❌ cancelAll error: $e');
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_enabled') ?? false;
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notif_hour') ?? 20;
    final minute = prefs.getInt('notif_minute') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
