# Nordic Ledger: Project Rules

Flutter (Android phones + tablets) money-lending ledger for small lending companies.
Firebase Auth (Google) + Cloud Firestore, **offline-first**, no Cloud Functions (Spark plan).
Design source of truth: Stitch project `7509627548686012595` ("Micro-Finance Loan Manager UI", design system "Nordic Ledger").
Requirements and design history: `docs/kani/runs/2026-11-20-nordic-ledger-multi-company-money-lending-app-architecture-schema-claudemd.md`.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed / json
flutter analyze                                            # must be clean
flutter test                                               # unit + widget
cd firebase && npm test                                    # Firestore rules tests (emulator)
firebase emulators:start --only firestore,auth
flutter build appbundle --release
```

## Architecture (feature-first, layered inside each feature)

```
lib/
  main.dart · bootstrap.dart · app.dart · firebase_options.dart
  core/        theme/ (app_theme.dart, app_breakpoints.dart) · money/ · time/ · routing/
               firebase/ (paths, converters) · widgets/ (shared atoms + adaptive layouts) · sync/ · errors/
  domain/      PURE DART, no Flutter or Firebase imports: models/ (freezed) · ledger/ (schedule, projection, rollover)
  features/<name>/
               data/          Firestore repositories (the only place that touches cloud_firestore)
               application/   Riverpod providers / Notifiers (state + use-cases)
               presentation/  screens/ + widgets/
```

- State: **Riverpod** (code-gen `@riverpod`). Navigation: **go_router** with auth/MPIN/company guards.
- Widgets never call Firestore directly. Use screen → provider → repository.
- All ledger math (schedule generation, FIFO allocation, overdue, auto-extension, rollover) lives in `lib/domain/ledger/` and is unit-tested. UI only renders projections.

## Money, dates, locale (non-negotiable)

- Money is **`int` paise** everywhere (`Money` value type in `core/money/`). Never `double` for money.
- Format with `core/money/inr_format.dart`: `₹` prefix, no space, Indian grouping (`₹1,00,000`, `₹12,34,567`). Show paise only when non-zero. Chart axes use short form (`₹50k`, `₹1L`, `₹1.5L`, `₹1Cr`).
- **Every amount, count, date and phone number** renders with `FontFeature.tabularFigures()`. Use `MoneyText` / `AppTextStyles.*Tabular`, never a raw `Text` for numbers.
- Civil dates are stored as `'yyyy-MM-dd'` strings in **IST (Asia/Kolkata)**. "Today" comes only from `core/time/ist_clock.dart` (injectable `Clock`). Never call `DateTime.now()` in domain or UI code.
- Locale `en_IN`. Phone numbers are `+91` E.164 in storage and displayed as `+91 98450 12890`.

## Design tokens (locked; source: Stitch "Nordic Ledger" + owner overrides)

All tokens live in `lib/core/theme/app_theme.dart` (`AppColors`, `AppSpacing`, `AppRadii`, `AppTextStyles`, `AppTheme.light`).
**Never hard-code a hex color, font size, radius, padding or shadow in a screen or widget.** Add a token instead.

| Token | Value | Use |
|---|---|---|
| `background` | `#F8F9FA` | scaffold canvas |
| `surface` | `#FFFFFF` | cards, sheets, inputs |
| `border` | `#E5E7EB` | 1px card/input borders (elevation = border, not shadow) |
| `borderFocus` / `primary` | `#1E3A5F` | primary buttons, active nav, focused input border |
| `primarySubtle` | `#EDF2F7` | info notes, soft chips, selected tint |
| `collected` | `#2E7D5B` · tint `#EAF5F0` | paid / collected / synced |
| `upcoming` | `#D97706` · tint `#FEF3C7` | due soon / pending / partial |
| `overdue` | `#C2410C` · tint `#FFF1EB` · border `#FED7AA` | missed / overdue / destructive. **Overrides Stitch's #DC2626** |
| `textPrimary` | `#111827` | body text |
| `textSecondary` | `#6B7280` | metadata, axis labels |
| `textTertiary` | `#9CA3AF` | placeholders |
| `track` | `#F1F3F5` | progress tracks, chart gridlines |
| `pressed` | `#F9FAFB` | pressed/selected row fill |

- Fonts (bundled as assets, no runtime download, because the app is offline-first): **Plus Jakarta Sans** for headlines and large currency, **Inter** for body and labels.
  - `headlineXl` 28/36 w700 −0.02em (mobile)
  - `headlineLg` 22/28 w600
  - `headlineSm` 18/24 w600
  - `titleMd` Inter 16/24 w600
  - `bodyLg` 16/24
  - `bodyMd` 14/20
  - `labelMd` 12/16 w500 +0.02em (sentence case, no ALL CAPS)
  - `currencyDisplay` PJS 32/40 w700
  - `currencyItem` Inter 15/20 w600
