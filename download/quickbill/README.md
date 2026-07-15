# BillKraft

**Professional Invoicing. Anywhere.**

BillKraft is an offline-first invoicing app built for freelancers, small businesses, and growing companies. Create professional invoices, manage clients, generate PDFs, and keep your business organized anywhere — even without an internet connection.

- **Primary platform:** Android
- **Secondary platform:** iOS (compiles cleanly, no platform-specific code)
- **State management:** Riverpod (with code generation)
- **Local DB:** Drift (SQLite) — file-based, persisted across app restarts
- **PDF:** `pdf` + `printing` packages
- **Share:** `share_plus` (native share sheet → WhatsApp / email / etc.)

> BillKraft is an offline-first invoicing app built for freelancers, small businesses, and growing companies. Create professional invoices, manage clients, generate PDFs, and keep your business organized anywhere — even without an internet connection.

---

## Setup

Requirements: Flutter `>=3.19.0`, Dart `>=3.3.0`.

```bash
cd quickbill
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
dart run flutter_launcher_icons
flutter run
```

> The `build_runner` step generates `*.g.dart` files for Drift tables and Riverpod providers. These are excluded from version control — always run `build_runner` after cloning or after editing any `@DriftDatabase` / `@riverpod` annotated source.
>
> The `flutter_launcher_icons` step regenerates Android adaptive icons and iOS app icons from `assets/icon/icon.png` and `assets/icon/icon_foreground.png`.

---

## Architecture

```
lib/
  main.dart                         # entry point + ProviderScope
  app.dart                          # MaterialApp.router + go_router config
  theme/app_theme.dart              # Material 3 theme — BillKraft brand palette
  data/
    database/
      database.dart                 # @DriftDatabase, NativeDatabase, migration stub
      tables/                       # 5 Drift tables (clients, invoices, items, profile, seq_counters)
    repositories/                   # thin DAO-style wrappers around the DB
  domain/
    models/gst_calculation.dart     # pure value type + item input
    services/
      gst_service.dart              # CGST/SGST vs IGST logic — pure, unit-testable
      invoice_number_service.dart   # FY-based sequential invoice numbers
      pdf_service.dart              # builds PdfDocument from invoice data
      backup_service.dart           # export / import with validation pipeline
      backup_nudge_service.dart     # SharedPreferences-based backup reminder
      reminder_service.dart         # local notifications for due dates
      logo_service.dart             # image_picker wrapper for logo upload
  presentation/
    providers/                      # @riverpod providers for CRUD + computed state
    screens/                        # 8 screens, go_router routes
    widgets/                        # shared widgets (empty_state, gst_summary_card, logo_picker, db_corruption_guard)
  utils/
    validators.dart                 # GSTIN, PAN, IFSC, UPI, email validators
    gst_state_codes.dart            # 36 Indian state/UT GST codes
  l10n/
    app_en.arb                      # English strings
    app_hi.arb                      # Hindi strings
```

### Navigation

`go_router` with a `StatefulShellRoute` for the 4-tab bottom nav (Home / Invoices / Clients / Settings). Invoice Create and Invoice Preview are pushed as full-screen routes on top of the shell.

---

## Brand palette

| Role | Color | Hex |
|---|---|---|
| Primary | Blue | `#2563EB` |
| Secondary | Light blue | `#3B82F6` |
| Accent | Emerald | `#10B981` |
| Background | Slate-50 | `#F8FAFC` |
| Surface | White | `#FFFFFF` |
| Text | Slate-900 | `#0F172A` |

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

Counter is persisted in a `SeqCounters` table keyed by FY label — survives reinstalls and backup restores.

---

## Backup & restore

- **Export:** Copies the live SQLite DB to a timestamped file (`billkraft-backup-YYYYMMDD_HHMM.sqlite`) and opens the native share sheet.
- **Import:** 5-stage validation pipeline (extension, SQLite header, schema version, integrity check, expected tables) runs against a temp copy BEFORE touching the production DB. Pre-import DB is preserved as `.preimport.bak` for manual rollback.
- **Backward compatibility:** Old `quickbill-backup-*.sqlite` files can still be imported — the validation pipeline accepts any `.sqlite` file with the correct header and tables.

---

## Non-goals (v1)

No cloud sync, no auth, no multi-currency, no recurring invoices, no client portal, no team support, no e-invoicing IRN integration, no expense tracking, no push notifications (beyond local due-date reminders). All of these are v2 ideas.

---

## Pricing philosophy

BillKraft is currently free with no subscription. These principles are documented now — before any monetization is considered — so they can't quietly erode later.

1. **What you see is what you get.** Any feature shown in marketing/store screenshots must be usable in the free tier, or clearly marked "Pro" in the screenshot itself — never revealed as locked only after install.

2. **No feature becomes paid retroactively.** No feature that was free becomes paid in a later update for existing users. If you downloaded BillKraft when PDF export was free, PDF export stays free for you forever.

3. **If a paid tier is ever introduced**, it's a flat one-time or transparent monthly price. No "credits," no "wallet recharge," no consumption-based unlocks for core billing features. PDF export, backup, and GST calculation stay free forever.

4. **No sales calls, no upsell nudges** beyond a single optional "Support development" screen in Settings. The app never interrupts your billing flow to ask for money.

5. **Your data is never held hostage behind a paywall.** Even if a paid tier exists, the free tier always includes full export/backup — you can take your data with you at any time, regardless of payment status.

These principles are a direct response to the pricing complaints driving users away from competitor invoicing apps. They are a product decision, not a marketing one.

---

## License

Proprietary — for personal use of the freelancer who deploys it.

---

## Trademark notice

"BillKraft" is used as a working brand name. Before public launch, verify trademark availability in your jurisdiction and acquire the relevant domains (`billkraft.app`, `billkraft.com`).
