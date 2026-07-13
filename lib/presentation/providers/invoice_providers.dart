import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/services/invoice_number_service.dart';
import '../../domain/services/reminder_service.dart';
import 'database_provider.dart';

part 'invoice_providers.g.dart';

@Riverpod(keepAlive: true)
InvoiceRepository invoiceRepository(InvoiceRepositoryRef ref) {
  return InvoiceRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
InvoiceNumberService invoiceNumberService(InvoiceNumberServiceRef ref) {
  return InvoiceNumberService(
    ref.watch(appDatabaseProvider),
    ref.watch(invoiceRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ReminderService reminderService(ReminderServiceRef ref) {
  return ReminderService(ref.watch(invoiceRepositoryProvider));
}

/// All invoices, newest first.
@riverpod
Future<List<Invoice>> invoiceList(InvoiceListRef ref) async {
  return ref.watch(invoiceRepositoryProvider).all();
}

/// A single invoice by id.
@riverpod
Future<Invoice?> invoiceById(InvoiceByIdRef ref, String id) async {
  return ref.watch(invoiceRepositoryProvider).byId(id);
}

/// Line items for a given invoice id.
@riverpod
Future<List<InvoiceItem>> invoiceItems(InvoiceItemsRef ref, String invoiceId) async {
  return ref.watch(invoiceRepositoryProvider).itemsFor(invoiceId);
}

/// Suggested next invoice number for the current FY.
/// Pre-fills the Invoice Create screen's invoice-number field.
@riverpod
Future<String> nextInvoiceNumber(NextInvoiceNumberRef ref) async {
  return ref.watch(invoiceNumberServiceProvider).nextNumber();
}
