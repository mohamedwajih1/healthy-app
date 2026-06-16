import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// موديل التنبيه المخصص الاحترافي
class HabitReminder {
  final String id;
  final int hour;
  final int minute;
  final String message;
  final String?
  soundPath; // مسار الملف الصوتي الكامل من الجهاز
  final String?
  imagePath; // مسار الصورة الكاملة من الجهاز
  final bool vibrate;
  final bool showLights;
  final Color ledColor;
  final List<int>? vibrationPattern;

  HabitReminder({
    required this.id,
    required this.hour,
    required this.minute,
    this.message = 'حان وقت عادتك! 🎯',
    this.soundPath,
    this.imagePath,
    this.vibrate = true,
    this.showLights = true,
    this.ledColor = const Color(0xFF6366F1),
    this.vibrationPattern,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'message': message,
      'soundPath': soundPath,
      'imagePath': imagePath,
      'vibrate': vibrate,
      'showLights': showLights,
      'ledColor': ledColor.value,
      'vibrationPattern': vibrationPattern,
    };
  }

  factory HabitReminder.fromMap(
    Map<String, dynamic> map,
  ) {
    return HabitReminder(
      id: map['id'],
      hour: map['hour'],
      minute: map['minute'],
      message:
          map['message'] ?? 'حان وقت عادتك! 🎯',
      soundPath: map['soundPath'],
      imagePath: map['imagePath'],
      vibrate: map['vibrate'] ?? true,
      showLights: map['showLights'] ?? true,
      ledColor: map['ledColor'] != null
          ? Color(map['ledColor'])
          : const Color(0xFF6366F1),
      vibrationPattern:
          map['vibrationPattern'] != null
          ? List<int>.from(
              map['vibrationPattern'],
            )
          : null,
    );
  }

  HabitReminder copyWith({
    String? id,
    int? hour,
    int? minute,
    String? message,
    String? soundPath,
    String? imagePath,
    bool? vibrate,
    bool? showLights,
    Color? ledColor,
    List<int>? vibrationPattern,
  }) {
    return HabitReminder(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      message: message ?? this.message,
      soundPath: soundPath ?? this.soundPath,
      imagePath: imagePath ?? this.imagePath,
      vibrate: vibrate ?? this.vibrate,
      showLights: showLights ?? this.showLights,
      ledColor: ledColor ?? this.ledColor,
      vibrationPattern:
          vibrationPattern ??
          this.vibrationPattern,
    );
  }

  String get timeFormatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get soundName {
    if (soundPath == null) {
      return 'الصوت الافتراضي';
    }
    return soundPath!
        .split('/')
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  String get imageName {
    if (imagePath == null) return 'بدون صورة';
    return imagePath!.split('/').last;
  }
}

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin
  _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // أنماط الاهتزاز المتاحة
  static const Map<String, List<int>>
  vibrationPatterns = {
    'قصير': [0, 200],
    'متوسط': [0, 500],
    'طويل': [0, 1000],
    'نبضتين': [0, 300, 200, 300],
    'ثلاث نبضات': [0, 200, 100, 200, 100, 200],
    'مستمر': [0, 500, 250, 500, 250, 500],
    'تدريجي': [
      0,
      100,
      100,
      200,
      200,
      300,
      300,
      400,
    ],
    'إنذار': [
      0,
      100,
      100,
      100,
      100,
      100,
      100,
      500,
    ],
  };

  // ألوان LED المتاحة
  static const Map<String, Color> ledColors = {
    'أزرق': Color(0xFF6366F1),
    'أخضر': Color(0xFF10B981),
    'أحمر': Color(0xFFEF4444),
    'برتقالي': Color(0xFFF59E0B),
    'بنفسجي': Color(0xFF8B5CF6),
    'وردي': Color(0xFFEC4899),
    'سماوي': Color(0xFF06B6D4),
    'أصفر': Color(0xFFEAB308),
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation('Africa/Cairo'),
      );