- Spacing (4/8 rhythm): `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. Card padding 16 (compact) / 24 (balance summaries).
- Radii: `sm 4 · base 8` (inputs, buttons) `· md 12 · lg 16` (cards) `· xl 24` (bottom-sheet top) `· full` (pills/chips).
- Components:
  - Primary button: navy fill, white label, 8 radius, 48 tall, no shadow.
  - Secondary: white with 1px border.
  - Ghost: navy text.
  - Inputs: white, 1px border, 56 tall, focus = navy border, `₹` prefix in PJS 600 `textSecondary`.
  - Status pills: full radius, 24–28 tall, tint background + status text + icon/dot.
  - Cards: white, 1px border, 16 radius, **no elevation**.
  - Sheets/dialogs may use the single ambient shadow `0 4 20 -2 rgba(17,24,39,.05)`.
- Status color is never the only signal. Always pair it with a label and/or icon.
- **Charts** (`fl_chart`):
  - single y-axis;
  - due = neutral `#E5E7EB` bar, collected = sage bar inside it;
  - **amber and terracotta must never be adjacent unlabeled segments** (ΔE 12.7, indistinguishable), so status breakdowns use separate labelled rows, never stacked bars;
  - 1px `track` gridlines, tabular axis labels, tooltip on tap, and a semantics summary for every chart.

## Responsive layout

Breakpoints in `core/theme/app_breakpoints.dart`, consumed only via `AdaptiveScaffold` / `ListDetailLayout`. No per-screen `MediaQuery` maths.
- **compact** < 600dp: bottom `NavigationBar` (Dashboard · Calendar · Borrowers · Settings), 16 margins, single column.
- **medium** 600–839dp: `NavigationRail`, 24 margins, 2-column grids.
- **expanded** ≥ 840dp: `NavigationRail` with labels + New-loan FAB, 12-column grid, 32 margins, max content width 1280. List-detail split panes for Borrowers (40/60), Calendar and Overdue. Record Payment / Rollover open as a dialog or side sheet (max 560) instead of a bottom sheet.
- Touch targets ≥ 48dp. Layouts must survive text scale 1.3×.

## Firestore & offline rules

- Tenancy: everything lives under `companies/{companyId}/...`. Every query is scoped to the active company. Security rules enforce membership and role. Never rely on hiding UI.
- Persistence is on (unlimited cache). **Ledger writes are `WriteBatch`es** (they queue offline). Do **not** use `runTransaction` for ledger writes, because transactions fail offline. Transactions are allowed only for online-only flows (invite accept).
- `transactions` docs are **append-only and immutable**. Corrections are a new `reversal` doc, never an edit or delete. No hard deletes of financial records.
- Contract aggregates are only ever changed with `FieldValue.increment`. Installment paid amounts and statuses are **derived** by `domain/ledger/contract_projection.dart`, never stored.
- Auto-extension installments (missed/partial rolled to the end) are **computed, never written**.
- Client-generated document IDs (`uuid v4`) for all ledger docs, so a retried batch is idempotent.
- Do not use Firestore `count()` / `sum()` aggregation queries for app metrics, because they do not work offline. Compute from the cached snapshot via the domain layer.
- Every write stamps `recordedBy` (uid), `recordedByName`, `recordedAt` (serverTimestamp) and `clientRecordedAt`.

## Roles

`owner`: everything (borrowers, contracts, rollover, reversal, members, invites, company settings).
`collector`: read the company's data, record payments, reschedule, send reminders. Cannot create, roll over, cancel or reverse contracts, or manage members.
Gate UI with `currentRoleProvider`, and mirror every gate in `firestore.rules`.

## Conventions

- Dart 3, `flutter_lints` + `very_good_analysis`-style strictness; `flutter analyze` must be clean.
- Immutable models with `freezed`. Enums are serialized as lowercase strings.
- File names `snake_case.dart`. One public widget per file in `presentation/widgets/`.
- Copy follows Stitch except these known mock errors, which must **not** be reproduced:
  - "daily interest accruals" (the model is upfront interest only);
  - "Local SQLite encrypted";
  - credit scores, "UPI Verified", UTR verification, auto-mandate, crypto/hash wording;
  - per-installment reminders described as borrower SMS. They are local notifications to the app user.
- Tests:
  - `domain/` has 100% branch coverage on ledger math;
  - widget tests at compact and expanded widths for Dashboard and Borrowers;
  - rules tests for every collection × role.
- Commit only when asked. Never commit `google-services.json` secrets beyond what FlutterFire requires, and never commit `key.properties` or keystores.
