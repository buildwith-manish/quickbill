# Invory — Play Store Listing

## App title (Play Store, ~30 char)
Invory: GST Invoice, No Login

## Short description (80 char)
Offline GST invoices. No login, no cloud, no subscription. Just bill & go.

## Full description (4000 chars max)
Tired of invoicing apps that force you to sign up, sync to the cloud,
and lock features behind a subscription just to bill a client?

Invory is different — by design.

✓ NO LOGIN — open the app and start billing in 10 seconds
✓ NO CLOUD — your business data stays on your phone, always
✓ NO SUBSCRIPTION TRAP — one-time setup, no recurring fees, no upsell calls
✓ CORRECT GST — automatic CGST/SGST vs IGST based on place of supply
✓ WORKS OFFLINE — no signal? No problem. Bill from anywhere.
✓ INSTANT SEARCH — even with thousands of invoices, no spinner, ever.
  Tested with 500 clients + 2,000 invoices: all queries under 10ms.
✓ YOUR DATA, YOUR CONTROL — one-tap backup/export, restore anytime,
  nothing held hostage on someone else's server

Built for freelancers and solo service providers who need fast,
GST-compliant invoices — not a full accounting suite with inventory,
staff logins, and features you'll never use.

Create client → Add items → Get a professional GST PDF → Share on
WhatsApp. That's it.

### Features

• GST-compliant invoices with automatic CGST/SGST/IGST
• Discount support (flat or percentage, applied before tax)
• Partial payment tracking — mark invoices as partially paid
• Quotations — create quotes, convert to invoices with one tap
• Two PDF templates — Minimal and Classic
• Sequential invoice numbering per financial year
• Client management with GSTIN auto-validation
• Payment due-date reminders (local notifications, no push)
• Backup & restore via file export
• "Your Data" screen — see exactly where your data lives
• English + Hindi localization
• Works fully offline — no network permissions requested

### Who is it for?

• Freelancers and consultants
• Small service providers
• Sole proprietors
• Anyone who needs to issue GST invoices without complicated accounting software

### Disclaimer

Invory helps generate GST-compliant invoice formats but is not a substitute for professional accounting or tax advice. Always verify tax calculations before filing returns.

## Keywords (comma-separated)
gst invoice, invoice maker, offline invoice app, gst billing app, invoice without login, free gst invoice no subscription, local invoice app india

## App category
Business

## Content rating
Everyone

## Target audience
Business professionals, freelancers, small business owners in India

## Privacy policy URL
https://github.com/buildwith-manish/quickbill/blob/main/PRIVACY_POLICY.md

## Support email
buildwith-manish@users.noreply.github.com

## Screenshot sequence (6 shots, this order)
1. Home screen with "No login required" visible in trust card
2. Invoice create screen mid-fill (shows speed)
3. GST breakdown on preview (CGST/SGST split visible — proves correctness)
4. Multi-page invoice PDF (25+ items rendering cleanly — proves pagination
   works, unlike competitor apps that overlap content)
5. WhatsApp share sheet open (proves the actual delivery moment)
6. Settings → "Your Data" screen (proves the privacy claim, not just states it)

## Release notes (v2.1.0)

Performance + PDF hardening — proves the speed and reliability claims.

• NEW: Database indexes on status, client name, issue date — instant queries
• NEW: SQL-level debounced search (was in-memory filtering on every keystroke)
• VERIFIED: 500 clients + 2,000 invoices tested — all queries under 10ms
• NEW: PDF stress tests — 25/50 line items, 200-char names, 120-char
  descriptions — all paginate cleanly without overlapping content
• NEW: Pricing philosophy documented in README — 5 non-negotiable principles
  to prevent future subscription/upsell drift
• Updated store listing with "Instant search, no spinner ever" claim
  (backed by stress test data)

## Release notes (v1.3.0)

Competitive build — closes the real feature gaps vs. legacy billing apps.

• NEW: "Your Data" screen — see your DB file path, size, and export anytime
• NEW: First-launch trust card on onboarding ("No account. No cloud.")
• NEW: Discount support (flat ₹ or %, applied before tax per GST rules)
• NEW: Partial payment tracking — record amount paid, see balance due
• NEW: Quotations — create quotes with QTN/ prefix, convert to invoices
• NEW: Backup nudge after every 10 new invoices (not just time-based)
• NEW: PDF renders discount line + "Amount Paid / Balance Due"
• NEW: Quotation PDFs show "QUOTATION" header instead of "TAX INVOICE"
• Improved: Backup nudge logic (proactive, not just time-based)
• All existing data preserved — backward compatible (schema v3 migration)
