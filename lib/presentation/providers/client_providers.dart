import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database.dart';
import '../../data/repositories/client_repository.dart';
import 'database_provider.dart';

part 'client_providers.g.dart';

/// Repository provider.
@Riverpod(keepAlive: true)
ClientRepository clientRepository(ClientRepositoryRef ref) {
  return ClientRepository(ref.watch(appDatabaseProvider));
}

/// All clients, alphabetical by name. Refreshable.
@riverpod
Future<List<Client>> clientList(ClientListRef ref) async {
  return ref.watch(clientRepositoryProvider).all();
}

/// SQL-level search by name or GSTIN. Used by the client list screen's
/// debounced search — at 500+ clients this is dramatically faster than
/// in-memory filtering on every keystroke.
@riverpod
Future<List<Client>> clientSearch(ClientSearchRef ref, String query) async {
  return ref.watch(clientRepositoryProvider).search(query);
}

/// A single client by id. Use family when looking up by FK.
@riverpod
Future<Client?> clientById(ClientByIdRef ref, String id) async {
  return ref.watch(clientRepositoryProvider).byId(id);
}
