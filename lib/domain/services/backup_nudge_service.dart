import 'package:shared_preferences/shared_preferences.dart';

/// Tracks `lastBackupDate` and the invoice count at last backup time, used
/// by [HomeScreen] to decide when to show the backup-nudge banner.
///
/// Storage: SharedPreferences (a single key-value store). We deliberately do
/// NOT create a new Drift table for this — per the task spec — to keep the
/// DB schema stable.
///
/// Two keys:
///   - `lastBackupDate` (int millis since epoch, 0 = never)
///   - `invoiceCountAtBackup` (int, 0 = never)
class BackupNudgeService {
  static const _kLastBackupDate = 'lastBackupDate';
  static const _kInvoiceCountAtBackup = 'invoiceCountAtBackup';

  /// Records a successful backup at [when] with [invoiceCount] invoices.
  static Future<void> recordBackup({
    required DateTime when,
    required int invoiceCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastBackupDate, when.millisecondsSinceEpoch);
    await prefs.setInt(_kInvoiceCountAtBackup, invoiceCount);
  }

  /// Returns the last backup timestamp, or null if never backed up.
  static Future<DateTime?> lastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastBackupDate);
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Returns the invoice count recorded at the last backup, or 0 if never.
  static Future<int> invoiceCountAtBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kInvoiceCountAtBackup) ?? 0;
  }

  /// Decides whether the nudge should be shown, given the current invoice
  /// count and the staleness threshold (default 30 days).
  ///
  /// Conditions:
  ///   (a) No backup has ever been made and the user has >= 5 invoices, OR
  ///   (b) Last backup was > 30 days ago and the user has created new
  ///       invoices since (current count > count at last backup).
  static Future<bool> shouldNudge({
    required int currentInvoiceCount,
    Duration staleness = const Duration(days: 30),
  }) async {
    final last = await lastBackupDate();
    final countAtBackup = await invoiceCountAtBackup();

    if (last == null) {
      // Never backed up — nudge if user has accumulated enough data.
      return currentInvoiceCount >= 5;
    }

    final age = DateTime.now().difference(last);
    if (age > staleness) {
      // Backup is stale — nudge only if new invoices exist since backup.
      return currentInvoiceCount > countAtBackup;
    }

    return false;
  }
}
