# QuickBill

A **standalone, offline-first Flutter mobile app** for solo Indian freelancers to generate GST-compliant invoices. No backend, no cloud, no authentication — everything runs locally on-device.

- **Primary platform:** Android
- **Secondary platform:** iOS (compiles cleanly, no platform-specific code)
- **State management:** Riverpod (with code generation)
- **Local DB:** Drift (SQLite) — file-based, persisted across app restarts
- **PDF:** `pdf` + `printing` packages
- **Share:** `share_plus` (native share sheet → WhatsApp / email / etc.)

---

## Setup

Requirements: Flutter `>=3.19.0`, Dart `>=3.3.0`.

```bash
cd quickbill
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

> The `build_runner` step generates `*.g.dart` files for Drift tables and Riverpod providers. These are excluded from version control — always run `build_runner` after cloning or after editing any `@DriftDatabase` / `@riverpod` annotated source.

---

## Architecture

```
lib/
  main.dart                         # entry point + ProviderScope
  app.dart                          # MaterialApp.router + go_router config
  theme/app_theme.dart              # Material 3 theme
  data/
    database/
      database.dart                 # @DriftDatabase, NativeDatabase, migration stub
      tables/                       # 4 Drift tables (clients, invoices, items, profile)
    repositories/                   # thin DAO-style wrappers around the DB
  domain/
    models/gst_calculation.dart     # pure value type + item input
    services/
      gst_service.dart              # CGST/SGST vs IGST logic — pure, unit-testable
      invoice_number_service.dart   # FY-based sequential invoice numbers
      pdf_service.dart              # builds PdfDocument from invoice data
  presentation/
    providers/                      # @riverpod providers for CRUD + computed state
    screens/                        # 8 screens, go_router routes
    widgets/                        # shared widgets (empty_state, gst_summary_card)
  utils/
    validators.dart                 # GSTIN, PAN, IFSC, UPI, email validators
    gst_state_codes.dart            # 36 Indian state/UT GST codes
```

### Navigation

`go_router` with a `StatefulShellRoute` for the 4-tab bottom nav (Home / Invoices / Clients / Settings). Invoice Create and Invoice Preview are pushed as full-screen routes on top of the shell.

---

## GST logic (core)

`gst_service.dart` exposes a single pure function:

```dart
GstCalculation calculateInvoiceGst({
  required List<InvoiceItemInput> items,
  required String sellerStateCode,
  required String placeOfSupplyStateCode,
});
```

- **Intrastate** (seller state == buyer state): split GST rate equally → CGST + SGST.
- **Interstate** (seller state != buyer state): full rate → IGST.
- **Unregistered seller** (no GSTIN): no tax line items; PDF shows the unregistered disclaimer.

---

## Invoice numbering

Format: `INV/<FY>/####` where FY is the Indian financial year (April–March). Example: `INV/2026-27/0001`.

Counter is derived from existing rows for the current FY — no separate mutable counter column.

---

## Non-goals (v1)

No cloud sync, no auth, no multi-currency, no recurring invoices, no client portal, no team support, no e-invoicing IRN integration, no expense tracking, no push notifications. All of these are v2 ideas.

---

## License

Proprietary — for personal use of the freelancer who deploys it.
