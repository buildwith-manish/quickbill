import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database.dart';
import 'database_provider.dart';

part 'business_profile_providers.g.dart';

/// Notifier for the freelancer's own BusinessProfile row.
///
/// Returns null on first launch (no profile yet) — the router observes this
/// to redirect to onboarding. Mutations upsert the single row (id = 1) and
/// refresh state.
@riverpod
class BusinessProfileController extends _$BusinessProfileController {
  @override
  Future<BusinessProfile?> build() async {
    return ref.read(businessProfileRepositoryProvider).get();
  }

  /// Insert or replace the profile row at id = 1.
  Future<void> saveProfile(BusinessProfilesCompanion companion) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessProfileRepositoryProvider).upsert(companion);
      return ref.read(businessProfileRepositoryProvider).get();
    });
  }
}
