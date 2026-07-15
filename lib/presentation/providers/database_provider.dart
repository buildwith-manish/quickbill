import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database.dart';
import '../../data/repositories/business_profile_repository.dart';

part 'database_provider.g.dart';

/// Single app-wide [AppDatabase] instance. Created lazily on first access.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// Single app-wide [BusinessProfileRepository].
@Riverpod(keepAlive: true)
BusinessProfileRepository businessProfileRepository(
    BusinessProfileRepositoryRef ref) {
  return BusinessProfileRepository(ref.watch(appDatabaseProvider));
}
