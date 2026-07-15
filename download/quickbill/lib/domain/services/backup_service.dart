import 'dart:io';

import 'package:drift/native.dart';
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
/// Import: validates the picked file (extension, SQLite header, schema
/// version, basic corruption check) against a temporary copy BEFORE
/// replacing the production DB. On any validation failure the production
/// DB is left untouched and an exception is thrown. On success the
/// pre-import DB is preserved as a `.preimport.bak` sidecar for manual
/// rollback.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// The schema version the imported backup must match. Drift's migration
  /// strategy handles upgrades, but we reject downgrades to avoid silent
  /// data loss.
  static const int _minSupportedSchema = 1;

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
      final destPath = p.join(tmpDir.path, 'billkraft-backup-$stamp.sqlite');
      await srcFile.copy(destPath);

      await Share.shareXFiles(
        [XFile(destPath)],
        text: 'BillKraft backup $stamp',
      );

      // Record the backup so the nudge banner stops showing. Count invoices
      // via a lightweight raw query (avoids pulling the full repo dependency
      // into this service).
      final countResult = await _db
          .customSelect(
            'SELECT COUNT(*) AS c FROM invoices',
          )
          .getSingle();
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
  /// Validation pipeline (all must pass before the production DB is touched):
  ///   1. File exists and has a `.sqlite` / `.db` extension.
  ///   2. File starts with the SQLite header magic string.
  ///   3. The file can be opened by Drift without throwing.
  ///   4. `PRAGMA user_version` (Drift's schema version) is >= [_minSupportedSchema].
  ///   5. `PRAGMA integrity_check` returns "ok".
  ///
  /// On success: the current DB is closed, the validated file is copied over
  /// the production path, and the pre-import DB is preserved as
  /// `billkraft.sqlite.preimport.bak` for manual rollback.
  ///
  /// On failure: the production DB is untouched, a [BackupValidationException]
  /// is thrown with a user-friendly message, and any temp files are cleaned up.
  ///
  /// The caller is responsible for recreating [AppDatabase] and invalidating
  /// providers after a successful import.
  Future<void> import(String srcPath) async {
    final srcFile = File(srcPath);

    // 1. Existence + extension check.
    if (!await srcFile.exists()) {
      throw const BackupValidationException(
        'Backup file not found. Please pick a valid BillKraft backup file.',
      );
    }
    final ext = p.extension(srcPath).toLowerCase();
    if (ext != '.sqlite' && ext != '.db' && ext != '.sqlite3') {
      throw BackupValidationException(
        'Invalid file type (.$ext). Please pick a .sqlite backup file.',
      );
    }

    // 2. SQLite header check — the first 16 bytes of any SQLite file are
    //    "SQLite format 3\0".
    final headerBytes = await srcFile.openRead(0, 16).toList();
    final header = headerBytes.expand((b) => b).toList();
    const magic = 'SQLite format 3\u0000';
    if (header.length < 16 || String.fromCharCodes(header) != magic) {
      throw const BackupValidationException(
        'This file is not a valid SQLite database. It may be corrupted or not an BillKraft backup.',
      );
    }

    // 3-5. Open the file in a TEMPORARY location and run integrity checks
    //      BEFORE touching the production DB. We copy to a temp path because
    //      the picked file may be on a read-only URI-backed cache.
    final tmpDir = await getTemporaryDirectory();
    final tempCopyPath = p.join(tmpDir.path, 'import-validation-tmp.sqlite');
    final tempCopy = File(tempCopyPath);
    try {
      await srcFile.copy(tempCopyPath);

      final validatorDb = AppDatabase.forTesting(NativeDatabase(tempCopy));
      try {
        // 4. Schema version check.
        final versionRow =
            await validatorDb.customSelect('PRAGMA user_version').getSingle();
        final fileVersion = versionRow.read<int>('user_version');
        if (fileVersion < _minSupportedSchema) {
          throw BackupValidationException(
            'Backup schema version $fileVersion is too old. Minimum supported is $_minSupportedSchema.',
          );
        }
        // Reject downgrades — the current DB's schema version.
        final currentVersion = _db.schemaVersion;
        if (fileVersion > currentVersion) {
          throw BackupValidationException(
            'Backup schema version $fileVersion is newer than this app supports ($currentVersion). Please update BillKraft.',
          );
        }

        // 5. Integrity check.
        final integrityRows =
            await validatorDb.customSelect('PRAGMA integrity_check').get();
        final integrityResult =
            integrityRows.first.data['integrity_check'] as String;
        if (integrityResult != 'ok') {
          throw BackupValidationException(
            'Backup database is corrupted: $integrityResult',
          );
        }

        // Verify the file has the expected tables (lightweight structural
        // check — catches the case where a valid SQLite file has the wrong
        // schema entirely).
        final tables = await validatorDb
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('business_profiles','clients','invoices','invoice_items')",
            )
            .get();
        if (tables.length < 4) {
          throw const BackupValidationException(
            'This SQLite file does not contain the expected BillKraft tables. It may be from a different app.',
          );
        }
      } finally {
        await validatorDb.close();
      }

      // All validations passed — now replace the production DB.
      await _db.close();

      final docs = await getApplicationDocumentsDirectory();
      final destPath = p.join(docs.path, 'quickbill.sqlite');
      final destFile = File(destPath);

      // Preserve the pre-import DB for manual rollback.
      if (await destFile.exists()) {
        final backupPath = '$destPath.preimport.bak';
        await destFile.copy(backupPath);
      }

      // Replace production DB with the validated temp copy.
      await tempCopy.copy(destPath);

      // Clean up WAL/SHM sidecar files from the old DB so Drift starts clean.
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$destPath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
    } catch (e) {
      // Rollback path: if anything went wrong after we closed the production
      // DB, the caller will need to recreate the DB connection. The
      // production file itself is untouched (we only copied TO temp, not
      // FROM temp, before the failure).
      rethrow;
    } finally {
      // Always clean up the temp validation copy.
      if (await tempCopy.exists()) {
        try {
          await tempCopy.delete();
        } catch (_) {
          // Non-fatal — temp dir is cleaned by the OS.
        }
      }
    }
  }
}

/// Thrown when a backup import fails validation. The message is safe to
/// show directly to the user.
class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
