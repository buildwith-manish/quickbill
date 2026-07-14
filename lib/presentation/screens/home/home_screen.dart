import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/database.dart';
import '../../../domain/services/backup_nudge_service.dart';
import '../../providers/business_profile_providers.dart';
import '../../providers/invoice_providers.dart';
import '../../widgets/empty_state.dart';

/// Home — quick stats, primary "+ New Invoice" CTA, recent invoices.
///
/// Stats are computed from the live invoice list (no extra query / index):
///   - Total invoiced this month
///   - Total outstanding (sent + draft, i.e. unpaid)
///
/// Also shows a dismissible backup-nudge banner when the user has enough
/// data to risk losing but hasn't backed up recently.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileControllerProvider);
    final invoicesAsync = ref.watch(invoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (invoices) {
          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load profile: $e')),
            data: (profile) => _Body(
              businessName: profile?.businessName ?? '',
              invoices: invoices,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
        onPressed: () => context.push('/invoices/new'),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.businessName, required this.invoices});

  final String businessName;
  final List<Invoice> invoices;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Per-session dismissal flag. Resets when the app process restarts, so
  /// the banner can resurface the next day if the user still hasn't backed
  /// up. We do NOT persist this — persistent dismissal would defeat the
  /// data-loss-mitigation goal.
  bool _nudgeDismissed = false;

  /// Cached result of [BackupNudgeService.shouldNudge] — null while loading.
  bool? _shouldNudge;

  @override
  void initState() {
    super.initState();
    _checkNudge();
  }

  @override
  void didUpdateWidget(_Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check when the invoice list changes (e.g. user creates an invoice
    // from another tab and returns home).
    if (oldWidget.invoices.length != widget.invoices.length) {
      _checkNudge();
    }
  }

  Future<void> _checkNudge() async {
    final result = await BackupNudgeService.shouldNudge(
      currentInvoiceCount: widget.invoices.length,
    );
    if (mounted) setState(() => _shouldNudge = result);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final invoices = widget.invoices;
    final monthInvoices = invoices
        .where((i) =>
            i.issueDate.year == now.year && i.issueDate.month == now.month)
        .toList();
    final monthTotal =
        monthInvoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final outstanding = invoices
        .where((i) => i.status != 'paid')
        .fold<double>(0, (s, i) => s + i.totalAmount);

    final recent = invoices.take(5).toList();
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    final showNudge = _shouldNudge == true && !_nudgeDismissed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        if (widget.businessName.isNotEmpty)
          Text(
            'Hi, ${widget.businessName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        if (showNudge) ...[
          const SizedBox(height: 8),
          _BackupNudgeBanner(
            onDismiss: () => setState(() => _nudgeDismissed = true),
            onAction: () => context.go('/settings'),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Invoiced this month',
                value: fmt.format(monthTotal),
                icon: Icons.trending_up,
                accent: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Outstanding',
                value: fmt.format(outstanding),
                icon: Icons.hourglass_top,
                accent: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent invoices',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton(
              onPressed: () => context.go('/invoices'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            message: 'Tap "New Invoice" to create your first one. '
                'It only takes a minute — pick a client, add line items, '
                'and the GST is calculated for you.',
          )
        else
          ...recent.map((i) => _InvoiceTile(invoice: i)),
      ],
    );
  }
}

/// Dismissible banner prompting the user to back up their data.
/// Navigates to Settings (where the Backup & Restore section lives) on tap.
class _BackupNudgeBanner extends StatelessWidget {
  const _BackupNudgeBanner({
    required this.onDismiss,
    required this.onAction,
  });

  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Back up your data — it\'s stored only on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Back up now'),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFmt = DateFormat('dd MMM yyyy');

    Color statusColor;
    switch (invoice.status) {
      case 'paid':
        statusColor = Colors.green;
        break;
      case 'sent':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/invoices/${invoice.id}/preview'),
        title: Text(
          invoice.invoiceNumber,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          dateFmt.format(invoice.issueDate),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                invoice.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fmt.format(invoice.totalAmount),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
