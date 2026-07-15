import 'package:drift/drift.dart';

/// The freelancer's own business profile.
///
/// There is only ever a single row (id = 1). It is created during
/// first-launch onboarding and edited from the Settings screen.
class BusinessProfiles extends Table {
  IntColumn get id => integer().clientDefault(() => 1)();
  TextColumn get businessName => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get stateCode => text()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get panNumber => text().nullable()();
  TextColumn get bankAccountName => text().nullable()();
  TextColumn get bankAccountNumber => text().nullable()();
  TextColumn get bankIfsc => text().nullable()();
  TextColumn get upiId => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  BoolColumn get isGstRegistered =>
      boolean().withDefault(const Constant(true))();

  /// v3: which PDF template to use. 'minimal' (default) or 'classic'.
  TextColumn get invoiceTemplate =>
      text().withDefault(const Constant('minimal'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
