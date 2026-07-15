import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/services/backup_nudge_service.dart';
import '../../../domain/services/backup_service.dart';
import '../../../theme/app_theme.dart';
import '../../providers/database_provider.dart';

/// "Your Data" screen — surfaces the privacy/trust claim as a tangible
/// feature. Shows the exact on-device DB file path + size, last backup
/// timestamp, and a prominent one-tap export button.
///
/// This is the differentiation vs. competitors that hold data hostage —
/// the user can SEE where their data lives and TAKE it anytime.
class YourDataScreen extends ConsumerStatefulWidget {
  const YourDataScreen({super.key});

  @override
  ConsumerState<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends ConsumerState<YourDataScreen> {
  String? _dbPath;
  int? _dbSizeBytes;
  DateTime? _lastBackup;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadDataInfo();
  }

  Future<void> _loadDataInfo() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docs.path, 'quickbill.sqlite');
      final dbFile = File(dbPath);
      int? size;
      if (await dbFile.exists()) {
        size = await dbFile.length();
      }
      final lastBackup = await BackupNudgeService.lastBackupDate();
      if (mounted) {
        setState(() {
          _dbPath = dbPath;
          _dbSizeBytes = size;
          _lastBackup = lastBackup;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final service = BackupService(db);
      final path = await service.exportAndShare();
      if (path == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed — no data to back up.')),
        );
      }
      // Refresh last backup timestamp after export.
      await _loadDataInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColors(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Hero trust message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: colors.accent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No account. No cloud.',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your invoices never leave this phone unless you '
                              'share them. Tap export below to take your data '
                              'with you anytime.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // DB file location
                _DataCard(
                  icon: Icons.storage_outlined,
                  title: 'Database location',
                  value: _dbPath ?? 'Not found',
                  subtitle: _dbSizeBytes != null
                      ? _formatBytes(_dbSizeBytes!)
                      : null,
                ),
                const SizedBox(height: 12),

                // Last backup
                _DataCard(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Last backup',
                  value: _lastBackup != null
                      ? DateFormat('dd MMM yyyy, HH:mm').format(_lastBackup!)
                      : 'Never',
                  subtitle: _lastBackup != null
                      ? _relativeTime(_lastBackup!)
                      : 'Export your data now to create your first backup.',
                ),
                const SizedBox(height: 12),

                // Record counts
                _RecordCountsCard(),
                const SizedBox(height: 24),

                // One-tap export
                FilledButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.ios_share),
                  label: Text(_exporting ? 'Exporting...' : 'Export my data'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Creates a backup file and opens the share sheet so you can '
                  'send it to yourself via WhatsApp, email, or Drive.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${(diff.inDays / 30).round()} months ago';
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows live counts of clients, invoices, and invoice items — reinforces
/// "this is YOUR data, here's how much of it exists".
class _RecordCountsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(appDatabaseProvider);

    return FutureBuilder<List<int>>(
      future: _getCounts(db),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? [0, 0, 0];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your records',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _CountTile(
                            label: 'Clients', count: counts[0])),
                    Expanded(
                        child: _CountTile(
                            label: 'Invoices', count: counts[1])),
                    Expanded(
                        child: _CountTile(
                            label: 'Items', count: counts[2])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<int>> _getCounts(db) async {
    final clients = await db.customSelect('SELECT COUNT(*) AS c FROM clients').getSingle();
    final invoices = await db.customSelect('SELECT COUNT(*) AS c FROM invoices').getSingle();
    final items = await db.customSelect('SELECT COUNT(*) AS c FROM invoice_items').getSingle();
    return [
      clients.read<int>('c'),
      invoices.read<int>('c'),
      items.read<int>('c'),
    ];
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            count.toString(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
