import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/backup_service.dart';
import '../../../theme/app_theme.dart';
import '../../providers/business_profile_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/invoice_providers.dart';

/// Backup / restore section shown at the bottom of the Settings screen.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = appColors(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.cloud_upload_outlined,
          title: 'Backup & restore',
          subtitle: 'Export your data to a file you can share or import later. '
              'Stored on your device — no cloud.',
          colors: colors,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _export(context, ref),
                icon: const Icon(Icons.ios_share),
                label: const Text('Export backup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Import backup'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Importing replaces ALL current data with the backup file. '
                  'Export a fresh backup first if you have any unsaved work.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final service = BackupService(db);
    final messenger = ScaffoldMessenger.of(context);
    final path = await service.exportAndShare();
    if (path == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export failed — no data to back up.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Backup ready: $path')),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
            'This will replace ALL current data with the contents of the '
            'backup file. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import & replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final srcPath = picked.files.single.path;
    if (srcPath == null) return;

    final db = ref.read(appDatabaseProvider);
    final service = BackupService(db);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.import(srcPath);
      // Invalidate everything so the next read re-opens the DB.
      ref.invalidate(appDatabaseProvider);
      ref.invalidate(businessProfileControllerProvider);
      ref.invalidate(clientListProvider);
      ref.invalidate(invoiceListProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup imported. Restart the app to apply.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
