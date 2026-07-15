import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers/database_provider.dart';
import '../../theme/app_theme.dart';

/// Wraps the app and intercepts DB init failures. Shows a recovery screen
/// with a "Reset DB" button instead of a red error screen.
///
/// Drift throws `SqliteException` with various codes when the DB file is
/// corrupt (e.g. after a partial OTA update). We catch all errors here and
/// offer the user a single button: nuke the DB file and restart.
class DbCorruptionGuard extends ConsumerStatefulWidget {
  const DbCorruptionGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DbCorruptionGuard> createState() => _DbCorruptionGuardState();
}

class _DbCorruptionGuardState extends ConsumerState<DbCorruptionGuard> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _verifyDb();
  }

  Future<void> _verifyDb() async {
    try {
      // Touch the DB — this triggers the lazy connection in Drift and will
      // throw if the file is corrupt.
      final db = ref.read(appDatabaseProvider);
      await db.customSelect('SELECT 1').get();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset database?'),
        content: const Text(
            'The database appears to be corrupt. This will delete the DB file '
            'and start fresh. All clients, invoices, and your business profile '
            'will be lost. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset & restart'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Close the DB connection and delete the file.
      final db = ref.read(appDatabaseProvider);
      await db.close();
      final docs = await getApplicationDocumentsDirectory();
      final path = p.join(docs.path, 'quickbill.sqlite');
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      // Also delete the WAL and SHM sidecar files if present.
      for (final suffix in ['-wal', '-shm', '.preimport.bak']) {
        final sidecar = File('$path$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      // Invalidate the provider so the next read recreates the DB.
      ref.invalidate(appDatabaseProvider);
    } catch (_) {
      // Swallow — the user will see the same error again if reset failed,
      // at which point reinstall is the only option.
    }

    if (mounted) {
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final colors = appColors(context);
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colors.danger),
                const SizedBox(height: 16),
                Text(
                  'Database error',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'BillKraft couldn\'t open its local database. This usually '
                  'happens after a system update or storage issue. Resetting '
                  'the database will let the app run again, but all saved '
                  'data will be lost.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.danger,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset database'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
