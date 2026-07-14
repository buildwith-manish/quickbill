# Invory Privacy Policy

Last updated: 2026-07-14

## Overview

Invory is an offline-first mobile application that generates GST-compliant invoices for Indian freelancers and small businesses. This privacy policy explains how your data is handled.

## Data Storage

**All data is stored locally on your device.** Invory does NOT use any cloud service, server, or third-party API. Your business profile, client information, invoices, and invoice items are stored in a SQLite database file on your device's internal storage.

- **No account required** — Invory does not have user accounts, login, or authentication.
- **No network access** — The app does not make any network requests. It works fully in airplane mode.
- **No analytics or tracking** — We do not collect usage data, crash reports, or any telemetry.

## Permissions

Invory requests the following permissions:

### Camera and Photo Library (optional)
- **Purpose:** To upload your business logo for invoices.
- **Used by:** `image_picker` package.
- **When:** Only when you tap "Add logo" in Settings or Onboarding.

### Notifications (optional)
- **Purpose:** To remind you about upcoming and overdue invoice due dates.
- **Used by:** `flutter_local_notifications` package.
- **When:** You are asked for permission after completing onboarding. Denying this permission does not affect any other feature — invoices save normally, reminders simply won't show.

### File Storage (for backup)
- **Purpose:** To export your database backup file and share it via the native share sheet (WhatsApp, email, Drive, etc.).
- **Used by:** `share_plus` and `file_picker` packages.
- **When:** Only when you tap "Export backup" or "Import backup" in Settings.

## Data You Share

When you share an invoice PDF or a backup file, the file is sent through your device's native share sheet. Invory does not transmit any data directly — you choose the destination app (email, WhatsApp, Drive, etc.).

## Data Retention

Your data remains on your device until:
- You delete the app (all data is removed with the app).
- You use "Reset all data" in Settings (all data is permanently deleted from the device).
- You import a backup file (the current database is replaced, but a pre-import backup is saved as `.preimport.bak`).

## Third-Party Services

Invory does not use any third-party services. There are no analytics SDKs, no crash reporters, no ad networks, and no cloud databases.

## Children's Privacy

Invory is a business tool and is not directed at children under 13. We do not knowingly collect any data from anyone, including children.

## Changes to This Policy

If we update this privacy policy, we will update the "Last updated" date at the top of this page and include the changes in the next app release.

## Contact

For questions about this privacy policy, contact: buildwith-manish@users.noreply.github.com

## Trademark Notice

"Invory" is used as a working brand name. Before public launch, verify trademark availability in your jurisdiction.
