import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../utils/gst_state_codes.dart';
import '../../providers/client_providers.dart';
import '../../widgets/empty_state.dart';

/// Search debouncer duration — 300ms balances responsiveness vs. query load.
const _searchDebounce = Duration(milliseconds: 300);

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use the search provider when there's a query, otherwise the full list.
    final clientsAsync = _query.isEmpty
        ? ref.watch(clientListProvider)
        : ref.watch(clientSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: 'Search by name or GSTIN',
              leading: const Icon(Icons.search),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (clients) {
                if (clients.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: _query.isEmpty ? 'No clients yet' : 'No matches',
                    message: _query.isEmpty
                        ? 'Add your first client to start invoicing them. '
                            'GSTIN is optional — freelancers can invoice unregistered clients too.'
                        : 'Try a different name or GSTIN.',
                    actionLabel: _query.isEmpty ? 'Add client' : null,
                    onAction: _query.isEmpty
                        ? () => context.push('/clients/new')
                        : null,
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: 0.3,
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              await ref
                                  .read(clientRepositoryProvider)
                                  .delete(c.id);
                              ref.invalidate(clientListProvider);
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Delete',
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            c.gstin != null && c.gstin!.isNotEmpty
                                ? 'GSTIN: ${c.gstin}'
                                : 'No GSTIN',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Text(
                            stateNameForCode(c.stateCode) ?? c.stateCode,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => context.push('/clients/${c.id}/edit'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
