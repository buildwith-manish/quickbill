import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/database.dart';
import '../../data/repositories/invoice_repository.dart';

/// Schedules local notifications for overdue invoices (due date passed,
/// status != paid) and reminders 1 day before due date.
///
/// v1 strategy: a single daily check at 9 AM local time that scans the DB
/// for overdue invoices and posts a summary notification. Plus per-invoice
/// reminders scheduled at create time.
///
/// Notifications fire even when the app is closed (OS-level scheduler).
/// No network, no FCM — fully offline.
class ReminderService {
  ReminderService(this._repo);

  final InvoiceRepository _repo;
  static final _notifications = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// One-time init — call from main.dart after WidgetsFlutterBinding.
  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);
    _initialized = true;
  }

  /// Request notification permission (iOS only — Android grants on install).
  static Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a reminder 1 day before [invoice.dueDate] (if set and in the
  /// future). Called from the Invoice Create screen after save.
  ///
  /// Notification IDs are derived from the invoice's UUID hashCode — stable
  /// across reboots, unique within reason.
  Future<void> scheduleFor(Invoice invoice) async {
    if (invoice.dueDate == null) return;
    await init();

    final reminderTime =
        invoice.dueDate!.subtract(const Duration(days: 1));

    // Don't schedule in the past.
    if (reminderTime.isBefore(DateTime.now())) return;

    final id = invoice.id.hashCode;
    await _notifications.zonedSchedule(
      id,
      'Invoice due tomorrow',
      '${invoice.invoiceNumber} is due on ${_fmtDate(invoice.dueDate!)}.',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'invoice_reminders',
          'Invoice reminders',
          channelDescription: 'Reminders for upcoming invoice due dates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules a daily 9 AM check for overdue invoices.
  static Future<void> scheduleDailyOverdueCheck() async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0, 0);
    if (when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0, // ID 0 = daily overdue check
      'Overdue invoices',
      'You have overdue invoices. Open QuickBill to review.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'overdue_check',
          'Daily overdue check',
          channelDescription: 'Daily 9 AM summary of overdue invoices.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels reminders for a deleted/paid invoice.
  Future<void> cancelFor(Invoice invoice) async {
    await init();
    await _notifications.cancel(invoice.id.hashCode);
  }

  /// Cancels all scheduled reminders — called on "Reset all data".
  static Future<void> cancelAll() async {
    await init();
    await _notifications.cancelAll();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
