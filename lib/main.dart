import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'domain/services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications + timezone data. Failures here are
  // non-fatal — the app still works, just without reminders.
  try {
    await ReminderService.init();
    await ReminderService.scheduleDailyOverdueCheck();
  } catch (_) {
    // Swallow — reminders are a nice-to-have, not a launch blocker.
  }

  runApp(
    const ProviderScope(
      child: QuickBillApp(),
    ),
  );
}
