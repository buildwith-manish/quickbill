import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/database.dart';
import 'backup_nudge_service.dart';

/// Export / import the app's SQLite database file.
///
/// Export: copies the live DB file to a timestamped file in the cache
/// directory and opens the native share sheet so the user can send it to
/// themselves via email / Drive / WhatsApp.
///
/// Import: replaces the live DB file with the picked file, then triggers
/// a full app restart (via [AppDatabase.wipeAll] + provider invalidation).
///
/// For v1 we don't do incremental / encrypted backups — just a raw file
/// copy. Encryption is a v2 idea.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Exports the DB file. Returns the path of the exported file, or null
  /// if the export failed.
  ///
  /// Also opens the native share sheet so the user can send the file.
  /// On success, records the backup timestamp + invoice count via
  /// [BackupNudgeService] so the home-screen nudge banner can stop showing.
  Future<String?> exportAndShare() async {
    try {
      // Force any in-flight writes to disk.
      await _db.customStatement('PRAGMA wal_checkpoint(FULL)');

      final docs = await getApplicationDocumentsDirectory();
      final srcPath = p.join(docs.path, 'quickbill.sqlite');
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) {
        return null;
      }

      // Stamp the filename with the current date so multiple backups don't
      // clobber each other.
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final tmpDir = await getTemporaryDirectory();
      final destPath = p.join(tmpDir.path, 'quickbill-backup-$stamp.sqlite');
      await srcFile.copy(destPath);

      await Share.shareXFiles(
        [XFile(destPath)],
        text: 'QuickBill backup $stamp',
      );

      // Record the backup so the nudge banner stops showing. Count invoices
      // via a lightweight raw query (avoids pulling the full repo dependency
      // into this service).
      final countResult = await _db.customSelect(
        'SELECT COUNT(*) AS c FROM invoices',
      ).getSingle();
      final invoiceCount = countResult.read<int>('c');
      await BackupNudgeService.recordBackup(
        when: now,
        invoiceCount: invoiceCount,
      );

      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Imports a DB file from [srcPath], replacing the live DB.
  ///
  /// Closes the current DB connection, overwrites the file, and signals
  /// the caller to trigger a restart. The caller is responsible for
  /// invalidating providers.
  Future<void> import(String srcPath) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      throw FileSystemException('Backup file not found', srcPath);
    }

    await _db.close();

    final docs = await getApplicationDocumentsDirectory();
    final destPath = p.join(docs.path, 'quickbill.sqlite');
    final destFile = File(destPath);

    // Back up the current DB before overwriting, in case the import file
    // is corrupt.
    if (await destFile.exists()) {
      final backupPath = '$destPath.preimport.bak';
      await destFile.copy(backupPath);
    }

    await srcFile.copy(destPath);
    // The caller must recreate the AppDatabase and invalidate providers.
  }
}
