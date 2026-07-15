import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// CRUD for Clients (buyers).
class ClientRepository {
  ClientRepository(this._db);

  final AppDatabase _db;

  Future<List<Client>> all() async {
    return (_db.select(_db.clients)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// SQL-level search by name or GSTIN. Uses LIKE with wildcards on both
  /// sides for substring matching. Case-insensitive by default in SQLite
  /// for ASCII text.
  ///
  /// At 500+ clients, this is dramatically faster than loading all rows
  /// and filtering in-memory on every keystroke. The caller should debounce
  /// calls (e.g. 300ms) to avoid excessive queries.
  Future<List<Client>> search(String query) async {
    final q = '%${query.trim()}%';
    final results = (_db.select(_db.clients)
          ..where((t) => t.name.like(q) | t.gstin.like(q))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    return results;
  }

  Future<Client?> byId(String id) async {
    return (_db.select(_db.clients)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Client> create({
    required String name,
    required String stateCode,
    String? gstin,
    String? address,
    String? email,
    String? phone,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.clients).insert(ClientsCompanion.insert(
          id: id,
          name: name,
          stateCode: stateCode,
          gstin: Value(gstin),
          address: Value(address),
          email: Value(email),
          phone: Value(phone),
        ));
    return (await byId(id))!;
  }

  Future<void> update(Client client) async {
    await (_db.update(_db.clients)..where((t) => t.id.equals(client.id)))
        .write(ClientsCompanion(
      name: Value(client.name),
      stateCode: Value(client.stateCode),
      gstin: Value(client.gstin),
      address: Value(client.address),
      email: Value(client.email),
      phone: Value(client.phone),
    ));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.clients)..where((t) => t.id.equals(id))).go();
  }
}
