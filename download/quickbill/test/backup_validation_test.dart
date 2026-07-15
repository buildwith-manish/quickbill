import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/domain/services/backup_service.dart';

/// Tests for [BackupService.import] validation pipeline.
///
/// These tests verify that invalid, corrupted, or wrong-format files are
/// rejected BEFORE the production DB is touched. The early validation
/// steps (extension check, SQLite header check) run before any path_provider
/// calls, so they're testable without platform mocking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('BackupService.import validation', () {
    test('rejects file with wrong extension', () async {
      final badFile = File(p.join(tempDir.path, 'not-a-backup.txt'));
      await badFile.writeAsString('this is not a database');

      final service = BackupService(db);
      expect(
        () => service.import(badFile.path),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rejects file that is not a SQLite database (bad header)', () async {
      final badFile = File(p.join(tempDir.path, 'fake.sqlite'));
      // Write 16 bytes that are NOT the SQLite magic header.
      await badFile.writeAsBytes(List.filled(100, 0));

      final service = BackupService(db);
      expect(
        () => service.import(badFile.path),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rejects non-existent file', () async {
      final service = BackupService(db);
      expect(
        () => service.import(p.join(tempDir.path, 'nonexistent.sqlite')),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('BackupValidationException carries user-friendly message', () async {
      final badFile = File(p.join(tempDir.path, 'not-a-backup.txt'));
      await badFile.writeAsString('not a db');

      final service = BackupService(db);
      try {
        await service.import(badFile.path);
        fail('Should have thrown');
      } on BackupValidationException catch (e) {
        // Message must be user-friendly — no stack traces, no raw exception text.
        expect(e.message, isNotEmpty);
        expect(e.message, contains('.txt'));
        expect(e.toString(), e.message);
      }
    });

    test('valid SQLite header is accepted past the header check', () async {
      // Create a valid SQLite file — the header check should pass.
      // Subsequent validation (tables check) will fail because this file
      // has no BillKraft tables, but the failure must be a
      // BackupValidationException, not a crash.
      final validSqlitePath = p.join(tempDir.path, 'valid-sqlite.sqlite');
      final validDb = AppDatabase.forTesting(
        NativeDatabase(File(validSqlitePath)),
      );
      await validDb.customStatement(
        'CREATE TABLE unrelated (id INTEGER PRIMARY KEY)',
      );
      await validDb.close();

      final service = BackupService(db);
      // This should throw BackupValidationException (missing tables or
      // path_provider issue), NOT a raw crash.
      expect(
        () => service.import(validSqlitePath),
        throwsA(anyOf(
          isA<BackupValidationException>(),
          isA<MissingPluginException>(), // path_provider not available in test env
        )),
      );
    });
  });

  group('BackupValidationException', () {
    test('message is preserved through toString()', () {
      const exc = BackupValidationException('test message');
      expect(exc.message, 'test message');
      expect(exc.toString(), 'test message');
    });

    test('is an Exception', () {
      const exc = BackupValidationException('test');
      expect(exc, isA<Exception>());
    });
  });
}