      const AndroidInitializationSettings
      androidSettings =
          AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          );

      const DarwinInitializationSettings
      iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings =
          InitializationSettings(
            android: androidSettings,
            iOS: iosSettings,
          );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            _onNotificationTapped,
      );

      _isInitialized = true;
      print(
        '✅ Notification Service initialized successfully',
      );
    } catch (e) {
      print(
        '❌ Error initializing Notification Service: $e',
      );
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        if (await Permission
            .notification
            .isDenied) {
          final status = await Permission
              .notification
              .request();
          if (!status.isGranted) return false;
        }

        if (await Permission
            .scheduleExactAlarm
            .isDenied) {
          await Permission.scheduleExactAlarm
              .request();
        }

        // طلب إذن الوصول للملفات الصوتية والصور
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }

        if (await Permission.audio.isDenied) {
          await Permission.audio.request();
        }

        // إذن الوصول للملفات (Android 13+)
        if (await Permission
            .manageExternalStorage
            .isDenied) {
          await Permission.manageExternalStorage
              .request();
        }

        return true;
      } else if (Platform.isIOS) {
        final bool? granted = await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  // Copy custom sound file to app directory
  Future<String?> _copySoundToAppDirectory(
    String sourcePath,
  ) async {
    try {
      if (!File(sourcePath).existsSync()) {
        print(
          '⚠️ Sound file does not exist: $sourcePath',
        );
        return null;
      }

      final appDir =
          await getApplicationDocumentsDirectory();
      final soundsDir = Directory(
        '${appDir.path}/sounds',
      );

      // إنشاء مجلد الأصوات إذا لم يكن موجوداً
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      final fileName = path.basename(sourcePath);
      final newPath =
          '${soundsDir.path}/$fileName';

      // نسخ الملف
      await File(sourcePath).copy(newPath);

      print('✅ Sound copied to: $newPath');
      return newPath;
    } catch (e) {
      print('❌ Error copying sound file: $e');
      return null;
    }
  }

  // Create custom notification channel for each sound
  Future<String> _createCustomSoundChannel(
    String habitName,
    String? soundPath,
  ) async {
    final channelId =
        'habit_${habitName.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      String? soundFileName;

      if (soundPath != null &&
          File(soundPath).existsSync()) {
        // نسخ الصوت إلى مجلد التطبيق
        final copiedPath =
            await _copySoundToAppDirectory(
              soundPath,
            );
        if (copiedPath != null) {
          soundFileName = path
              .basenameWithoutExtension(
                copiedPath,
              );
        }
      }

      // إنشاء قناة بصوت مخصص
      final AndroidNotificationChannel
      channel = AndroidNotificationChannel(
        channelId,
        habitName,
        description: 'تنبيهات عادة $habitName',
        importance: Importance.max,
        playSound: true,
        sound: soundFileName != null
            ? RawResourceAndroidNotificationSound(
                soundFileName,
              )
            : null, // الصوت الافتراضي
        enableVibration: true,
        enableLights: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      print(
        '✅ Created channel: $channelId with sound: $soundFileName',
      );
      return channelId;
    } catch (e) {
      print(
        '❌ Error creating notification channel: $e',
      );
      return 'habit_reminders_default';
    }
  }

  Future<void> scheduleHabitReminders({
    required String habitId,
    required String habitName,
    required List<HabitReminder> reminders,
    required String frequency,
    List<int>? customDays,
  }) async {
    await initialize();
    await cancelHabitNotifications(habitId);

    print(
      '📅 Scheduling ${reminders.length} reminders for: $habitName',
    );
    print('   Frequency: $frequency');
    if (customDays != null) {
      print('   Custom Days: $customDays');
    }

    for (int i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final baseNotificationId =
          _generateNotificationId(habitId, i);

      try {
        if (frequency == 'daily') {
          // جدولة يومية - منبه واحد يتكرر كل يوم
          await _scheduleDailyReminder(
            notificationId: baseNotificationId,
            habitName: habitName,
            reminder: reminder,
          );
        } else if (frequency == 'weekly') {
          // جدولة أسبوعية - منبه واحد يتكرر كل أسبوع
          // يستخدم اليوم الذي اختاره المستخدم، وإلا يوم إعداد العادة
          final weekday =
              (customDays != null && customDays.isNotEmpty)
              ? customDays.first
              : tz.TZDateTime.now(tz.local).weekday;
          await _scheduleWeeklyReminder(
            notificationId: baseNotificationId,
            habitName: habitName,
            reminder: reminder,
            weekdays: [weekday], // يوم واحد في الأسبوع
          );
        } else if (frequency == 'custom') {
          // جدولة مخصصة - منبه لكل يوم من الأيام المختارة
          final days =
              customDays ?? [1, 2, 3, 4, 5, 6, 7];
          await _scheduleCustomReminder(
            baseNotificationId:
                baseNotificationId,
            habitName: habitName,
            reminder: reminder,
            weekdays: days,
          );
        }

        print(
          '✅ Reminder $i scheduled at ${reminder.timeFormatted}',
        );
      } catch (e) {
        print(
          '❌ Error scheduling reminder $i for $habitName: $e',
        );
      }
    }

    print(
      '✅ Successfully scheduled ${reminders.length} reminders for: $habitName',
    );
  }

  Future<void> _scheduleDailyReminder({
    required int notificationId,
    required String habitName,
    required HabitReminder reminder,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 1),
      );
    }

    final details =
        await _buildNotificationDetails(
          habitName,
          reminder,
        );

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ $habitName',
      reminder.message,
      scheduledDate,
      details,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // يتكرر كل يوم
    );

    print(
      '   ✓ Daily reminder scheduled for ${reminder.timeFormatted}',
    );
  }

  Future<void> _scheduleWeeklyReminder({
    required int notificationId,
    required String habitName,
    required HabitReminder reminder,
    required List<int> weekdays,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // جدولة لأول يوم من الأيام المحددة
    var scheduledDate = _nextInstanceOfWeekday(
      now,
      weekdays.first,
      reminder.hour,
      reminder.minute,
    );

    final details =
        await _buildNotificationDetails(
          habitName,
          reminder,
        );

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ $habitName',
      reminder.message,
      scheduledDate,
      details,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents
          .dayOfWeekAndTime, // يتكرر أسبوعياً
    );

    print(
      '   ✓ Weekly reminder scheduled for ${_getDayName(weekdays.first)} at ${reminder.timeFormatted}',
    );
  }

  // Schedule weekly repeating reminder for specific days
  Future<void> _scheduleCustomReminder({
    required int baseNotificationId,
    required String habitName,
    required HabitReminder reminder,
    required List<int> weekdays,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    for (int weekday in weekdays) {
      var scheduledDate = _nextInstanceOfWeekday(
        now,
        weekday,
        reminder.hour,
        reminder.minute,
      );

      final details =
          await _buildNotificationDetails(
            habitName,
            reminder,
          );

      // استخدام ID مختلف لكل يوم من الأسبوع
      final uniqueId =
          baseNotificationId * 10 + weekday;

      await _notifications.zonedSchedule(
        uniqueId,
        '⏰ $habitName',
        reminder.message,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode
            .exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents
            .dayOfWeekAndTime, // يتكرر أسبوعياً في نفس اليوم
      );

      print(
        '   ✓ Custom reminder scheduled for ${_getDayName(weekday)} at ${reminder.timeFormatted} (ID: $uniqueId)',
      );
    }
  }

  Future<NotificationDetails>
  _buildNotificationDetails(
    String habitName,
    HabitReminder reminder,
  ) async {
    BigPictureStyleInformation? bigPictureStyle;

    // إضافة الصورة إذا كانت موجودة
    if (reminder.imagePath != null &&
        File(reminder.imagePath!).existsSync()) {
      try {
        bigPictureStyle =
            BigPictureStyleInformation(
              FilePathAndroidBitmap(
                reminder.imagePath!,
              ),
              largeIcon: FilePathAndroidBitmap(
                reminder.imagePath!,
              ),
              contentTitle: '⏰ $habitName',
              summaryText: reminder.message,
              htmlFormatContent: true,
              htmlFormatTitle: true,
            );
      } catch (e) {
        print('⚠️ Error loading image: $e');
      }
    }

    // إعداد نمط الاهتزاز
    final vibrationPattern = reminder.vibrate
        ? Int64List.fromList(
            reminder.vibrationPattern ??
                [0, 500, 250, 500],
          )
        : null;

    // Create custom notification channel for sound
    String channelId;
    if (reminder.soundPath != null &&
        File(reminder.soundPath!).existsSync()) {
      channelId = await _createCustomSoundChannel(
        habitName,
        reminder.soundPath,
      );
    } else {
      channelId =
          'habit_reminders_${habitName.hashCode}';
    }

    final androidDetails =
        AndroidNotificationDetails(
          channelId,
          habitName,
          channelDescription:
              'تنبيهات عادة $habitName',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: reminder.vibrate,
          vibrationPattern: vibrationPattern,
          enableLights: reminder.showLights,
          ledColor: reminder.ledColor,
          ledOnMs: 1000,
          ledOffMs: 500,
          styleInformation: bigPictureStyle,
          icon: '@mipmap/ic_launcher',
          color: reminder.ledColor,
          category: AndroidNotificationCategory
              .reminder,
          visibility:
              NotificationVisibility.public,
          ticker: 'تذكير: $habitName',
          showWhen: true,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'mark_done',
              '✅ تم الإنجاز',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'snooze',
              '⏰ تأجيل 10 دقائق',
              cancelNotification: false,
            ),
            const AndroidNotificationAction(
              'dismiss',
              '✖️ تجاهل',
              cancelNotification: true,
            ),
          ],
        );

    // إعدادات iOS
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: reminder.soundPath != null
          ? path.basename(reminder.soundPath!)
          : null,
      attachments:
          reminder.imagePath != null &&
              File(
                reminder.imagePath!,
              ).existsSync()
          ? [
              DarwinNotificationAttachment(
                reminder.imagePath!,
              ),
            ]
          : null,
      categoryIdentifier: 'habit_reminder',
      threadIdentifier: habitName,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  tz.TZDateTime _nextInstanceOfWeekday(
    tz.TZDateTime date,
    int weekday,
    int hour,
    int minute,
  ) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 1),
      );
    }

    if (scheduledDate.isBefore(date)) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 7),
      );
    }

    return scheduledDate;
  }

  String _getDayName(int weekday) {
    const days = [
      'الاثنين', // 1
      'الثلاثاء', // 2
      'الأربعاء', // 3
      'الخميس', // 4
      'الجمعة', // 5
      'السبت', // 6
      'الأحد', // 7
    ];
    return weekday >= 1 && weekday <= 7
        ? days[weekday - 1]
        : '';
  }

  int _generateNotificationId(
    String habitId,
    int index,
  ) {
    return (habitId.hashCode.abs() % 100000) +
        (index * 100);
  }

  Future<void> cancelHabitNotifications(
    String habitId,
  ) async {
    final pendingNotifications =
        await _notifications
            .pendingNotificationRequests();

    int canceledCount = 0;
    for (var notification
        in pendingNotifications) {
      // إلغاء جميع المنبهات المرتبطة بهذه العادة
      // ID format: baseId + (index * 100) + weekday
      final baseId =
          (habitId.hashCode.abs() % 100000);
      if (notification.id >= baseId &&
          notification.id < baseId + 10000) {
        await _notifications.cancel(
          notification.id,
        );
        canceledCount++;
      }
    }

    print(
      '🔕 Cancelled $canceledCount notifications for habit: $habitId',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    print('🔕 Cancelled notification: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🔕 Cancelled all notifications');
  }

  Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications
        .pendingNotificationRequests();
  }

  // Debug helper: show all scheduled notifications
  Future<void>
  showScheduledNotifications() async {
    final pending =
        await getPendingNotifications();
    print(
      '\n📋 Scheduled Notifications (${pending.length}):',
    );
    for (var notification in pending) {
      print('   • ID: ${notification.id}');
      print('     Title: ${notification.title}');
      print('     Body: ${notification.body}');
      print('');
    }
  }

  Future<void> showTestNotification({
    required String habitName,
    required HabitReminder reminder,
  }) async {
    await initialize();

    final details =
        await _buildNotificationDetails(
          habitName,
          reminder,
        );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch %
          100000,
      '🧪 اختبار: $habitName',
      reminder.message,
      details,
    );

    print('✅ Test notification shown');
  }

  void _onNotificationTapped(
    NotificationResponse response,
  ) {
    print(
      '📱 Notification tapped: ${response.actionId ?? "main"}',
    );

    switch (response.actionId) {
      case 'mark_done':
        print('✅ User marked habit as done');
        break;
      case 'snooze':
        print(
          '⏰ User snoozed notification for 10 minutes',
        );
        break;
      case 'dismiss':
        print('✖️ User dismissed notification');
        break;
      default:
        print(
          '📱 User opened the app from notification',
        );
    }
  }
}
