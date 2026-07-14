import 'package:drift/drift.dart';

import '../database/database.dart';

/// CRUD for the single BusinessProfile row (id = 1).
///
/// There is only ever one row — the freelancer's own business details.
/// Created during first-launch onboarding, edited from Settings.
class BusinessProfileRepository {
  BusinessProfileRepository(this._db);

  final AppDatabase _db;
  static const int _id = 1;

  /// Returns the profile, or null if onboarding hasn't happened yet.
  Future<BusinessProfile?> get() async {
    return (_db.select(_db.businessProfiles)
          ..where((t) => t.id.equals(_id)))
        .getSingleOrNull();
  }

  /// Insert or replace the row at id = 1.
  Future<BusinessProfile> upsert(BusinessProfilesCompanion companion) async {
    await _db.into(_db.businessProfiles).insertOnConflictUpdate(
          companion.copyWith(id: const Value(_id)),
        );
    return (await get())!;
  }

  Future<void> delete() async {
    await (_db.delete(_db.businessProfiles)
          ..where((t) => t.id.equals(_id)))
        .go();
  }

  /// Wipes ALL data from the database (business profile + clients +
  /// invoices + items + seq counters). Used by Settings → "Reset all data".
  Future<void> wipeAll() async {
    await _db.wipeAll();
  }
}
