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

  // ─── Khởi tạo ──────────────────────────────────────────────────────────────

  /// Gọi một lần duy nhất trong main() trước runApp().
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
    debugPrint('[NotificationService] initialized');

    // Khôi phục lịch nếu user đã bật trước đó (ví dụ sau khi restart app)
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_enabled') ?? false) {
      final hour = prefs.getInt('notif_hour') ?? 20;
      final minute = prefs.getInt('notif_minute') ?? 0;
      await scheduleDailyReminder(hour, minute);
    }
  }

  // ─── Request permission ────────────────────────────────────────────────────

  /// Yêu cầu quyền POST_NOTIFICATIONS ở runtime.
  /// Trả về true nếu đã được cấp.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    // requestNotificationsPermission() có sẵn từ flutter_local_notifications ^14
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  // ─── Lên lịch nhắc hàng ngày ───────────────────────────────────────────────

  /// Lên lịch một notification lặp hàng ngày vào [hour]:[minute].
  /// Tự động request permission nếu chưa có.
  /// Trả về true nếu thành công.
  Future<bool> scheduleDailyReminder(int hour, int minute) async {
    try {
      // Kiểm tra / xin permission trước
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('[NotificationService] permission denied');
        return false;
      }

      await _plugin.cancelAll();

      const androidDetails = AndroidNotificationDetails(
        'daily_reminder',
        'Nhắc học hàng ngày',
        channelDescription: 'Nhắc nhở bạn ôn tập flashcard mỗi ngày',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      await _plugin.zonedSchedule(
        id: 0,
        title: 'Đến giờ ôn tập rồi! 📚',
        body: 'Hãy dành vài phút để ôn flashcard nhé!',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(android: androidDetails),
        // exactAllowWhileIdle đảm bảo thông báo đúng giờ kể cả khi màn hình tắt
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', true);
      await prefs.setInt('notif_hour', hour);
      await prefs.setInt('notif_minute', minute);

      debugPrint(
        '[NotificationService] scheduled at $hour:${minute.toString().padLeft(2, '0')}',
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationService] scheduleDailyReminder error: $e');
      return false;
    }
  }

  // ─── Hủy tất cả ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', false);
      debugPrint('[NotificationService] cancelled');
    } catch (e) {
      debugPrint('[NotificationService] cancelAll error: $e');
    }
  }

  // ─── Getters trạng thái ─────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_enabled') ?? false;
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt('notif_hour') ?? 20,
      minute: prefs.getInt('notif_minute') ?? 0,
    );
  }

  // ─── Helper ─────────────────────────────────────────────────────────────────

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
    // Nếu giờ đã qua hôm nay → lên lịch cho ngày mai
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
