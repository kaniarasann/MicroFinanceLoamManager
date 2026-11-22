# Kani Orchestrator Run
**Title:** Nordic Ledger — multi-company money-lending app (architecture, schema, CLAUDE.md)
**Type:** feature
**Date:** 2026-11-20
**Status:** In Progress
**Run ID:** 2026-11-20-nordic-ledger-multi-company-money-lending-app-architecture-schema-claudemd

---

## 0. Feasibility & Approach Review
> Filled by: Principal Architect

**Final Description:** Greenfield Flutter mobile app for money-lending management on Firebase Auth (Google Sign-In) + Cloud Firestore + **Cloud Functions (TypeScript, callable) for all ledger mutations**, on a new Firebase project `microfinance-loan-mgr` (Blaze plan required). **Multi-company:** a user can create/belong to multiple companies; per-company membership roles **owner** (full access, create contracts/rollovers, invite staff by Google email, manage roles) and **collector** (views borrowers and dues **only of the company/companies they are a member of**; records payments, reschedules; cannot create/rollover/delete contracts); company switcher. Local 4-digit MPIN (flutter_secure_storage) + optional biometric unlock (local_auth); MPIN reset = Google re-auth. Borrowers hold multiple concurrent contracts (optional guarantor + notes). Upfront interest flat ₹ or % of sanctioned; net disbursed = sanctioned − upfront. Auto-generated Daily/Weekly/Monthly schedule on preferred weekday/date. Partial & advance payments allocated FIFO across installments. Missed installments surface with days overdue, Pay Now and reschedule/carry-forward. Rollover closes remaining balance into a new contract with fresh upfront interest, audit preserved (bidirectional links). Dashboard: Total Net Disbursed / Sanctioned Receivable / Collected / Overdue. Call/WhatsApp/SMS launch via url_launcher. Every transaction stamps `recordedBy` + timestamp. UI faithful to Stitch project 7509627548686012595 (8 screens; inventory below), tokens locked in `lib/core/theme/app_theme.dart` and CLAUDE.md (overdue = terracotta #C2410C overriding design.md red). **This run = plan only** (folder architecture, Firestore schema + rules outline, Functions API, CLAUDE.md); no app code until user confirms.

**Approach Assessed:** Single-lender Flutter + Firebase lending app with client-side WriteBatch/transaction ledger writes, planned against existing Stitch screens.

**Completeness Check:** Flagged: Firebase project choice, Stitch extras (biometric, contact launch, partial/advance payments, guarantor/notes), user model, MPIN reset, audit. User confirmed: new project `microfinance-loan-mgr`; all four extras in scope; **multi-company with owner/collector roles**; MPIN reset via Google re-auth; credit scores / UPI verification / auto-mandate / batch UPI links out of scope; invite by Google email; `recordedBy` audit on every transaction.

**Concerns Raised:**
- With multiple staff writing, client-only ledger math (balance updates, FIFO payment allocation, rollover settlement) can be bypassed by a modified client; Firestore rules cannot re-verify multi-document ledger arithmetic.
- Multi-company tenancy needs a company→members→role model and company-scoped rules; a flat `users/{uid}` layout won't support it.
- "Total overdue" is time-dependent; a stored counter goes stale without a scheduler.

**Alternative(s) Proposed:**
- Callable Cloud Functions performing each ledger write as a server-side Firestore transaction (`createContract`, `recordPayment`, `rescheduleInstallment`, `rolloverContract`); clients read-only on ledger collections.
- `companies/{companyId}/{borrowers|contracts|installments|transactions}` + `companies/{companyId}/members/{uid}` with role; rules check membership/role.
- Overdue & dashboard totals via Firestore `sum()`/`count()` aggregation queries over a stored per-installment `outstanding` field filtered by `dueDate < today` — no stale stored totals, no scheduler.

**Gate 1 revision (user, 2026-11-20). This supersedes the Cloud Functions decision below.**
- **Android / Google Play only.** No iOS and no Sign in with Apple. Publishing to Play is the final step of the project.
- **Offline-first with Firebase sync.** Every action works with no internet, including payments, contract creation, reschedule and rollover, and syncs to Firestore when the device is back online.
- **Consequences:**
  - **No Cloud Functions.** Callables need a network, and Firestore *transactions* fail offline. Ledger writes are atomic **WriteBatch**es that queue offline.
  - Security rules enforce membership, role and field shape.
  - The Spark (free) plan is sufficient.
- **Accepted trade-off:** ledger maths runs on the device, so the app trusts staff devices.
- **New concern: concurrent offline edits.** Two collectors offline at the same time on the same contract would overwrite each other's stored balances, because Firestore resolves conflicts as last-write-wins.
- **Mitigation (adopted):**
  - The transaction log is **append-only and immutable** (client-generated IDs).
  - Contract aggregates use `FieldValue.increment()`, which merges correctly across devices.
  - Installment paid/status is **derived by replaying payments oldest-first (FIFO) against the schedule**. It is not stored as mutable truth.
  - A double collection made while offline appears as an "excess / credit" flag for the owner and is never silently lost.

**Outcome (original):** User chose Cloud Functions (accepts Blaze plan; billing must be linked manually). Multi-company owner/collector model adopted. Toolchain: Flutter 3.41.9 / Dart 3.11.5, Node 24, Firebase CLI 15.37; FlutterFire CLI not installed (needed for `flutterfire configure`). Repo empty — greenfield.

### Stitch screen inventory (source of truth for UI)
Project "Micro-Finance Loan Manager UI", design system "Nordic Ledger". Fonts: Plus Jakarta Sans (headlines, currency-display), Inter (body/labels). Bottom nav: Dashboard · Calendar · Borrowers · Settings.
1. **Auth & MPIN** — brand header, "Session Active" pill, "Welcome back, {name}", 4 PIN dots, circular keypad (biometric key, 0, backspace), "Forgot MPIN?", OR, "Continue with Google".
2. **Executive Dashboard** — greeting/date, "+ New Loan"; KPI cards (to become 2×2: Net Disbursed / Sanctioned Receivable / Collected / Overdue); recovery-rate bar; Overdue alert card → tracker; Today's Due card (amount, received-today progress); "Due Today" list with All/Pending/Collected chips, Record buttons.
3. **Collection Calendar** — month nav, Month/List toggle, grid with status dots (sage/amber/terracotta), legend totals, selected-day list cards with status pills, Call + Record.
4. **Create New Loan Contract** — borrower picker/new; sanctioned ₹ input + quick chips; Flat ₹ / % segmented; upfront interest + "x% effective"; Sanctioned − Upfront = Net Cash Handover; frequency segmented; installment ₹ + auto tenor; preferred weekday/date chips; first collection + maturity dates; guarantor, notes; sticky footer "Create & Disburse Loan".
5. **Borrower Search & Profile** — search + filter chips; profile card (phone, locality), tiles Active Exposure / Lifetime Lent / Collected; Call / WhatsApp / + New Loan; tabs Active / Ledger / Closed; contract cards (Sanctioned/Paid/Remaining, cleared % bar, next due, cycles n/N); Recent Receipts.
6. **Record Payment & Rollover** — sheet; Outstanding chip; segmented Record Installment / Rollover; amount + chips Full Due / 2× / Advance; collection date; mode UPI / Cash / Bank; reference; note; rollover eligibility card → breakdown; "Confirm & Record ₹X".
7. **Contract Installment Schedule** — header tiles Sanctioned / Disbursed / Upfront Fee, principal-cleared bar, overdue banner; chips All/Missed/Upcoming/Paid; timeline cards: paid (mode, cleared date, ref), overdue (terracotta rail, "Overdue by N days", Collect + Reschedule), upcoming, planned, maturity.
8. **Overdue Tracker** — Total Overdue card (n loans, highest delay), risk % card; chips All / Critical >3d / Recent 1–3d; cards with "N days late", scheduled date, phone, overdue ₹, Call / WhatsApp / Record.

---

## 1. Business Requirements
> Filled by: Business Analyst

**Knowledge Sources Consulted:**
- `docs/kani/knowledge/KNOWLEDGE_BASE.md` — newly created, no prior runs
- `docs/kani/knowledge/**/*` — only `.gitkeep`
- `README.md` — does not exist (greenfield repo, no commits)
- `docs/**/*.md` (excluding runs) — none
- Source files — none exist
- Section 0 of this living doc (vetted scope + Stitch screen inventory)
- Stitch project 7509627548686012595: design.md ("Nordic Ledger" tokens) and screenshots of all 8 screens
- Firebase environment: CLI authenticated, no project linked to this directory

**Request Summary:**
Build "Nordic Ledger", a Flutter mobile app that lets small lending businesses (companies with an owner and field collectors) issue upfront-interest loans, auto-schedule repayments, record collections, chase overdue installments and roll contracts over, all with exact, tamper-resistant balances. A book that is accurate and auditable is the core business value: a wrong balance in money lending is a dispute with a borrower.

**Delivery gating (user instruction):** The user's "Step 1" deliverables are the folder architecture, the Firestore schema and the CLAUDE.md design/convention lock. They are produced in Section 2 and reviewed at Gate 2. No application code is written until the user approves Gate 2.

**Stakeholder Impact:**
- **Company owner (lender):** creates companies, invites staff, creates and disburses contracts, runs rollovers, and sees portfolio metrics (Net Disbursed, Sanctioned Receivable, Collected, Overdue).
- **Collector (staff):** sees due and overdue lists and the calendar **only for the company or companies they have joined**, records payments (full, partial or advance), and reschedules missed installments. Cannot create, roll over or delete contracts.
- **Borrowers (not app users):** receive accurate balances. Their contact is via call, WhatsApp or SMS launched from the app.
- **Downstream:** Firebase project `microfinance-loan-mgr` (Auth, Firestore, Cloud Functions on the Blaze plan).

**Acceptance Criteria:**

*Planning deliverables (Gate 2)*
- [ ] Section 2 gives the Flutter folder architecture, the exact Firestore schema (companies, members, borrowers, contracts, installments, transactions, user_settings), a security-rules outline, the Cloud Functions API, and the full text of the root `CLAUDE.md`.
- [ ] `CLAUDE.md` locks the Stitch tokens and the user overrides: bg #F8F9FA, card #FFFFFF with 1px #E5E7EB borders, primary #1E3A5F, collected #2E7D5B, upcoming #D97706, overdue #C2410C, Plus Jakarta Sans/Inter, radii and spacing. It also requires all tokens to come from `lib/core/theme/app_theme.dart`.

*Auth & companies*
- [ ] A user can sign in with Google (Firebase Auth). On first launch after sign-in they set a 4-digit MPIN, stored only in `flutter_secure_storage` and never in Firestore.
- [ ] On later launches, the app unlocks with the MPIN or with biometrics (if the device supports them and the user has enabled them). After 5 wrong MPIN attempts the app forces a Google re-auth. "Forgot MPIN" re-authenticates with Google and then sets a new MPIN.
- [ ] **Registration creates the company.** A first-time user who signs in and has no company membership and no pending invite sees a "Register your company" step. It asks for the company name (required, 2–80 chars) and the owner's display name and phone, and it creates the company atomically with that user as its **owner**. A user cannot reach the app without a company, either created or joined.
- [ ] **Owner invites staff via SMS / WhatsApp from their own phone.**
  - The owner enters the staff member's name, mobile number and role (owner or collector). The app creates an invite with a unique 6-character code.
  - The owner picks **Send via WhatsApp** or **Send via SMS**. The app opens WhatsApp (`wa.me/<number>`) or the SMS app with a pre-filled message: company name, role, code, and the Play Store link carrying the code as an install referrer / deep-link parameter. Example: "Join *Sri Lakshmi Finance* on Nordic Ledger as Collector. Install: <play link> · Invite code: K7Q2MD". The message goes from the owner's own phone; there is no SMS gateway or server cost. A generic **Share** option and **Copy code** are also available.
  - The staff member installs the app and signs in with Google. Then they enter the code, or it fills in automatically when they open the link with the app already installed. They join the company with the assigned role, and their name and phone are pre-filled from the invite.
  - Each code is single-use, expires after 7 days, and can be resent or revoked. Pending invites are listed under Settings → Members.
- [ ] An owner can change a member's role and remove a member. The last remaining owner cannot be demoted or removed.
- [ ] A user who belongs to several companies (for example, owner of their own company and collector in another) can switch the active company. All screens show only the active company's data.

*Google Play readiness (final step: publish to Play)*
- [ ] **In-app account deletion** (required by Google Play's account-deletion policy). From Settings a user can delete their account:
  - their Auth user and profile data are removed;
  - if they are the sole owner of a company, they must first transfer ownership or delete the company;
  - ledger records they created are kept for the company, with `recordedBy` retained as a uid and display name.
- [ ] A Privacy Policy screen/link and a Terms link appear in Settings and on the sign-in screen. The app shows the app version.
- [ ] The Android release build is Play-ready:
  - applicationId, app icon, splash;
  - release signing via `key.properties`, release SHA-1/SHA-256 registered in Firebase;
  - target SDK meets the current Play requirement;
  - an `.aab` builds, and Google Sign-In works in the release build.
- [ ] The final sprint produces a Play publishing checklist: the store listing positioned as a lender's bookkeeping tool, Data Safety answers, the privacy-policy URL, and an internal-testing track upload.
- [ ] **Company data isolation.** A user, owner or collector, can read and write data only for companies where they have an active membership doc. A collector of Company A cannot see Company B's borrowers, contracts, installments, transactions, members, invites or dashboard totals:
  - not in any list, search, notification or offline cache;
  - not even by guessing a document ID.
  
  Firestore security rules enforce this on every collection path `companies/{companyId}/**`, and it is verified by emulator rules tests. A user who belongs to several companies sees only the **active** company's data at a time. Notifications are scheduled only for companies they belong to.
- [ ] When a member is removed or their invite is revoked, they lose access to that company on their next sync. If it was their active company, the app switches them out. Cached data for that company is cleared from their device.
- [ ] Within their company, a collector cannot create, roll over, edit terms of or delete contracts, and cannot manage members or invites. This is enforced by Firestore security rules (role check on the member doc), not only by hiding UI.

*Borrowers & contracts*
- [ ] An owner can create borrowers (name, phone, locality, notes). One borrower can hold several active contracts at the same time.
- [ ] Creating a contract captures: sanctioned amount, upfront interest as flat ₹ or % of sanctioned, frequency (Daily/Weekly/Monthly), installment amount, preferred weekday (weekly) or day of month (monthly), first collection date, optional guarantor and notes. The app shows Net Cash Handover = sanctioned − upfront and the effective % live. Example: ₹1,00,000, flat ₹7,000 → net ₹93,000, effective 7.0%.
- [ ] Creating a contract generates the full installment schedule atomically:
  - tenor = ceil(sanctioned ÷ installment);
  - the last installment absorbs the remainder (₹1,00,000 at ₹30,000 → 30k, 30k, 30k, 10k);
  - monthly dates on the 29th–31st clamp to the month's last day;
  - the maturity date equals the last due date.
- [ ] Validation rejects: sanctioned ≤ 0; upfront < 0 or ≥ sanctioned; % > 100; installment ≤ 0 or > sanctioned; missing preferred day or date for weekly/monthly.

*Payments*
- [ ] Recording a payment (amount, date, mode UPI/Cash/Bank, optional reference and note) **works offline**. It is one atomic Firestore WriteBatch that:
  - appends one immutable transaction doc (client-generated ID, `recordedBy`, `recordedAt`, `deviceId`);
  - increments the contract's `totalPaid` with `FieldValue.increment`.
  
  Installment paid amounts and statuses are derived by applying all of the contract's payments oldest-first (FIFO), partially paying the last one touched. Balances never drift, even when two collectors record payments offline at the same time.
- [ ] Advance payments beyond the current due are allowed. On the device, amounts above the contract's known outstanding balance are rejected. If payments recorded on separate offline devices push the total over the sanctioned amount after sync, the contract is flagged **Excess collected ₹X** for owner review. Nothing is silently dropped.
- [ ] While offline, the app shows a clear "Offline: changes will sync" indicator and a pending-sync count. Queued writes survive an app restart.
- [ ] When the outstanding balance reaches ₹0, the contract automatically becomes `closed`.

*Overdue & reschedule*
- [ ] An installment that is unpaid (or partly paid) with a due date before today shows as Missed/Overdue with days overdue (today − dueDate). This is derived at read time, with no scheduler needed.
- [ ] The Overdue Tracker lists all overdue installments of the active company with total overdue ₹, loan count, highest delay, and filters Critical (>3 days) and Recent (1–3 days). Each item has Call, WhatsApp and Record (Pay Now).
- [ ] **Automatic schedule recalculation for missed and partial payments.** Once an installment's due date has ended (after 23:59 IST that day) and it is not fully paid, the app does two things:
  1. The installment **stays visible as Overdue / Partially paid**, showing the shortfall ₹ and days late. It keeps appearing in the Overdue Tracker, dashboard Total Overdue and the overdue notification.
  2. The schedule is **auto-extended at the end**. The total shortfall of all past-due installments is appended after the last regular due date as new installments at the contract's frequency and preferred day/date, in chunks of the regular installment amount with any remainder last.
     - Example: ₹10,000 weekly, pays ₹6,000 → a ₹4,000 installment is added one week after the current final date.
     - Example: misses two full weeks → two ₹10,000 installments are added.
     
     Maturity date and tenor ("cycles n/N") update to match.
- [ ] **Late payments shrink the extension automatically.** Payments are applied oldest-first, so a late payment clears the overdue shortfall first, and the matching extension installments disappear or shrink.
  - Example: the ₹4,000 is paid in the next week → the extra end installment is removed.
- [ ] The extension is **computed, not stored**: the schedule is base installments + derived extension, recalculated on the device from the payment log and today's IST date. It works offline, needs no scheduler, and cannot drift or conflict when two devices sync.
  - Extension rows are labelled "Added · missed/partial on {date}" in the contract timeline and calendar.
  - Notifications are scheduled for them like any other installment.
  - Totals never double-count: Sanctioned Receivable = sanctioned − paid. Extension rows re-plan the same overdue money; they are not new debt.
- [ ] **Manual reschedule is still available** to the owner and collector as an override. It moves a specific overdue installment's unpaid amount to a chosen date. Rescheduled amounts are excluded from the auto-extension, so nothing is counted twice. The original installment is kept, marked `rescheduled` and linked to its target, and the action is logged with `recordedBy`.

*Rollover*
- [ ] An owner can roll over an active contract. The old contract's outstanding balance is settled and the old contract is closed with status `rolledOver`. A new contract is created with new sanctioned amount, fresh upfront interest and new terms, and its schedule is generated. Net cash handed over = new sanctioned − new upfront − old outstanding (it may be ₹0, and the app blocks a negative value). All of this happens in one atomic WriteBatch, which works offline.
- [ ] The two contracts link both ways (`rolledOverFromContractId` / `rolledOverToContractId`), the settlement is recorded as a `rolloverSettlement` transaction, and the old contract's full history stays readable.

*Collection notifications (per schedule)*
- [ ] The app schedules **local notifications on the device** (flutter_local_notifications + timezone, Asia/Kolkata) from the active company's installment schedule. They need no server or internet. Three kinds:
  - **Daily collection digest** at a user-set time (default 08:00): "5 collections due today · ₹42,500". Tapping opens Dashboard → Due Today.
  - **Per-installment reminder** at the user-set time on the due date (optional, off by default): "Suresh Verma · Loan #04 · ₹3,500 due today". Tapping opens that contract's Record Payment sheet.
  - **Overdue nudge** at the digest time, when overdue items exist: "3 overdue · ₹25,500 · highest 5 days". Tapping opens the Overdue Tracker.
- [ ] Notifications are rescheduled whenever the schedule changes: a contract is created, a payment is recorded, an installment is rescheduled or carried forward, a rollover happens, the company is switched, data syncs from other devices, or the app starts. A fully paid installment never triggers a reminder. Because Android limits pending alarms, at most the next 14 days are scheduled at any time.
- [ ] Settings → Notifications lets each user turn each kind on or off and set the time. These preferences are stored in `user_settings`.
- [ ] On Android 13+ the app asks for POST_NOTIFICATIONS permission at first use and keeps working if it's denied. It uses inexact alarms (no SCHEDULE_EXACT_ALARM, which Play restricts). Notifications survive a device reboot.

*Dashboard, calendar, borrower profile*
- [ ] The dashboard shows four metrics for the active company:
  - Total Net Disbursed (Σ net disbursed);
  - Total Sanctioned Receivable (Σ outstanding of active contracts);
  - Total Collected (Σ payments);
  - Total Overdue (Σ outstanding of overdue installments).
  
  It also shows Today's Due (total, received today, progress) and a Due Today list with All/Pending/Collected filters.
- [ ] The calendar shows a month grid with status dots per day (collected, upcoming, overdue), legend totals, and a list for the selected day with Record and Call.
- [ ] The borrower list is searchable by name or phone. The borrower profile shows Active Exposure, Lifetime Lent and Collected, Active/Closed contract tabs (each with sanctioned/paid/remaining, cleared %, next due, cycles n/N), and recent receipts.
- [ ] The contract detail shows the Sanctioned/Disbursed/Upfront tiles, a principal-cleared bar, the overdue banner, and the installment timeline with All/Missed/Upcoming/Paid filters, plus Collect and Reschedule on overdue rows.
- [ ] Call, WhatsApp and SMS buttons open the dialer, WhatsApp or the SMS app with a pre-filled polite reminder (borrower name, ₹ due, date).

*New Stitch screens (added 2026-11-21 in project 7509627548686012595)*
- [ ] **0. Register Your Company** (screen `cb1122c4566f41ccb6b713271eef0ba6`), shown after first Google sign-in:
  - signed-in account chip with Switch;
  - Company details: name (required), city (optional), business phone (+91);
  - Your profile: display name, mobile (+91);
  - an Owner-rights info card and a "Have an invite code? Join an existing company →" link;
  - sticky "Create company & continue", with a Terms/Privacy note.
  
  Implementation notes:
  - Inputs follow CLAUDE.md (white fill, 1px border), not the mock's tinted fill.
  - The owner-rights copy must read "Create loans, rollovers and manage the ledger". The mock's "daily interest accruals" is wrong for the upfront-interest model.
- [ ] **9. Members & Invite Staff**: an invite form (name, +91 mobile, Collector/Owner segmented), Send via WhatsApp / Send via SMS / Share / Copy code, message preview, pending invites with Resend/Revoke, and a member list with role pills and change-role/remove. The last owner is protected.
- [ ] **00. Splash** (`eea24dd1c2484b52b2aea0f13fc4ea73`):
  - alabaster background, centered 96px navy rounded tile with a white ledger glyph (3 lines + sage dot);
  - "Nordic Ledger" wordmark and the tagline "Calm, accurate lending books";
  - a slim sage progress bar with "Syncing your ledger…".
  
  Implemented with `flutter_native_splash` (static mark on #F8F9FA) and then an in-app splash route while auth, MPIN state and the Firestore cache initialise. The same mark is used as the **Android adaptive launcher icon** (`flutter_launcher_icons`: navy background layer, white glyph foreground).
- [ ] **0b. Join with Invite Code** (`1478643836644e65b3796adc94671420`): signed-in chip, 6-box code entry + paste, an invite preview card (company, invited-by, role pill, permissions with ✓/🔒, expiry), "Join {company}", and "Register a new company instead". Needs internet.
- [ ] **10. Settings** (`98bc6b4703484fc5a0adfde7706c81e0`): profile + role pill, sync status card, Company group (active-company switcher sheet, Members & invites [owner only], Join another, Register new), Collection notifications toggles + time, Security (Change MPIN, fingerprint, auto-lock), About (Privacy, Terms, version), Sign out, and Delete account (terracotta). Copy fixes:
  - no "Local SQLite encrypted" line (we use Firestore offline persistence);
  - per-installment reminders are **device notifications to the user**, not borrower SMS.
- [ ] **6b. Rollover Breakdown** (`db36f4e34ed541d98368e13354e6b4be`), owner only:
  - closing-contract card (Sanctioned / Paid / Outstanding);
  - new-contract inputs (sanctioned + chips, Flat/% toggle, upfront, frequency, installment → cycles, weekday, first date);
  - settlement card: new sanctioned − upfront − old outstanding = **Net cash handover**;
  - schedule preview, and a footer "Confirm rollover · Works offline".
- **Existing screens updated in Stitch (2026-11-21):**
  - **Dashboard:** company switcher + Synced chip in the header, a **2×2 KPI grid** (Net disbursed / Sanctioned receivable / Total collected / Total overdue), overdue in terracotta.
  - **Contract schedule:** terracotta overdue, a **Partially paid** state, **auto-extension rows** "Installment 11/12 · Added" (dashed border) with maturity moved, an explanatory note, and the auto-mandate and hash copy removed.
  - **Record Payment:**
    - "Verified" / UTR check / score / crypto copy removed;
    - chips Full due / Partial / Advance with the "Short amounts are added to the end" helper;
    - an owner-only "Roll over this loan" card;
    - "Send receipt to borrower" via WhatsApp/SMS from the user's phone;
    - "Works offline · syncs automatically" footer.
  - **MPIN:** brand mark, "Lending ledger for your business", company · role line, "Forgot MPIN? Sign in with Google again", and the "Your MPIN stays on this device · Privacy · Terms" footer.

*Dashboard charts (added 2026-11-21)*
- [ ] **Collections chart.** The dashboard has a bar chart, "Collections · last 8 weeks", with an 8W / 6M (/12M on tablet) toggle:
  - Each period shows a wide neutral `#E5E7EB` bar for the **amount due**, with a narrower sage bar inside it, anchored to the baseline, for the **amount collected**. Bars have 4dp rounded tops.
  - There is one y-axis only, in ₹ short Indian format (₹50k, ₹1L, ₹1.5L).
  - The current, incomplete period uses a lighter sage.
  - Tapping (phone) or hovering (tablet) a period shows a tooltip, e.g. "16 Nov week · Due ₹1,50,000 · Collected ₹1,45,000 (97%)", with a crosshair on tablet.
  - The legend reads Collected / Due, with a summary line below: "8-week collection rate 92% · ₹X of ₹Y".
  - "Due" per period = Σ amountDue of installments (including auto-extension rows) whose due date falls in the period. "Collected" = Σ payment transactions whose date falls in the period.
- [ ] **Receivable breakdown.** The dashboard has a "Receivable breakdown" card (₹ total sanctioned receivable). It shows **three separate labelled rows, never a stacked bar**: Collected this month (sage), Upcoming next 30 days (amber), Overdue (terracotta + warning icon). Each row has a ₹ amount, a %, and a thin 6dp bar on a `#F1F3F5` track, plus a "View overdue tracker →" link.
  - **Why rows:** palette validation showed amber `#D97706` vs terracotta `#C2410C` at ΔE 12.7, below the 15 normal-vision floor. The two must never be adjacent unlabeled segments in any chart. Status colors always appear with text labels (and an icon for overdue).
- [ ] **Chart styling.** Charts are built with `fl_chart`, styled only from `app_theme.dart` tokens: 1dp `#F1F3F5` gridlines, 11–12sp Inter `#6B7280` tabular axis labels, ≥ 44dp tap targets per bar. Each chart has an accessible semantics label summarising its values, and the summary line doubles as the text alternative.
- [ ] **Chart layout.** Mobile: both charts stack below the KPI grid, replacing the old recovery-rate bar. Tablet: Collections takes 8 columns and the Receivable breakdown 4 columns. Stitch refs: `2. Executive Dashboard` (`895c6b841da34e6ea907fc8e63352e13`) and **T2. Dashboard (Tablet with Charts)** (`71bb3c8616154c70bfc88147df57332a`), which supersedes `68380b60…`.
- [ ] **Chart data offline.** Chart data comes from the same offline cache (installments + transactions), so it works offline and updates live after a payment.

*Responsive layout: mobile + tablet*
- [ ] The app supports **Android phones and tablets**, portrait and landscape, using width breakpoints in `lib/core/theme/app_breakpoints.dart`:
  - **compact** < 600dp: single column, bottom NavigationBar (Dashboard · Calendar · Borrowers · Settings), 16dp margins.
  - **medium** 600–839dp: NavigationRail, 2-column grids (KPI 2×2), 24dp margins.
  - **expanded** ≥ 840dp: NavigationRail with labels + "+ New loan" FAB in the rail, a 12-column content grid, 32dp margins, max content width 1280dp, and **list-detail split panes** for Borrowers (40/60), Calendar (month grid | day list) and Overdue (list | contract schedule). Record Payment and Rollover open as a centered dialog / side sheet (max 560dp) instead of a full-screen bottom sheet.
- [ ] Reference tablet designs: **T2. Dashboard (Tablet)** (`68380b601259475faa0812e1f572b876`; rail, 4 KPIs in one row, Due today 8 cols + Today's collections/Overdue 4 cols, recovery bar) and **T5. Borrowers (Tablet split view)** (`cb13c4fec99c4152ab07070cbd9d364b`; master list 40% + profile/contracts/receipts detail 60%). Other screens on tablet follow the same rail + grid rules.
- [ ] All screens are built from shared responsive scaffolds (`AdaptiveScaffold`, `ListDetailLayout`), with no per-screen breakpoint maths. Text scales up to 1.3× without overflow, touch targets are ≥ 48dp, and widget tests cover compact and expanded widths for Dashboard and Borrowers.

*UI & formatting*
- [ ] Every currency value uses ₹ with Indian grouping (₹1,00,000; ₹12,34,567). Every amount and date renders with tabular figures.
- [ ] Screens match the 8 Stitch screens in layout, color and typography. No widget contains a hard-coded hex color, font size or radius; everything comes from `app_theme.dart`. Overdue uses terracotta #C2410C, collected sage, upcoming amber, and primary actions slate.
- [ ] **Offline-first:** every screen and action works without internet, using Firestore persistence and queued writes. Only sign-in, accepting an invite and account deletion need a connection, and the app says so plainly.

**Scope:**

In scope:
- Everything in the acceptance criteria above, **Android only**. Publishing to Google Play is the final step.
- Company registration during sign-up (the creator becomes owner), member invites by email or code, role management.
- Offline-first operation with Firestore sync. Play-compliance features: in-app account deletion, privacy/terms links, a release `.aab`.
- A new Firebase project `microfinance-loan-mgr` with Auth (Google), Firestore, Functions and rules, plus Firestore emulator/unit tests for the ledger maths.

Out of scope:
- Credit scores/tiers, UPI payment verification, auto-mandate, batch UPI payment links.
- Server-sent push (FCM) and automatic SMS/WhatsApp to **borrowers**. Borrower reminders are launched by the user only. Collection notifications go to the app user's own device as local notifications.
- Late fees or penalties of any kind (Stitch: "Zero Hidden Penalties"). Interest beyond the upfront deduction.
- PDF/CSV statements and export, web/desktop builds, collector-to-borrower assignment, multi-currency.
- iOS, the App Store and Sign in with Apple.
- Cloud Functions / server-side enforcement. Spark plan only.
- The privacy-policy web page content, and Play Console account creation ($25 one-time). The user does these. The Play checklist and internal-track upload are in scope.
- Subscriptions, paid plans or in-app purchases.
- Hard deletes of financial records. Contracts can only be cancelled by an owner if no payment exists.

**Risks & Dependencies:**
- **Trusted devices:** with no Cloud Functions, ledger maths runs on the device. A tampered APK could write bad amounts within what the rules allow. This was accepted for offline-first. Rules still validate role, field types and amount > 0, and treat transactions as immutable.
- **Offline conflicts:**
  - Two staff offline at the same time can both collect the same installment, and the result appears as "Excess collected" after sync.
  - An owner editing or rolling over a contract while a collector records a payment on it offline is a harder case: the payment can land on a contract already marked `rolledOver`. The design must handle a late payment on a closed contract by flagging it and carrying it into the successor contract.
  - The Tech Lead must specify both cases.
- **Invites need a connection** (reading the invite doc by code). Invite acceptance is online-only.
- **Google Sign-In on Android** needs the debug and release SHA-1/SHA-256 fingerprints registered in Firebase. The FlutterFire CLI is not installed yet.
- **Ledger correctness** (FIFO replay, rollover, reschedule) is the highest-risk logic. It must live in a pure-Dart domain layer with exhaustive unit tests, plus Firestore-emulator rules tests.
- **Money precision:** amounts must be stored as integer paise or whole rupees, never as floating-point.
- **Timezone:** due dates and "today" must use IST (Asia/Kolkata) consistently on both client and server, or overdue day counts will be off by one.
- **Invite flow:** invites are code-based and sent from the owner's phone by WhatsApp or SMS. There is no email matching. Code guessing is limited by 6 characters from a 31-character unambiguous alphabet (~887M combinations), single use, 7-day expiry, and rules that only allow reading an invite by its exact code doc ID (no listing). The Play-referrer auto-fill only works once the app is published to Play; before that, the code is entered by hand.
- **Google Play review:** Play's *Personal Loan* app policy (stricter in India, where it requires an RBI-licensed lender or partner declaration) applies only to apps that *offer loans to users*. Position and declare this app as a **lender's bookkeeping / business ledger tool**. A misclassified listing risks rejection.
- **Play Console:** needs a privacy policy URL and Data Safety form answers (financial info and contacts are stored).
- **Scope size:** this is a full app, so the Scrum Master will need several sprints.
- **Stitch mocks** contain decorative elements (scores, UTR verification, hashing copy) that are out of scope. The UI team must omit them rather than fake them.

---

## 2. Technical Design
> Filled by: Tech Lead

**Tech Stack Detected:**
This is a greenfield repo: no `pubspec.yaml`, `lib/` or source files exist (verified by glob). Only `docs/kani/**` and the new root `CLAUDE.md` exist. Toolchain on the machine: Flutter 3.41.9 / Dart 3.11.5, Node 24.15, Firebase CLI 15.37. The FlutterFire CLI is **not installed** (`dart pub global activate flutterfire_cli` is part of Task 1).

Chosen stack. Versions are pinned to the latest stable when Task 2 runs; caret ranges go in `pubspec.yaml`.

| Concern | Package |
|---|---|
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| Google login | `google_sign_in` (v7 API: `GoogleSignIn.instance.initialize()` / `authenticate()`) |
| State / DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |
| Routing | `go_router` |
| Models | `freezed`, `freezed_annotation`, `json_serializable`, `build_runner` |
| Secure MPIN | `flutter_secure_storage` (Android Keystore-backed) |
| Biometric | `local_auth` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Contact / share | `url_launcher`, `share_plus` |
| Charts | `fl_chart` |
| Formatting | `intl` (en_IN) + custom Indian grouping |
| IDs | `uuid` |
| Connectivity | `connectivity_plus` |
| App info | `package_info_plus` |
| Install-referrer code | `android_play_install_referrer` |
| Splash / icon | `flutter_native_splash`, `flutter_launcher_icons` |
| Fonts | Plus Jakarta Sans + Inter bundled under `assets/fonts/` (OFL) |
| Tests | `flutter_test`, `mocktail`, `fake_cloud_firestore`, `integration_test`; rules: Node `@firebase/rules-unit-testing` + `vitest` in `firebase/` |

**Architecture Decision:**

*1. Shape.* A feature-first Flutter app with three layers per feature (`data/` → `application/` → `presentation/`). A **pure-Dart `lib/domain/`** owns every ledger rule, so the highest-risk logic is testable without Flutter or Firebase. Full rules are in the root `CLAUDE.md`.

```
lib/
├─ main.dart                      # runZonedGuarded → bootstrap()
├─ bootstrap.dart                 # Firebase.initializeApp, Firestore persistence (unlimited), tz init, ProviderScope
├─ app.dart                       # MaterialApp.router, AppTheme.light, en_IN locale
├─ firebase_options.dart          # generated by flutterfire
├─ core/
│  ├─ theme/        app_theme.dart (AppColors, AppSpacing, AppRadii, AppTextStyles, AppTheme), app_breakpoints.dart
│  ├─ money/        money.dart (int paise value type), inr_format.dart (₹1,00,000 / ₹1.5L short)
│  ├─ time/         ist_clock.dart (Clock interface, IstClock, civil-date helpers 'yyyy-MM-dd')
│  ├─ routing/      app_router.dart (guards: signedIn → hasMpin → unlocked → hasActiveCompany), routes.dart
│  ├─ firebase/     firestore_paths.dart, converters.dart (withConverter helpers), batch_writer.dart
│  ├─ sync/         sync_status_provider.dart (hasPendingWrites + connectivity → Synced / N pending / Offline)
│  ├─ errors/       app_failure.dart (sealed: offlineRequired, permissionDenied, validation, notFound, unknown)
│  └─ widgets/      app_card, status_pill, money_text, kpi_tile, segmented_toggle, currency_field, pin_pad,
│                   section_header, empty_state, adaptive_scaffold, list_detail_layout, offline_banner
├─ domain/                        # NO flutter/firebase imports (enforced by a test that greps imports)
│  ├─ models/       company, member, invite, borrower, contract, installment, ledger_transaction, user_settings,
│  │                enums (Role, Frequency, UpfrontMode, ContractStatus, TxType, PaymentMode)
│  └─ ledger/       schedule_generator.dart, contract_projection.dart, rollover_calculator.dart,
│                   portfolio_metrics.dart (dashboard KPIs + chart series), validators.dart
└─ features/
   ├─ splash/       presentation/splash_screen.dart
   ├─ auth/         data/auth_repository.dart, data/mpin_store.dart · application/session_controller.dart,
   │                lock_controller.dart · presentation/mpin_screen, set_mpin_screen
   ├─ onboarding/   register_company_screen, join_with_code_screen · data/company_repository, invite_repository
   ├─ company/      application/active_company_provider, current_role_provider · presentation/company_switcher_sheet,
   │                members_screen
   ├─ dashboard/    presentation/dashboard_screen, widgets/kpi_grid, collections_chart, receivable_breakdown, due_today_list
   ├─ calendar/     presentation/calendar_screen (month grid + day list)
   ├─ borrowers/    data/borrower_repository · presentation/borrowers_screen (list/detail), borrower_form
   ├─ contracts/    data/contract_repository · application/create_contract_controller, reschedule_controller ·
   │                presentation/create_contract_screen, contract_detail_screen, reschedule_sheet
   ├─ payments/     data/payment_repository · application/record_payment_controller · presentation/record_payment_sheet
   ├─ rollover/     application/rollover_controller · presentation/rollover_screen
   ├─ overdue/      presentation/overdue_tracker_screen
   ├─ settings/     presentation/settings_screen, notification_settings, delete_account_flow
   └─ notifications/ application/collection_notification_scheduler.dart
firebase/                          # firebase.json, firestore.rules, firestore.indexes.json, rules tests (package.json)
assets/fonts, assets/brand (logo glyph svg/png for icon + splash)
test/ (mirrors lib/), integration_test/
```

*2. Offline-first data flow.*
- **On company activation**, the app attaches snapshot listeners, all scoped to `companies/{cid}/`:
  - `contracts` where `status == 'active'`;
  - `installments` where `contractActive == true`;
  - `transactions` where `contractActive == true`;
  - `borrowers` (all, not archived);
  - `members`.
  
  Firestore persistence serves these offline.
- **On top of the snapshots:**
  - `domain/ledger` builds a `ContractProjection` per active contract;
  - `portfolio_metrics` folds the projections into the dashboard KPIs, chart series, calendar day buckets and the overdue list.
- **Recalculation triggers:** Riverpod recomputes on any snapshot change, and on a `dayTickerProvider` that fires at IST midnight and on app resume.
- **Closed contracts and their history** load on demand, per borrower or contract.
- **Firestore aggregation queries are not used**, because they don't work offline. The scaling ceiling of this approach is noted under Performance.

*3. Ledger engine: `contract_projection.dart`* (deterministic: inputs contract, installments, transactions, today).
1. **Effective schedule.** Start from base installments, sorted by `(dueDate, seq)`.
   - For each reschedule, subtract `rescheduledOutPaise` from the source and include the `rescheduled` target rows at their chosen dates.
2. **Paid pool.** P = Σ payment + Σ rolloverSettlement − Σ reversal, for this contract.
3. **FIFO allocation.** Allocate P across the effective schedule in order, regardless of date. This makes advance payments work naturally.
   - Each row gets `paid` and a status: `paid` | `partial` | `due` (dueDate == today) | `overdue` (dueDate < today and paid < due) | `upcoming` (≤ 7 days) | `planned`.
   - `daysOverdue` = today − dueDate.
4. **Shortfall.** S = Σ (due − paid) over rows with dueDate < today.
5. **Auto-extension.** If S > 0, the engine appends ⌈S / installmentPaise⌉ virtual rows after the last effective due date, stepping by frequency and preferred weekday/month-day (day 29–31 clamps to month end).
   - Every row except the last is installmentPaise; the last takes the remainder.
   - Each row has `isExtension = true` and a `sourceLabel` ("missed on 15 Oct (Inst. 5)" / "partial on 08 Oct (Inst. 4)"), attributed FIFO to the shortfall rows.
   - They are never stored. When a late payment reduces S, they shrink or disappear.
6. **Totals.**
   - paid = P; outstanding = max(sanctioned − P, 0).
   - excess = max(P − sanctioned, 0). This flags "Excess collected" for double collection on two offline devices, or a late payment that lands on an already rolled-over contract.
   - overdueAmount = S; maxDaysOverdue.
   - nextDue = first row that isn't fully paid.
   - maturityDate = last row's date (extensions included); cyclesTotal = row count.
   - clearedPct = P / sanctioned.

*`schedule_generator.dart`:*
- **Count:** n = ⌈sanctioned / installment⌉, and the last installment absorbs the remainder.
- **Dates:**
  - Daily: firstDue + i days. Sundays are not skipped; holidays are out of scope.
  - Weekly: the preferred weekday, stepping 7 days.
  - Monthly: the preferred month-day, clamped.
- **Validation:** n ≤ 366, which keeps any batch under Firestore's 500-op limit.

*`rollover_calculator.dart`:* netCash = newSanctioned − newUpfront − oldOutstanding. The result must be ≥ 0, otherwise validation fails and the UI explains why.

*4. Write paths.* Each is one atomic **WriteBatch** with client-generated uuid IDs, so it queues offline.

| Use-case | Role | Batch contents |
|---|---|---|
| Register company (online first-run, offline-tolerant) | any signed-in | `companies/{cid}` + `members/{uid}` (owner) + `users/{uid}/memberships/{cid}` + `user_settings/{uid}` (activeCompanyId) |
| Create borrower | owner | `borrowers/{bid}` |
| Create contract | owner | `contracts/{ctid}` (status active, totalPaidPaise 0, loanNo from `companies.nextLoanNo` + `increment(1)`) + N `installments` + `transactions` disbursement (netDisbursed) + company `nextLoanNo` increment |
| Record payment | owner, collector | `transactions` payment + contract `{totalPaidPaise: increment(amt), lastPaymentOn, updatedAt}`, plus `{status:'closed', closedAt}` and installments/transactions `contractActive:false` when the projection's outstanding reaches 0 |
| Reverse payment | owner | `transactions` reversal (refs original) + contract `totalPaidPaise: increment(−amt)` (+ reopen if it was closed) |
| Reschedule (manual) | owner, collector | source installment `{rescheduledOutPaise: increment(x), rescheduledToIds: arrayUnion(id)}` + new installment `{kind:'rescheduled', rescheduledFromId, dueDate, amountDuePaise:x}` + `transactions` reschedule (amount 0, audit only) |
| Rollover | owner | old contract `{status:'rolledOver', rolledOverToContractId, closedAt, totalPaidPaise: increment(outstanding)}` + `transactions` rolloverSettlement on old + new `contracts` (rolledOverFromContractId) + new `installments` + new disbursement tx (netCash) + old rows `contractActive:false` |
| Create invite | owner | `invites/{code}` (6 chars from `23456789ABCDEFGHJKMNPQRSTUVWXYZ`, collision-checked online via `get`) |
| Accept invite (**online only**) | invitee | `runTransaction`: read invite (pending, not expired) → create `members/{uid}` + `users/{uid}/memberships/{cid}` + invite `{status:'accepted', acceptedBy, acceptedAt}` |
| Change role / remove member | owner | member doc update/delete + company `ownerUids` arrayUnion/arrayRemove + delete `users/{x}/memberships/{cid}` |
| Delete account (online) | self | for each membership: block if sole owner, else delete own member doc + membership; delete `user_settings/{uid}`, `users/{uid}`; clear secure storage; `currentUser.delete()` (re-auth with Google first) |

**Known offline concurrency cases.** All are resolved by the projection; the owner sees a flag, and nothing is lost.
- Two collectors record the same installment offline. Both payments survive, and the excess shows as "Excess collected ₹X".
- A payment arrives after a rollover. It lands on the `rolledOver` contract, shows as excess there, and the owner reverses it and re-records it on the successor.
- Two owners create contracts offline at the same time. They may share a `loanNo`. Identity is the doc ID; the UI shows `#22` and appends `·b` if it detects a duplicate number.

*5. Auth and lock.* The app moves through these states: Splash → `authStateChanges`.
- **Signed out:** Google sign-in screen.
- **Signed in, no MPIN on this device:** Set MPIN.
- **Locked:** MPIN pad, with biometric if enabled.
- **No membership:** Register company or join with code.
- **Otherwise:** the shell.

MPIN storage and lockout:
- The MPIN is stored as `sha256(salt + pin + uid)` with a random salt, in `flutter_secure_storage` (`encryptedSharedPreferences: true`). It never goes to Firestore.
- 5 wrong attempts wipes it and forces Google re-auth. "Forgot MPIN" works the same way.
- Auto-lock triggers after N minutes in the background (default 1).

*6. Notifications.* `collection_notification_scheduler` subscribes to the portfolio projection and the user's `user_settings.notifications`. It cancels all and re-schedules only the next 14 days:
- the daily digest at the chosen time;
- per-installment reminders (opt-in);
- the overdue nudge.

It runs on app start, on snapshot changes (debounced 2 s), on company switch and on settings change. It uses `AndroidScheduleMode.inexactAllowWhileIdle` (no exact-alarm permission). Boot persistence comes from the plugin's boot receiver. Payload routes are `/dashboard?tab=today`, `/contracts/{id}/pay` and `/overdue`.

*7. Responsive.*
- `AdaptiveScaffold` picks `NavigationBar` (compact) or `NavigationRail` (medium/expanded).
- `ListDetailLayout(list, detail)` shows a single pane on compact (pushing the detail route) and a 40/60 split on expanded.
- `showAdaptiveSheet()` gives a bottom sheet on compact and a dialog (max 560) on expanded.

**Component Breakdown:**

| Component | Responsibility | Owner (skill) | Depends On |
|-----------|---------------|-------|------------|
| Firebase project & app config | Create `microfinance-loan-mgr`, enable Google Auth, Firestore (asia-south1), register Android app + SHA-1/256, FlutterFire config | `kani-orchestrator:role-ui-team` | none |
| Firestore rules & indexes | `firestore.rules`, `firestore.indexes.json`, emulator rules tests per collection × role | `kani-orchestrator:role-database-admin` | Data models |
| Core foundation | theme tokens, breakpoints, Money/INR formatter, IST clock, Firestore paths/converters, shared widgets, adaptive layouts | `kani-orchestrator:role-ui-team` | none |
| Domain models | freezed models + JSON converters for all collections | `kani-orchestrator:role-ui-team` | Core foundation |
| Ledger engine | schedule generator, contract projection (FIFO/overdue/extension/reschedule/excess), rollover calculator, portfolio metrics | `kani-orchestrator:role-ui-team` | Domain models |
| Auth & lock | Google sign-in, splash/bootstrap, MPIN set/verify/lockout, biometric, auto-lock, router guards | `kani-orchestrator:role-ui-team` | Core foundation, Firebase config |
| Companies & members | register company, join with code, switcher, members & invites (WhatsApp/SMS), role mgmt, removal handling | `kani-orchestrator:role-ui-team` | Auth & lock, Firestore rules |
| Borrowers | list/search/filters, profile aggregates, create/edit | `kani-orchestrator:role-ui-team` | Ledger engine |
| Contracts | create contract, detail timeline (extension rows), manual reschedule | `kani-orchestrator:role-ui-team` | Ledger engine, Borrowers |
| Payments & rollover | record payment sheet (+receipt share), reversal, rollover screen | `kani-orchestrator:role-ui-team` | Contracts |
| Dashboard, calendar, overdue | KPIs, fl_chart charts, due-today, month calendar, overdue tracker, contact launch | `kani-orchestrator:role-ui-team` | Ledger engine, Payments |
| Settings & notifications | settings screen, notification prefs, delete account, sign out, sync status, local notification scheduler | `kani-orchestrator:role-ui-team` | Dashboard |
| Release | launcher icon, native splash, signing, release SHA, `.aab`, Play checklist doc | `kani-orchestrator:role-ui-team` | all |

**API Contracts (if applicable):**
There is no REST API. The client talks to Firestore directly, protected by the security rules below. Repository interfaces (Dart) are the internal contract:

```dart
abstract interface class PaymentRepository {
  /// One WriteBatch; resolves when committed locally (not when synced).
  Future<void> recordPayment(RecordPaymentCommand cmd); // {companyId, contractId, amountPaise>0, paidOn 'yyyy-MM-dd', mode, reference?, note?}
  Future<void> reversePayment({required String companyId, required String transactionId, required String reason}); // owner
}
abstract interface class ContractRepository {
  Stream<List<Contract>> watchActive(String companyId);
  Future<String> createContract(CreateContractCommand cmd);   // returns contractId; validated by domain/ledger/validators.dart
  Future<String> rollover(RolloverCommand cmd);               // returns new contractId
  Future<void> reschedule(RescheduleCommand cmd);             // {installmentId, amountPaise, newDueDate}
}
abstract interface class InviteRepository {
  Future<Invite> create({required String companyId, required String name, required String phoneE164, required Role role}); // online
  Future<InvitePreview> lookup(String code);                  // online; throws AppFailure.offlineRequired / notFound / expired
  Future<void> accept(String code);                           // online transaction
  Future<void> revoke(String code);
}
```

**Data Models (if applicable):**
Conventions:
- Money is `int` paise.
- Civil dates are `string 'yyyy-MM-dd'` (IST).
- Timestamps are Firestore `Timestamp`.
- Every doc has `schemaVersion: int` (1), plus `createdAt`/`createdBy`, or `recordedAt`/`recordedBy`/`recordedByName`/`clientRecordedAt`/`deviceId` on ledger docs.

Collection: `users/{uid}`
- displayName: string · email: string · photoUrl: string? · phoneE164: string? · createdAt: Timestamp

Collection: `users/{uid}/memberships/{companyId}` (lets a user list their companies without collection-group queries)
- companyId: string · companyName: string · role: 'owner'|'collector' · joinedAt: Timestamp

Collection: `user_settings/{uid}`
- activeCompanyId: string?
- notifications: map `{ digestEnabled: bool (true), digestTime: 'HH:mm' ('08:00'), perInstallmentEnabled: bool (false), overdueNudgeEnabled: bool (true) }`
- autoLockMinutes: int (1) · updatedAt: Timestamp
- *(MPIN hash, salt, biometric flag and lockout counter are **device-local** in secure storage, never in Firestore.)*

Collection: `companies/{companyId}`
- name: string (2–80) · nameLower: string · city: string? · phoneE164: string?
- ownerUids: array<string> — used by rules for owner checks and the last-owner guard
- nextLoanNo: int — display counter, `increment(1)` per contract
- createdBy: string · createdAt: Timestamp

Collection: `companies/{cid}/members/{uid}`
- uid: string · role: 'owner'|'collector' · displayName: string · phoneE164: string? · status: 'active' · inviteCode: string? · invitedBy: string? · joinedAt: Timestamp

Collection: `invites/{code}` (top-level so an invitee who isn't a member yet can `get` it by exact code; `list` is denied)
- companyId: string · companyName: string · companyCity: string? · role: 'owner'|'collector'
- inviteeName: string · inviteePhoneE164: string
- createdBy: string · createdByName: string · createdAt: Timestamp · expiresAt: Timestamp (+7 d)
- status: 'pending'|'accepted'|'revoked' · acceptedBy: string? · acceptedAt: Timestamp?

Collection: `companies/{cid}/borrowers/{borrowerId}`
- name: string · nameLower: string · phoneE164: string · locality: string? · notes: string?
- archived: bool · createdBy: string · createdAt: Timestamp · updatedAt: Timestamp
- *(Exposure, lifetime lent and collected are derived from contracts and projections, not stored.)*

Collection: `companies/{cid}/contracts/{contractId}`
- **Identity:** borrowerId: string · borrowerName: string (denormalized) · borrowerPhoneE164: string · loanNo: int · purpose: string?
- **Lifecycle:** status: 'active'|'closed'|'rolledOver'|'cancelled'
- **Amounts:**
  - sanctionedPaise: int — repayable principal
  - upfrontMode: 'flat'|'percent' · upfrontInput: int (paise if flat, basis points if percent, e.g. 700 = 7.00%)
  - upfrontPaise: int — the amount actually deducted
  - netDisbursedPaise: int — sanctioned − upfront (for a rollover, the cash actually handed over = sanctioned − upfront − settledOldOutstanding)
- **Schedule terms:**
  - frequency: 'daily'|'weekly'|'monthly' · preferredWeekday: int? (1=Mon…7) · preferredMonthDay: int? (1–31)
  - installmentPaise: int · baseInstallmentCount: int
  - firstDueDate: string · disbursedOn: string
- **Optional details:** guarantor: string? · notes: string?
- **Running total:** totalPaidPaise: int — only ever `increment()`; a cache for lists, while the projection is the source of truth
- **Lifecycle dates:** lastPaymentOn: string? · closedAt: Timestamp?
- **Rollover links:** rolledOverFromContractId: string? · rolledOverToContractId: string? · rolloverSettledPaise: int?
- **Audit:** createdBy · createdAt · updatedAt

Collection: `companies/{cid}/installments/{installmentId}` (company-level, so the calendar and overdue views query across contracts)
- contractId · borrowerId · borrowerName · loanNo · contractActive: bool
- seq: int (1..n; rescheduled rows get the next seq)
- kind: 'base'|'rescheduled' · dueDate: string · amountDuePaise: int
- rescheduledOutPaise: int (0) · rescheduledToIds: array<string> · rescheduledFromId: string?
- createdBy · createdAt
- *(No stored paid/status. They are derived. Auto-extension rows are never stored.)*

Collection: `companies/{cid}/transactions/{txId}` (**append-only, immutable**)
- contractId · borrowerId · borrowerName · loanNo · contractActive: bool
- type: 'disbursement'|'payment'|'rolloverSettlement'|'reversal'|'reschedule'
- amountPaise: int (≥ 0; 0 only for reschedule audit) · paidOn: string
- mode: 'upi'|'cash'|'bank'? · reference: string? · note: string?
- reversesTxId: string? · relatedContractId: string? (rollover counterpart) · rescheduleInfo: map?
- recordedBy · recordedByName · recordedAt (serverTimestamp) · clientRecordedAt · deviceId

Indexes (`firestore.indexes.json`):
- installments (contractActive ASC, dueDate ASC)
- installments (contractId ASC, dueDate ASC)
- transactions (contractActive ASC, paidOn DESC)
- transactions (contractId ASC, paidOn DESC)
- transactions (borrowerId ASC, paidOn DESC)
- contracts (status ASC, borrowerId ASC)
- contracts (borrowerId ASC, createdAt DESC)
- borrowers (archived ASC, nameLower ASC)

Security rules outline (`firestore.rules`):
```
function signedIn() { return request.auth != null; }
function member(cid) { return signedIn() && exists(/databases/$(db)/documents/companies/$(cid)/members/$(request.auth.uid)); }
function owner(cid)  { return signedIn() && request.auth.uid in get(/databases/$(db)/documents/companies/$(cid)).data.ownerUids; }
function stampedBy() { return request.resource.data.recordedBy == request.auth.uid
                         && request.resource.data.recordedAt == request.time; }
users/{uid}, user_settings/{uid}: read,write if request.auth.uid == uid
users/{uid}/memberships/{cid}: read if self; create if self && getAfter(members/uid) exists; delete if self || owner(cid)
companies/{cid}: read if member; create if createdBy == uid && ownerUids == [uid] && getAfter(members/uid).role == 'owner';
                 update if owner (nextLoanNo may be incremented by owner only); delete: false
  members/{uid}: read if member; create if owner(cid) || (self && invite path validated via getAfter(invites/code) accepted by self, role matches);
                 update/delete if owner(cid) && !(last owner); delete if self && not last owner
  borrowers/*: read if member; create/update if owner; delete: false
  contracts/*: read if member; create if owner && valid amounts (ints, sanctioned>0, 0<=upfront<sanctioned, net==sanctioned-upfront or rollover);
               update if owner; or collector && diff().affectedKeys().hasOnly(['totalPaidPaise','lastPaymentOn','updatedAt','status','closedAt'])
                                  && status in ['active','closed']; delete: false
  installments/*: read if member; create if owner || (member && kind == 'rescheduled');
                  update if member && affectedKeys hasOnly(['rescheduledOutPaise','rescheduledToIds','contractActive']); delete: false
  transactions/*: read if member; create if member && stampedBy() && amountPaise is int && amountPaise >= 0
                  && (type in ['payment','reschedule'] || owner(cid)); update: only contractActive by member; delete: false
invites/{code}: get if signedIn; list if signedIn && owner(resource.data.companyId) [query must filter companyId == cid; added Sprint 4]; create if owner(companyId) && status=='pending';
                update if owner(companyId) (revoke) || (signedIn && pending && expiresAt > request.time && acceptedBy == uid && status=='accepted')
```

**Non-Functional Requirements:**
- **Security.**
  - Rules enforce tenant isolation and roles as above. Emulator rules tests cover every collection × {owner, collector, other-company member, signed-out} × {read, create, update, delete}.
  - Invite codes are 6 characters from a 31-character alphabet, single use, 7-day expiry, and `get` only (no list).
  - The MPIN is salted, hashed and device-only, with a 5-attempt lockout. The app sets `FLAG_SECURE` on screens showing balances, which blocks screenshots and recents thumbnails.
  - Inputs are validated in `domain/ledger/validators.dart` and again in the rules.
  - Accepted risk: a tampered APK can write arithmetically wrong but schema-valid ledger docs.
- **Error handling.**
  - Repositories map exceptions to `AppFailure`: `permission-denied` → "You don't have access to this company"; `unavailable` on online-only flows → `offlineRequired`.
  - Batches resolve locally, so the UI confirms with a "Saved · will sync" snackbar.
  - The sync status chip shows Synced / N pending / Offline.
  - A removed member is detected when their member doc is missing; the app switches company, calls `clearPersistence()` after `terminate()` on the next cold start, and explains why.
  - Validation errors show inline under the field.
- **Performance.**
  - Target scale per company is ≤ 1,000 active contracts, ≤ 40k open installments and ≤ 100k transactions in the 12-month chart window.
  - Projections are memoized per contract (recomputed only for contracts whose docs changed), and portfolio folding stays under 50 ms on a mid-range phone for 1,000 contracts, verified by a domain benchmark test.
  - Lists use `ListView.builder`.
  - Beyond the target scale, the next step is materialized summaries via Cloud Functions on the Blaze plan. Out of scope.
- **Correction to Section 0:** dashboard totals are computed client-side from the cached snapshot, **not** with Firestore `sum()`/`count()` aggregation queries, because those don't work offline.

**Assignable Tasks:**

| # | Task Name | Owner (skill) | Depends On |
|---|-----------|-------|------------|
| 1 | Provision Firebase: create project `microfinance-loan-mgr`, enable Google sign-in provider, create Firestore (asia-south1, production mode), register Android app `com.nordicledger.app`, add debug SHA-1/SHA-256, install FlutterFire CLI and run `flutterfire configure`; write `firebase/firebase.json` | `kani-orchestrator:role-ui-team` | none |
| 2 | Scaffold Flutter app (`flutter create --org com.nordicledger --platforms android`), add dependencies, analysis_options, bundled fonts, folder skeleton per CLAUDE.md, `bootstrap.dart` with persistence + timezone init, domain-purity import test | `kani-orchestrator:role-ui-team` | Task 1 |
| 3 | Core foundation: `app_theme.dart` tokens + ThemeData, `app_breakpoints.dart`, `Money` + `inr_format.dart` (full + short), `ist_clock.dart`, Firestore paths/converters, shared widgets (AppCard, StatusPill, MoneyText, KpiTile, SegmentedToggle, CurrencyField, PinPad, AdaptiveScaffold, ListDetailLayout, showAdaptiveSheet, OfflineBanner) with golden/widget tests | `kani-orchestrator:role-ui-team` | Task 2 |
| 4 | Domain models (freezed + JSON) for all collections and enums; converters round-trip tests | `kani-orchestrator:role-ui-team` | Task 3 |
| 5 | Ledger engine: `schedule_generator`, `validators`, `contract_projection` (effective schedule, FIFO, statuses, daysOverdue, auto-extension w/ source labels, reschedule handling, excess), `rollover_calculator`, `portfolio_metrics` (4 KPIs, today's due, 8W/6M/12M chart series, receivable breakdown, calendar buckets, overdue list); exhaustive unit tests + benchmark | `kani-orchestrator:role-ui-team` | Task 4 |
| 6 | Firestore security rules + indexes + Node emulator rules test suite (collection × role matrix, invite accept path, last-owner guard, immutability of transactions) | `kani-orchestrator:role-database-admin` | Task 4 |
| 7 | Auth & lock: Google sign-in (v7 API), splash route, set/verify MPIN (salted hash, secure storage, 5-try lockout), biometric unlock, auto-lock on background, go_router guards, MPIN screen per Stitch | `kani-orchestrator:role-ui-team` | Tasks 3, 1 |
| 8 | Companies & onboarding: register company batch, join-with-code (lookup preview + transactional accept, Play install-referrer prefill), memberships list, active company persistence, company switcher sheet, `currentRoleProvider`, removed-member handling | `kani-orchestrator:role-ui-team` | Tasks 5, 6, 7 |
| 9 | Members & invites screen: create invite + WhatsApp/SMS/share/copy message, pending invites resend/revoke, member list change-role/remove with last-owner guard | `kani-orchestrator:role-ui-team` | Task 8 |
| 10 | Borrowers: repository, list/search/filters, borrower form (owner), profile with derived aggregates, Active/Ledger/Closed tabs, recent receipts; tablet list-detail | `kani-orchestrator:role-ui-team` | Task 8 |
| 11 | Contracts: create-contract screen (live net/effective %, frequency/day pickers, schedule preview) + batch; contract detail timeline (paid/partial/overdue/upcoming/extension rows, filters); manual reschedule sheet + batch | `kani-orchestrator:role-ui-team` | Task 10 |
| 12 | Payments & rollover: record-payment adaptive sheet (Full/Partial/Advance, date, mode, reference, note) + batch + auto-close; receipt share via WhatsApp/SMS; owner reversal; rollover screen + batch; excess flag UI | `kani-orchestrator:role-ui-team` | Task 11 |
| 13 | Dashboard: 2×2 / 4-up KPI grid, collections chart (fl_chart, tooltip, 8W/6M/12M), receivable breakdown rows, today's due card + Due Today list with filters; tablet 8/4 layout | `kani-orchestrator:role-ui-team` | Task 12 |
| 14 | Calendar (month grid with status dots + legend totals, day list, Month/List toggle; tablet split) and Overdue tracker (totals, Critical/Recent filters, Call/WhatsApp/Record; tablet split) | `kani-orchestrator:role-ui-team` | Task 12 |
| 15 | Settings: profile, sync status, company group, notification prefs, security (change MPIN, biometric, auto-lock), privacy/terms/version, sign out, delete-account flow; local notification scheduler (digest, per-installment, overdue nudge; 14-day window; deep-link payloads; Android 13 permission) | `kani-orchestrator:role-ui-team` | Tasks 13, 14 |
| 16 | Responsive pass + widget tests at compact/expanded for all shell screens; text-scale 1.3× check | `kani-orchestrator:role-ui-team` | Task 15 |
| 17 | Release & Play readiness: launcher icon + native splash from brand mark, release signing via key.properties, release SHA in Firebase, targetSdk per Play requirement, `flutter build appbundle`, `docs/play-publishing-checklist.md` (bookkeeping positioning, Data Safety answers, account-deletion web URL, internal-testing upload) | `kani-orchestrator:role-ui-team` | Task 16 |

---

## 3. Sprint Plan
> Filled by: Scrum Master

**Sprint Breakdown:**

| Sprint | Tasks (# from Section 2) | Owner(s) | Depends On (Sprint #) | Status | Sprint Goal |
|--------|---------------------------|----------|------------------------|--------|-------------|
| 1 | 1 Provision Firebase · 2 Scaffold Flutter app · 3 Core foundation (theme, money, clock, shared widgets) | `kani-orchestrator:role-ui-team` | none | passed | The app builds and launches on Android connected to Firebase project `microfinance-loan-mgr`, and renders a token-driven theme/widget gallery. `flutter analyze` is clean, and INR-format and widget tests pass. |
| 2 | 4 Domain models · 5 Ledger engine | `kani-orchestrator:role-ui-team` | 1 | passed | Schedule generation, FIFO projection, overdue/partial status, auto-extension, reschedule, rollover maths and portfolio metrics are verifiable through the unit-test suite (pure Dart, no device needed). |
| 3 | 6 Firestore rules + indexes + rules tests · 7 Auth & lock | `kani-orchestrator:role-database-admin`, `kani-orchestrator:role-ui-team` | 1, 2 | passed | Rules tests pass on the emulator for every collection × role. On a device a user can sign in with Google, set an MPIN, unlock with MPIN or fingerprint, hit the 5-try lockout, and auto-lock. |
| 4 | 8 Companies & onboarding · 9 Members & invites | `kani-orchestrator:role-ui-team` | 3 | passed | A new user registers a company and becomes owner. The owner invites a collector via WhatsApp/SMS. The collector joins with the code, sees only that company, and switches companies. Revoke, role change and the last-owner guard work. |
| 5 | 10 Borrowers · 11 Contracts (create, detail timeline, reschedule) | `kani-orchestrator:role-ui-team` | 4 | pending | An owner adds borrowers and creates contracts, including offline, with a correct net-disbursed figure and an auto-generated schedule. The owner views the timeline and reschedules an installment. Data syncs to the second device. |
| 6 | 12 Payments, reversal & rollover | `kani-orchestrator:role-ui-team` | 5 | pending | Full, partial and advance payments update the schedule. A partial or missed installment shows as overdue and auto-extends at the end. A contract closes at ₹0. An owner rolls over a contract with the correct net cash. Excess is flagged after a concurrent offline collection. |
| 7 | 13 Dashboard · 14 Calendar & Overdue tracker | `kani-orchestrator:role-ui-team` | 6 | pending | The dashboard shows the 4 KPIs, the collections chart and the receivable breakdown matching the recorded data. The calendar dots and day lists are correct, and the overdue tracker filters and Call/WhatsApp/Record actions work. |
| 8 | 15 Settings & notifications · 16 Responsive pass | `kani-orchestrator:role-ui-team` | 7 | pending | Settings works end to end (notification prefs, MPIN change, sign out, delete account). Digest, overdue and per-installment local notifications fire and deep-link correctly. Every screen adapts correctly on phone and tablet widths. |
| 9 | 17 Release & Play readiness | `kani-orchestrator:role-ui-team` | 8 | pending | A signed release `.aab` builds with the launcher icon and splash, Google sign-in works in the release build, and the Play publishing checklist is ready for internal-testing upload. |

**Total sprints:** 9

**Testing Strategy:** per-sprint

**Chunking notes:**
- Ledger maths (Sprint 2) and security rules (Sprint 3) sit on their own ahead of any feature UI. They are the highest-risk logic, they are fully verifiable through automated tests alone, and every later sprint builds on them.
- Feature sprints pair each data path with its screen, so a human can exercise a real flow on a device at the end of every sprint.
- Release is isolated last, matching the user's "publish to Play is the last step".

---

## 4. Implementation Log
> Filled by: Team Members + Module Lead, one `### Sprint N` subsection appended per sprint — never overwritten

### Sprint 1
**Sprint Goal:** The app builds and launches on Android connected to Firebase project `microfinance-loan-mgr`, and renders a token-driven theme/widget gallery. `flutter analyze` is clean, and INR-format and widget tests pass.

**kani-orchestrator:role-ui-team — Task 1 Provision Firebase:**

Files created/modified:
- `firebase/firebase.json` — Firestore config (rules + indexes in same folder) and emulators: auth 9099, firestore 8080, UI enabled, singleProjectMode
- `firebase/.firebaserc` — default project `microfinance-loan-mgr`
- `firebase/firestore.rules` — placeholder, rules_version '2', denies all reads/writes (not deployed)
- `firebase/firestore.indexes.json` — `{"indexes":[],"fieldOverrides":[]}`

Key decisions:
- Final project ID: `microfinance-loan-mgr` (exact ID was available), project number 38863526262, display name "MicroFinance Loan Manager".
- Firestore `(default)` database created in Native mode, `asia-south1`, Standard edition, free tier. The CLI `firestore:databases:create` returned 403 (API not enabled); the MCP `firestore_create_database` tool succeeded. No rules were deployed, so the server-side rules stay at the production-mode default (deny all) until Sprint 3.
- Android app registered: package `com.nordicledger.app`, nickname "Nordic Ledger Android", app ID `1:38863526262:android:a5c3b6338f4ccf9a76c257`.
- Debug keystore SHA-1 `15:38:D7:58:B0:48:60:D9:F0:D8:75:50:F2:21:86:5D:2E:47:49:0B` and SHA-256 `F9:9A:AD:9A:3F:96:07:20:41:62:FB:96:55:BA:45:CB:F5:C0:41:40:9D:EB:25:62:E7:AD:C4:DD:28:01:44:5B` both added to the Android app.
- FlutterFire CLI 1.5.0 installed. Its executable is at `%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat`, which is NOT on PATH. Task 2 must run it from that path or add that folder to PATH. Command for Task 2, run from the Flutter project root:
  `flutterfire configure --project=microfinance-loan-mgr --platforms=android --android-package-name=com.nordicledger.app --out=lib/firebase_options.dart --yes`
  This reuses the existing Android app and writes `android/app/google-services.json`.

Known limitations:
- **Google sign-in provider is NOT enabled.** The MCP and CLI can't enable it, because it needs the console-created OAuth web client. Manual steps: Firebase Console → project `microfinance-loan-mgr` → Build → Authentication → Get started → Sign-in method → Google → Enable → choose a project support email → Save. Afterwards, re-download `google-services.json` (or re-run `flutterfire configure`) so it includes the OAuth client entries.
- Release SHA-1/SHA-256 are not added yet; that is the release sprint's job.

**kani-orchestrator:role-ui-team — Task 2 Scaffold Flutter app:**

Files created/modified:
- `pubspec.yaml` / `pubspec.lock` — project `nordic_ledger`; all deps; `assets/brand/` + font families `PlusJakartaSans`, `Inter`
- `analysis_options.yaml` — flutter_lints + strict-casts/inference/raw-types; excludes `**/*.g.dart`, `**/*.freezed.dart`, `build/**`
- `.gitignore` — Flutter default + `android/key.properties`, `*.jks`, `*.keystore`, `.env`, `firebase/*-debug.log`, `firebase/.firebase/`
- `android/app/build.gradle.kts` — namespace/applicationId `com.nordicledger.app`, `minSdk = maxOf(flutter.minSdkVersion, 23)` (resolves to 24), core library desugaring + `desugar_jdk_libs:2.1.5`, Kotlin `compilerOptions { jvmTarget = JVM_17 }`, google-services plugin
- `android/settings.gradle.kts` — google-services plugin 4.4.4 (FlutterFire), Kotlin Android plugin bumped 2.2.20 → 2.3.21
- `android/app/src/main/kotlin/com/nordicledger/app/MainActivity.kt` — moved from `com/nordicledger/nordic_ledger/`
- `android/app/src/main/AndroidManifest.xml` — label "Nordic Ledger"
- `android/app/google-services.json` — generated by FlutterFire (oauth_client is `[]`)
- `firebase.json` (repo root) — FlutterFire CLI's config record. It is separate from `firebase/firebase.json`; keep it so `flutterfire configure` can re-run.
- `lib/firebase_options.dart` — generated by FlutterFire (android only)
- `lib/main.dart` — `runZonedGuarded(bootstrap, …)`, logs uncaught errors via `dart:developer`
- `lib/bootstrap.dart` — binding, Firebase init, Firestore persistence (unlimited cache), tz init + `Asia/Kolkata`, `Intl.defaultLocale = 'en_IN'`, `runApp(ProviderScope(child: App()))`
- `lib/app.dart` — minimal `MaterialApp` "Nordic Ledger" + `FirebaseStatusPlaceholder` ("Nordic Ledger: Firebase connected: <projectId>"); Task 3 replaces it
- `lib/core/{theme,money,time,routing,firebase,sync,errors,widgets}/.gitkeep`, `lib/domain/{models,ledger}/.gitkeep`, `lib/features/<13 features>/{data,application,presentation}/.gitkeep` — folder skeleton
- `assets/fonts/plus_jakarta_sans/{PlusJakartaSans-Variable.ttf,OFL.txt}`, `assets/fonts/inter/{Inter-Variable.ttf,OFL.txt}`, `assets/brand/.gitkeep`
- `test/architecture/domain_purity_test.dart` — fails on `package:flutter/`, `package:cloud_firestore`, `package:firebase_` or `dart:ui` imports/exports/parts under `lib/domain/` (checked with a temporary violating file)
- `test/app_placeholder_test.dart` — widget test for the placeholder text (replaces the default `widget_test.dart`)

Key decisions:
- **Codegen toolchain is constrained by Flutter 3.41.9 pinning `meta 1.17.0`.** analyzer ≥10 needs meta ^1.18, and riverpod_annotation ≥4.0.5 / riverpod_lint ≥3.1.6 need Dart ≥3.12. Resolved set: analyzer 9.0.0, build_runner ^2.15.1, freezed ^3.2.5, freezed_annotation ^3.1.0, json_serializable ^6.13.0, json_annotation ^4.11.0, riverpod_generator ^4.0.3, riverpod_annotation ^4.0.2, flutter_riverpod ^3.3.1 (riverpod 3.2.1).
- Other key versions: firebase_core ^5.1.0, firebase_auth ^7.0.1, cloud_firestore ^7.1.0, google_sign_in ^7.2.0 (v7 API: `GoogleSignIn.instance.initialize()/authenticate()`), go_router ^17.5.0, flutter_secure_storage ^11.2.0, local_auth ^3.0.2, flutter_local_notifications ^22.3.3, timezone ^0.11.2, flutter_timezone ^5.1.1, url_launcher ^6.3.3, share_plus ^13.3.1, fl_chart ^1.3.1, intl ^0.20.3, uuid ^4.6.0, connectivity_plus ^7.3.2, package_info_plus ^10.2.2; dev: fake_cloud_firestore ^4.5.0, mocktail ^1.0.5, flutter_native_splash ^2.4.7, flutter_launcher_icons ^0.14.4, flutter_lints ^6.0.0.
- **Kotlin 2.3.21:** firebase-auth 25.0.0 (pulled in by firebase_auth 7) ships Kotlin 2.4 metadata, and the template's Kotlin 2.2.20 fails with "incompatible version of Kotlin". Kotlin 2.3 rejects `kotlinOptions.jvmTarget`, so it moved to the `kotlin { compilerOptions }` DSL.
- **Fonts are variable TTFs.** google/fonts `ofl/plusjakartasans` and `ofl/inter` ship no static files, only `[wght]` / `[opsz,wght]` variable fonts. Each family is declared with one asset. **Task 3:** alongside `fontWeight`, set `fontVariations: [FontVariation('wght', 600)]` etc. in `AppTextStyles` so weights render reliably on the variable axis.
- Debug keystore already existed, so no new debug SHA was needed; Task 1's SHAs apply.
- `FirebaseStatusPlaceholder` takes `projectId` as a parameter, so it is widget-testable without Firebase. `App` passes `Firebase.app().options.projectId`.

Known limitations:
- **riverpod_lint and custom_lint are NOT added.** No riverpod_lint version resolves with Dart 3.11.5 / meta 1.17 alongside freezed_annotation 3 and riverpod_annotation 4. Revisit when Flutter ships Dart ≥3.12.
- `google-services.json` has `oauth_client: []` because Google sign-in is not yet enabled in the console (manual step from Task 1). After enabling it, re-run the `flutterfire configure` command.
- The app has not been launched on a device or emulator; only `flutter build apk --debug` was verified.
- Release signing is still the template's debug signing (release sprint).


**kani-orchestrator:role-ui-team — Task 3 Core foundation:**

Files created/modified:
- `lib/core/theme/app_theme.dart` — `AppColors` (all CLAUDE.md hex tokens + `sheetShadow`, `transparent`, `onPrimary`), `AppSpacing`, `AppInsets`, `AppSizes`, `AppRadii`, `AppTextStyles` (base + `*Tabular` variants, `labelMdStrong`, `labelLg`, `bodySm`, `currencyPrefix`), `AppTheme.light` (M3 ThemeData with all component themes)
- `lib/core/theme/app_breakpoints.dart` — `enum WindowSize {compact, medium, expanded}` + `of(context)`, `fromWidth`, `margin` (16/24/32), `tileColumns`, `maxContentWidth` 1280
- `lib/core/money/money.dart` — immutable `Money(int paise)`: `fromRupees`, `+ - * unary-`, comparisons, `compareTo`, `isZero/isNegative/isPositive`, `percentOf` (basis points int), `sum/min/max`. Pure Dart (domain-safe)
- `lib/core/money/inr_format.dart` — `formatInr`, `formatInrPlain`, `formatInrShort`, `parseInrInput`, `groupIndianDigits` (hand-rolled grouping, U+2212 minus, no intl)
- `lib/core/time/ist_clock.dart` — `Clock` interface, `IstClock` (timezone Asia/Kolkata, self-initialises the tz DB if needed), `FixedClock`, `CivilDate` value type, `formatCivilDate` ("24 Oct 2023"), `formatCivilDateWithWeekday` ("Tue, 24 Oct")
- `lib/core/time/clock_provider.dart` (+ generated `.g.dart`) — `@Riverpod(keepAlive: true) clockProvider`
- `lib/core/firebase/firestore_paths.dart` — `FirestorePaths` static builders for every collection/doc path in the schema
- `lib/core/errors/app_failure.dart` — sealed `AppFailure` (offlineRequired, permissionDenied, validation, notFound, expired, unknown) with `userMessage`, plus `mapFirebaseException`
- `lib/core/widgets/{app_card,status_pill,money_text,kpi_tile,segmented_toggle,currency_field,pin_pad,section_header,empty_state,offline_banner,adaptive_scaffold,list_detail_layout,adaptive_sheet}.dart` — shared widgets (token-only); `StatusKind` enum lives in `status_pill.dart`; `IndianGroupingFormatter` in `currency_field.dart`
- `lib/features/splash/presentation/theme_gallery_screen.dart` — temporary Theme gallery inside `AdaptiveScaffold` (Dashboard · Calendar · Borrowers · Settings)
- `lib/app.dart` — `AppTheme.light`, locale `en_IN`, `GlobalMaterialLocalizations.delegates`, home = gallery (`FirebaseStatusPlaceholder` removed)
- `pubspec.yaml` — added `flutter_localizations` (sdk); `intl` constraint `^0.20.3` → `^0.20.2`
- `test/core/money/inr_format_test.dart`, `test/core/time/civil_date_test.dart`, `test/core/theme/theme_tokens_test.dart`, `test/core/widgets/{money_text,status_pill,pin_pad,currency_field,adaptive_scaffold}_test.dart`, `test/features/splash/theme_gallery_screen_test.dart`, `test/architecture/no_hardcoded_style_test.dart`, `test/helpers/pump_app.dart` — new tests; `test/app_placeholder_test.dart` deleted (placeholder gone)

Key decisions:
- **intl downgraded to ^0.20.2.** The Flutter 3.41.9 SDK pins intl 0.20.2 through `flutter_localizations`. Without the delegates, Material date pickers fall back to US date order, so en_IN localizations are worth the patch-level step down. The resolved intl version is 0.20.2.
- Date formatters are hand-rolled with English month and weekday names, not `DateFormat`. They are deterministic and need no `initializeDateFormatting` call. en_IN uses the same abbreviations.
- `CivilDate.addMonthsClamped(int months, {int? preferredDay})`: the target day is `preferredDay ?? day`, clamped to the length of the month. Schedules pass the anchor day, so 31 Jan → 28 Feb → 31 Mar. `a.daysBetween(b)` returns `b − a`. `CivilDate` lives in `ist_clock.dart` and is pure Dart.
- `Money.percentOf` truncates toward zero and returns 0 when the total is 0.
- `formatInrShort` rounds half up to one decimal and promotes the unit when rounding reaches 100 (for example ₹99,999 → ₹1L, not ₹100k). Crore values above 1,000 get Indian grouping.
- `parseInrInput` accepts plain digits, valid Indian grouping or valid Western grouping, an optional leading ₹, and at most 2 decimals; "1234." is allowed. It rejects negatives, misplaced commas, ".5" and more than 13 rupee digits.
- Component dimensions (48 button, 56 input, 64 PIN key, 28 pill, 560 dialog, etc.) and insets are tokens in `AppSizes`/`AppInsets`. Widgets use only these tokens and contain no numeric styling literals.
- `PinPad` clears itself immediately after `onCompleted`, so the caller decides what feedback to show (error or navigation). Keys carry `ValueKey('pin_key_N')`, `pin_backspace` and `pin_biometric` for tests. Each key has a semantic label and the dots use a live region; the PIN itself is never announced.
- `OfflineBanner` text uses textPrimary on the amber tint, because amber on amber tint has about 2.9:1 contrast. The amber icon carries the status colour.
- `AdaptiveScaffold` shows the FAB only on expanded (in the rail's leading slot). Medium uses a rail with no labels. `applyMargins: false` lets list-detail bodies manage their own padding. `ListDetailLayout` shows a single pane (`detail ?? list`) on compact and medium.
- `mapFirebaseException` never surfaces raw Firebase messages; validation failures get a fixed sentence.
- The hard-coded-style guard uses a lookbehind, so `AppColors.` is not flagged as `Colors.`.

Known limitations:
- The gallery has not been run on a device or emulator; it is verified by widget tests only, at widths 400, 700 and 1200.
- No golden tests yet (widget tests only), because bundled variable fonts render as the test font in `flutter test`.
- Firestore converters (named in the Section 2 Task 3 row) are not included: only path builders are. Converters belong with the freezed models in Task 4.

**Orchestrator note:** after the user enabled the Google provider in the console (2026-11-21), `flutterfire configure` was re-run. `android/app/google-services.json` now contains an Android OAuth client (type 1) and a web client (type 3, the `serverClientId` for google_sign_in v7).

**Module Lead — Sprint 1 Review (attempt 1):**
Date: 2026-11-21

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- Independently re-ran the checks: `flutter analyze` reports no issues, and `flutter test` passes 108/108.
- **Styling.** A grep over `lib/` outside `core/theme/` finds no `Color(0x…)`, no `fontSize:` and no `Colors.*`. All widget styling goes through `AppColors`/tokens.
- **Money.** `inr_format.dart` reviewed: the Indian grouping, the U+2212 minus sign, half-up short format and strict input regex are correct, and the 13-digit cap keeps `int` paise safe.
- **Secrets.** The only key in source is the public Firebase client config in `firebase_options.dart`, which is expected and not a secret. Signing files are git-ignored.
- **Accepted deviations:**
  1. `intl` constraint lowered to ^0.20.2, because Flutter 3.41.9's `flutter_localizations` pins it. `flutter_localizations` is kept for en_IN Material localizations.
  2. `riverpod_lint` and `custom_lint` were dropped (no version resolves on this SDK), so the riverpod rules are enforced by review instead.
  3. Fonts are the variable TTFs, with `wght` variations set.
  4. Firestore converters move to Task 4, where the models live.
  5. Kotlin was raised to 2.3.21 and core-library desugaring enabled, both required by firebase-auth 25 and flutter_local_notifications.
- **Not yet verified on a device or emulator.** That is part of the human verification for this sprint.

**Tester — Sprint 1 Results (attempt 1):**

Environment: `flutter devices` lists only Windows desktop and Edge web. No Android device or emulator is attached, so the on-device launch was not run (it is a human-verification item, not a failure). Tester added `test/core/sprint1_edge_cases_test.dart` (26 edge/failure tests, test-only; no production code changed).

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | T1: Firebase project wiring (`.firebaserc`, `firebase_options.dart`, `google-services.json`) | happy | All point to `microfinance-loan-mgr`, package `com.nordicledger.app`, OAuth clients type 1 + 3 present | Matches; client types 1 and 3 present | pass |
| 2 | T1: placeholder `firestore.rules` | edge | Denies all reads/writes until Sprint 3 | `allow read, write: if false` placeholder, not deployed | pass |
| 3 | T2: `flutter analyze` | happy | No issues | No issues found | pass |
| 4 | T2: `flutter build apk --debug` | happy | APK builds | `app-debug.apk` built (24s) | pass |
| 5 | T2: domain purity guard (`lib/domain/` has no Flutter/Firebase imports) | failure | Guard test passes on clean tree | Passes | pass |
| 6 | T2: on-device launch shows the gallery connected to Firebase | happy | Launches on Android | Not run, no device attached. Human verification needed | n/a (human) |
| 7 | T3: full suite `flutter test` (108 dev + 26 tester tests) | happy | All pass | 135/135 passed | pass |
| 8 | T3: INR extremes: ₹0, ₹0.01, −₹0.05, ₹1,00,00,000, 13-digit max `₹99,99,99,99,99,999` | edge | Indian grouping, U+2212 minus | As expected | pass |
| 9 | T3: `formatInrShort` promotion boundaries (999, 1k, 99.9k, ₹99,950→1L, ₹99,95,000→1Cr, ₹999.50→1k, negative) | edge | Half-up rounding, unit promoted at 100 | As expected | pass |
| 10 | T3: `parseInrInput` rejects `-100`, `−100`, `.5`, `1.234`, `1,00,000,000`, `10,00`, `1,,000`, `1 000`, `1e5`, 14 digits, bare `₹` | failure | `null` for each | `null` for each | pass |
| 11 | T3: `parseInrInput` accepts ` ₹ 1,00,000 `, `100,000`, `007`, `1234.`, `9999999999999.99` | happy | Correct paise | Correct | pass |
| 12 | T3: `CivilDate.addMonthsClamped`: 31 Jan→29 Feb (leap) / 28 Feb; anchor 31 restores 31 Mar; →30 Apr; Dec→Feb rollover; negative months (−1, −13) | edge | Clamped correctly | As expected | pass |
| 13 | T3: CivilDate leap rules (1900, 2000, 2100) and `tryParse` rejecting `2024-2-01`, `2024-13-01`, `2024-04-31`, ISO with time, empty; `parse('2023-02-30')` throws | failure | Rejected / FormatException | As expected | pass |
| 14 | T3: `daysBetween` across a leap day (sign), `addDays(366)`; `todayIst` at 23:59/00:00; `IstClock` offset +5:30 | edge | Correct | As expected | pass |
| 15 | T3: `IndianGroupingFormatter` live grouping, 2-decimal cap, `.`→`0.`, rejects letters, minus, second dot, 14th digit | edge/failure | Invalid edits keep the old value | As expected | pass |
| 16 | T3: `CurrencyField` initialValue `1,23,456.50`; negative initial ignored; invalid keystroke keeps ₹500; label/error render | edge | As specified | As expected | pass |
| 17 | T3: `PinPad` disabled ignores taps; backspace on empty pad is a no-op; 5th digit doesn't double-fire `onCompleted` | edge/failure | One `'1234'` completion | As expected | pass |
| 18 | T3: `mapFirebaseException` maps codes; raw Firebase messages never surface; unknown → `UnknownFailure`; AppFailure passes through | failure | Friendly messages only | As expected | pass |
| 19 | T3: CLAUDE.md tokens vs `AppColors` (bg #F8F9FA, card #FFFFFF, border #E5E7EB, primary #1E3A5F, collected #2E7D5B, upcoming #D97706, overdue #C2410C); no hard-coded styles outside theme | happy | Match; guard passes | Match; `no_hardcoded_style_test` passes | pass |

**Bugs Found:** None.

**Observations (not bugs):**
- `const CivilDate(y, m, d)` does not validate (for example `CivilDate(2023, 2, 30)` is constructible). Use `tryParse`/`parse` at boundaries, and consider an assert in Sprint 2 if the ledger constructs dates directly.
- `parseInrInput('00,000')` parses as ₹0 (a leading-zero group is accepted). Harmless.

**Human verification needed:** launch on an Android device/emulator (`flutter run`), confirm the theme gallery renders with Plus Jakarta Sans/Inter and that Firebase initialises without errors.

**Sprint Test Summary:** 18 passed, 0 failed (1 item, the on-device launch, deferred to human verification). Automated suite: 135 tests, 0 failures.

**kani-orchestrator:role-ui-team — Sprint 1 fix (attempt 2): rail overflow + copy:**

Files created/modified:
- `lib/core/theme/app_breakpoints.dart` — added a height class: `WindowSize.shortHeightMax` (480dp), `isShortHeightValue(double)` and `isShortHeight(BuildContext)`.
- `lib/core/widgets/adaptive_scaffold.dart` — the rail layout chooses the full rail (labels plus FAB) only when the window is expanded and not short. On short heights it uses the compact rail (`labelType.none`, no leading) and moves the FAB to the Scaffold's `floatingActionButton` in the content pane. The rail is wrapped in `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight)` → `IntrinsicHeight`, so it scrolls instead of overflowing. In rail layouts the `appBar` now sits inside the content pane, so the rail runs the full body height from the top.
- `lib/features/splash/presentation/theme_gallery_screen.dart` — the "Sanctioned receivable" caption now reads "Outstanding on active loans".
- `test/core/widgets/adaptive_scaffold_test.dart` — new group at 915×412 logical (dpr 2.625). It checks for no exception, a compact rail with no leading, the FAB present in content, and that all 4 destinations are hit-testable and tappable. It also checks that the rail starts at y=0 and spans the full 412dp, with the AppBar to the right of the rail. A 200dp-tall case confirms the rail scrolls without overflow.
- `test/features/splash/theme_gallery_screen_test.dart` — the gallery at 915×412 has no overflow, all 4 rail destinations are hit-testable, and the new caption is shown.

Key decisions:
- The FAB moves to the content pane instead of becoming `FloatingActionButton.small`. Callers pass the FAB as a widget, so the scaffold cannot resize it, and the Material bottom-right FAB is the standard placement.
- The compact (rail/bar) path is unchanged. The medium rail also gets the scroll wrapper and the app bar in the content pane, for the same placement rule.

Known limitations:
- On the medium and expanded layouts the AppBar now spans only the content pane instead of the full window width. This is intended per the Material layout, but other screens will inherit it.

**On-device verification (orchestrator on the user's emulator, Android 17 / API 37, 2026-11-21):**
- **Attempt 1:** the app launches, connected to `microfinance-loan-mgr`. Tokens, KPI tiles, status pills, Indian ₹ grouping (typing 100000 shows 1,00,000), CurrencyField rejecting `abc-1e5`, and PinPad fill and backspace all verified ✅. **Bug:** the phone-landscape NavigationRail overflowed by 49 px and Settings was clipped. **Copy bug:** the "Principal + upfront interest" caption.
- **Attempt 2 (after the fix):** `flutter analyze` is clean and 139/139 tests pass. In landscape a compact rail shows all 4 destinations with no overflow, the FAB sits in the content pane, the 4-up KPI row renders, and the caption reads "Outstanding on active loans" ✅.
- **Note:** the emulator ran out of storage on reinstall (`INSTALL_FAILED_INSUFFICIENT_STORAGE`). Resolved by uninstalling the previous debug build.

### Sprint 2
**Sprint Goal:** Schedule generation, FIFO projection, overdue/partial status, auto-extension, reschedule, rollover maths and portfolio metrics are verifiable through the unit-test suite (pure Dart, no device needed).

**kani-orchestrator:role-ui-team — Task 4 Domain models:**

Files created/modified:
- `lib/core/time/civil_date.dart` — NEW pure-Dart home of `CivilDate`, the `Clock` interface and `formatCivilDate*` (moved out of ist_clock.dart, not duplicated)
- `lib/core/time/ist_clock.dart` — now holds only `IstClock` (timezone) + `FixedClock`; imports and re-exports `civil_date.dart`, so existing imports are unchanged
- `build.yaml` — NEW; json_serializable `explicit_to_json: true` (nested `NotificationPrefs` serialises as a map)
- `lib/domain/models/enums.dart` — Role, Frequency, UpfrontMode, ContractStatus, InstallmentKind, TxType, PaymentMode, InviteStatus (wire value = Dart `name`)
- `lib/domain/models/json_converters.dart` — `MoneyPaiseConverter`, `CivilDateConverter` (+ nullable variants)
- `lib/domain/models/{app_user,membership,user_settings,company,member,invite,borrower,contract,installment,ledger_transaction}.dart` (+ generated `.freezed.dart`/`.g.dart`) — freezed models, field-for-field with Section 2
- `lib/domain/models/models.dart` — barrel export
- `lib/core/firebase/converters.dart` — `ModelCodec<T>` (Timestamp mapping, serverTimestamp, id injection), `ModelCodecs.*` per collection, `TypedRefs` (typed collection/doc refs built from `FirestorePaths`)
- `test/helpers/model_fixtures.dart` — realistic shared fixtures (₹1,00,000 = 10000000 paise)
- `test/domain/models/models_round_trip_test.dart`, `test/domain/models/json_converters_test.dart` — JSON round trip for every model, body shape, exact enum strings, defaults, `isActive`, `isExpired`
- `test/core/firebase/converters_test.dart` — fake_cloud_firestore write/read of every model, Timestamp storage, serverTimestamp, pending-null fallback, `increment`, typed queries

Key decisions:
- **Money:** Dart fields are `Money` (converter `MoneyPaiseConverter`), and the document keys keep the schema names with the `Paise` suffix via `@JsonKey(name:)`. Dart names drop the suffix: `sanctioned`, `upfront`, `netDisbursed`, `installmentAmount` (installmentPaise), `totalPaid`, `rolloverSettled` (nullable), `amountDue`, `rescheduledOut`, `amount` (amountPaise). `upfrontInput` stays `int`, because it holds paise or basis points depending on the mode.
- **CivilDate:** Dart fields are `CivilDate` (`CivilDateConverter`, stored as `'yyyy-MM-dd'`); `lastPaymentOn` is nullable. A malformed or impossible date throws `FormatException` on read.
- **Timestamps:** the domain uses `DateTime`, which is ISO-8601 in the domain JSON. The data layer converts to and from Firestore `Timestamp` using a per-model `timestampFields` set, and reads normalise to **UTC** `DateTime`. Tests use `DateTime.utc` so that equality holds.
- **Server timestamps:** `transactions.recordedAt` and `user_settings.updatedAt` are always written as `FieldValue.serverTimestamp()` (the rules require `recordedAt == request.time`). Both are nullable in the model, so a pending cached read gives `null`; `LedgerTransaction.effectiveRecordedAt` falls back to `clientRecordedAt`. Every other timestamp is written from the model value (client-stamped).
- `id` is `@JsonKey(includeToJson: false)` on every doc model and is injected from `snapshot.id` on read. Membership (`id == companyId`) and Member (`id == uid`) still store the body field the schema lists.
- Defaults applied on read when a key is missing: `schemaVersion` 1, Contract `status` active and `totalPaid` 0, Installment `kind` base, `rescheduledOut` 0 and `rescheduledToIds` [], `contractActive` true, Member `status` 'active', Borrower `archived` false, Invite `status` pending, Company `nextLoanNo` 1.
- Extra helpers beyond the brief: `Invite.validity` (7 d), `Invite.isAcceptable(now)` and `LedgerTransaction.effectiveRecordedAt`. Repositories can use `enum.name` in queries.

Known limitations:
- An unknown enum string on read throws (no `unknownEnumValue` fallback). This is deliberate for schema v1.
- `rescheduleInfo` is an untyped `Map<String, dynamic>?`, because Section 2 does not define its shape, and Timestamps nested inside maps are not converted.
- `ModelCodec.timestampFields` lists are maintained by hand next to the models. Converter tests cover every model, so drift shows up as a test failure.

**kani-orchestrator:role-ui-team — Task 5 Ledger engine:**

Files created/modified:
- `lib/domain/ledger/upfront.dart` — `computeUpfront` (percent = sanctioned × bps / 10000, half-up), `computeNetDisbursed`, `effectiveBps`
- `lib/domain/ledger/validators.dart` — `ValidationError`, `LedgerFields`, `validateContractTerms`, `validatePaymentAmount`
- `lib/domain/ledger/schedule_generator.dart` — `SchedulePrefs`, `PlannedInstallment`, `installmentCount`, shared `nextDueDate` stepper, `firstDueOnOrAfter`, `generateSchedule` (≤ 366 rows)
- `lib/domain/ledger/contract_projection.dart` — `RowStatus`, `ProjectedRow`, `ExtensionSource`, `ContractProjection`, `paidPool`, `projectContract` (effective schedule, FIFO, statuses, shortfall, auto-extension with source labels, totals)
- `lib/domain/ledger/rollover_calculator.dart` — `RolloverQuote`, `computeRollover`
- `lib/domain/ledger/portfolio_metrics.dart` — `computePortfolio` → `PortfolioMetrics` (4 KPIs, `todayDue`, `receivableBreakdown`, `overdueList`, `collectionsSeries(ChartPeriod)`, `calendarBuckets(year, month)`), `mondayOf`
- `lib/domain/ledger/ledger.dart` — barrel export
- `lib/core/time/civil_date.dart` — added `formatCivilDateDayMonth` ("8 Oct") and `civilMonthShortName` (locale-free, for labels)
- `test/domain/ledger/ledger_fixtures.dart` — contract/installment/transaction builders
- `test/domain/ledger/{upfront_validators,schedule_generator,contract_projection,rollover_calculator,portfolio_metrics,benchmark}_test.dart` — 97 tests; 100% line coverage of `lib/domain/ledger/` (464/464); benchmark about 55–65 ms for 1,000 contracts

Key decisions:
- **Extension attribution.** A late payment is allocated FIFO, so it clears the earliest shortfall first, and a smaller S shrinks the last extension row first. Shortfall sources are therefore laid across the extension rows latest-first: the tail rows carry the earliest shortfalls. This reproduces Stitch (Inst. 11 = missed Inst. 5, Inst. 12 = partial Inst. 4), and labels stay stable as late payments arrive. When one extension row spans several sources, its label joins them chronologically with " + ", and `ProjectedRow.sources` holds the exact split.
- **Extension dates.** Extensions start at `nextDueDate(lastEffectiveDue)`, the first anchor date strictly after the last non-zero row. They are then rolled forward by whole frequency steps until they are ≥ today, so an extension is never overdue, even when the whole base schedule is in the past. Status is `dueToday`, `upcoming` or `planned`; `paid` is always 0.
- **Label format.** The label uses "d MMM" without a leading zero ("missed on 8 Oct (Inst. 4)"), per the task brief. The Section 2 example shows "08 Oct".
- **Status precedence:** `rescheduled` (effective due ≤ 0) > `paid` > `overdue` (date < today) > `dueToday` > `upcoming` (1–7 days ahead) > `planned`. `isPartial` is set on any not-fully-paid row with 0 < paid < due, including an advance partial on a future row. `daysOverdue` is set only on overdue rows.
- **Rescheduled rows.** Effective due = max(amountDue − rescheduledOut, 0). A 0-due row stays in `rows` with status `rescheduled` and is excluded from allocation, shortfall, cycles, nextDue and maturity.
- **Paid pool.** P is not clamped (a reversal-heavy data error shows a negative `totalPaid`), but only max(P, 0) is allocated. Reversals subtract regardless of their target. Installments and transactions from other contracts are filtered out.
- **Excess.** Excess = max(P − sanctioned, 0) for every status. A payment on a `rolledOver` contract therefore shows as excess, because the settlement already covers the outstanding. `clearedBps` is truncated and capped at 10000.
- **Seq numbering.** Extension seq starts at max(stored seq) + 1, so rescheduled rows and extensions never collide.
- **Schedule anchors.** In `generateSchedule`, a missing preferredWeekday or preferredMonthDay defaults to the firstDueDate's own weekday or day, so the first due is the firstDueDate itself. `nextDueDate` always returns the first anchor date strictly after its input, so the same stepper serves both the base schedule and extensions after an off-anchor rescheduled date.
- **Rounding.** Percent upfront and `effectiveBps` both round half-up. The validator rejects an upfront that rounds up to the full sanctioned amount.
- **totalNetDisbursed** = Σ netDisbursed over every contract in `contractsById`: active, closed and rolled over. It is a lifetime "cash lent" figure for the loaded book. A rollover's netDisbursed is already net of the settled old outstanding, so nothing is double counted.
- **totalCollected, receivedToday, collectedThisMonth, the chart's collected series and the calendar's collected** all count payments − reversals by `paidOn`. A `rolloverSettlement` is excluded because no cash moves. A reversal of a known non-payment, such as a settlement, moves no cash. A reversal whose original is outside the window is assumed to reverse a payment. A reversal therefore lands on its own date, and a day's collected can be negative.
- **Portfolio scope.** Receivable, overdue, todayDue, upcoming30, the chart's due series and the calendar's scheduled/overdue figures use only projections whose contract `isActive`; non-active projections passed in are skipped. Due figures include extension rows and exclude 0-due rescheduled rows.
- **upcoming30** = Σ unpaid remainder of open, non-overdue rows with 0 ≤ (due − today) ≤ 30, so today's rows are included. Each breakdown share is reported in bps of sanctionedReceivable (truncated; 0 when the receivable is 0).
- **Chart buckets.** weeks8 = 8 Monday-start weeks ending with the current week. months6/12 = calendar months ending with the current month. The last bucket is `isCurrent`, and its due figure covers the whole bucket, future days included. Labels are "d MMM" for the week start and "MMM" for a month.
- **Sort order.** The overdue list sorts by daysOverdue desc, then loanNo, contractId and seq. Severity is `critical` when daysOverdue > 3, otherwise `recent`. Today's items sort by loanNo, contractId and seq.
- **Memoisation.** All functions are pure. `PortfolioMetrics.collectionsSeries` and `calendarBuckets` compute on each call from the held inputs, and the provider layer memoises them.

Known limitations:
- Dart's lcov output has no branch records (BRDA), so branch coverage cannot be measured with the stock tooling. Line coverage is 100%, and the tests target every conditional explicitly. One defensive loop guard in the extension attribution (`qi < queue.length`) cannot be false, because Σ sources == S.
- Labels are English only (locale-free by design).

**Module Lead — Sprint 2 Review (attempt 1):**
Date: 2026-11-21

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- **Re-ran independently:** `flutter analyze` is clean, `flutter test` passes 284/284, and the domain purity test passes.
- **Coverage:** `domain/ledger` line coverage is 100% (464/464). Dart lcov has no branch data, so branches are covered by targeted tests.
- **Speed:** the benchmark runs 1,000 contracts in about 55–64 ms, against a 500 ms budget.
- **Hand-verified the Stitch reproduction test.** Weekly Tuesdays from 31 Oct 2023 give Inst 4 = 21 Nov and Inst 5 = 28 Nov. On 3 Dec:
  - Inst 5 is 5 days overdue and Inst 4 is 12 days overdue (partial);
  - paid ₹36,000, shortfall ₹14,000;
  - extensions are Inst 11 ₹10,000 on 9 Jan ("missed on 28 Nov (Inst. 5)") and Inst 12 ₹4,000 on 16 Jan ("partial on 21 Nov (Inst. 4)");
  - maturity 16 Jan, 12 cycles, cleared 36%.
  
  All match the expectations. The algorithm matches Section 2 point 3.
- **Interpretations accepted** (they refine the design and do not change requirements):
  1. Extension rows are labelled latest-first, so a late payment shrinks the tail row first and labels stay stable.
  2. Extensions are rolled forward so they are never dated in the past, which means never overdue themselves.
  3. "Collected" means cash: payments − reversals. Rollover settlement is excluded because no cash moves.
  4. Net disbursed sums all contracts (active + closed + rolledOver). A rollover's netDisbursed already excludes the settled balance, so there is no double count.
  5. Labels use "8 Oct" (no leading zero).
- **Hand-off note for the provider layer (Sprint 5+):** `collectionsSeries` and `calendarBuckets` are pure and recompute on each call. Memoise them in Riverpod providers keyed on the snapshot and today.
- No user-facing input exists yet. Validation lives in `validators.dart` and is covered by tests.

**Tester — Sprint 2 Results (attempt 1):**

Independent tests: `test/domain/ledger/tester/s2_{upfront_schedule,projection,excess_rollover,portfolio}_test.dart` (44 tests). `flutter analyze` is clean, and the full `flutter test` passes 328/328 (284 existing + 44 new).

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | ₹1,00,000 flat ₹7,000 | happy | upfront 7,000, net 93,000, 700 bps | as expected | pass |
| 2 | Percent 700 bps of 1L; half-up rounding on 333 paise × 50 bps | edge | 7,000; 2 paise | as expected | pass |
| 3 | 1L at 30k schedule | happy | 30k,30k,30k,10k, tenor 4, maturity = last due | as expected | pass |
| 4 | Monthly on the 31st from 31 Jan 2024 | edge | 31 Jan, 29 Feb, 31 Mar, 30 Apr (no drift after the Feb clamp) | as expected | pass |
| 5 | Monthly on the 30th in non-leap Feb; daily across the year end | edge | 28 Feb; 2 Jan | as expected | pass |
| 6 | Validation: sanctioned 0, upfront <0 or = sanctioned, % >100, installment 0 or > sanctioned, missing weekday/month day, payment 0 or > outstanding | failure | all rejected; valid terms pass | as expected | pass |
| 7 | Due today, unpaid | edge | `dueToday`, not overdue, no extension | as expected | pass |
| 8 | Partial 6k of 10k, next day | happy | overdue partial, 1 day; one ₹4,000 extension on 9 Jan, seq 11, "partial on 31 Oct (Inst. 1)"; maturity and cycles update; outstanding 94k | as expected | pass |
| 9 | Two missed weeks | happy | two ₹10k extensions 9/16 Jan, labelled latest-first; overdue 20k, max 8 days | as expected | pass |
| 10 | Late payment clears the 4k / pays 2.5k of it | edge | extension removed / shrinks to 1.5k | as expected | pass |
| 11 | Advance payment of 30k on day one | happy | rows 1–3 paid, next due Inst 4, no overdue | as expected | pass |
| 12 | Reschedule Inst 1 (full) to 15 Nov, today 8 Nov | edge | Inst 1 `rescheduled`; only Inst 2 overdue; one 10k extension, seq 12; base + moved = 1L; outstanding 1L | as expected | pass |
| 13 | Reversal of 10k after full payment | edge | settled, then reopened with outstanding 10k | as expected | pass |
| 14 | Two offline 5k payments over a 5k balance | edge | excess 5k, outstanding 0 | as expected | pass |
| 15 | Payment after rollover (rolledOver contract) | edge | excess = late payment | as expected | pass |
| 16 | Rollover: 1.5L new, flat 15k, old outstanding 60k | happy | net ₹75,000, valid | as expected | pass |
| 17 | Rollover net exactly 0; net −15k; new sanctioned 0; % > 100 | edge/failure | 0 is valid; the others are invalid with an error | as expected | pass |
| 18 | Portfolio KPIs on a 3-contract fixture (2 active, 1 closed) | happy | net disbursed 159.5k, receivable 139k, collected 31k, overdue 14k (2 rows, max 8 days) | as expected | pass |
| 19 | Receivable = sanctioned − paid even with extension rows | edge | 94k for c1 | as expected | pass |
| 20 | Today's due, and overdue list order and severity, incl. the 3/4-day boundary | edge | 5k/5k; [8,1] days; 8 critical, 1 recent; 3 days recent, 4 days critical | as expected | pass |
| 21 | Weekly chart buckets | edge | 8 buckets starting Monday, current = 6 Nov, collected 5k / 26k | as expected | pass |
| 22 | Monthly chart, and an empty book | edge | 6 buckets Jun–Nov; empty book gives zero KPIs, 0 bps | as expected | pass |
| 23 | No `double` for money in `lib/domain` and `lib/core/money` | failure | no `double` | grep finds only a doc comment forbidding it | pass |

**Bugs Found:** None.

**Sprint Test Summary:** 23 test cases (44 automated tests) passed, 0 failed.

**Human verification:** the user approved Sprint 2's money rules (2026-11-21).

### Sprint 3
**Sprint Goal:** Rules tests pass on the emulator for every collection × role. On a device a user can sign in with Google, set an MPIN, unlock with MPIN or fingerprint, hit the 5-try lockout, and auto-lock.

**kani-orchestrator:role-database-admin — Task 6 Firestore rules + indexes + rules tests:**

Files created/modified:
- `firebase/firestore.rules` — full company-scoped rules (helpers signedIn/isSelf/member/memberAfter/owner/stamped/isInt/nonNeg/onlyKeys/affectedKeys), every path, default deny
- `firebase/firestore.indexes.json` — the 8 composite indexes from Section 2
- `firebase/package.json`, `firebase/package-lock.json`, `firebase/vitest.config.js`, `firebase/.gitignore` — Node rules-test project (`@firebase/rules-unit-testing` 6, `firebase` 13, `vitest` 4); `npm test` = `firebase emulators:exec --only firestore --project demo-nordic "npx vitest run"`
- `firebase/test/rules.test.js` — 260 tests: collection × {owner, collector, other-company owner, signed-out} × {get, list, create, update, delete} matrix + dedicated write-path tests

Key decisions:
- Role ⇔ `ownerUids` consistency is enforced via `getAfter(company)` on member create/update/delete, so a member doc with role owner always pairs with `ownerUids` containing that uid (and a removed uid can't linger in `ownerUids` with owner powers).
- Invite accept is mutually bound: member create checks `get`(invite) pending+unexpired and `getAfter`(invite) accepted by self, same company + role; invite update checks `getAfter(members/self).inviteCode == code`.
- Collector contract updates: changed keys only [totalPaidPaise, lastPaymentOn, updatedAt, status, closedAt]; totalPaidPaise may only grow; status may stay as-is or move within active↔closed.
- Transactions: `stamped()` (recordedAt must be serverTimestamp), int amounts ≥ 0, payment > 0, reversal > 0 with reversesTxId, reschedule == 0; updates only `contractActive`.
- Contract create: ints, sanctioned > 0, 0 ≤ upfront < sanctioned, net == sanctioned − upfront (or < it when `rolledOverFromContractId` is set), totalPaidPaise == 0, status active, count ≤ 366.
- Invite create requires the code to match the 6-char alphabet `[2-9A-HJKMNP-Z]`, `expiresAt > now`, createdBy == caller.

Known limitations:
- **Client contract changes (for the Companies & members task):** (1) accepting an *owner* invite must also `arrayUnion(self)` on `companies/{cid}.ownerUids` in the same transaction (rules allow exactly that, nothing else); (2) an owner leaving / deleting their account (non-last owner) must `arrayRemove(self)` from `ownerUids` in the same batch as deleting their member doc; (3) member/membership docs are key-whitelisted (member: uid, role, displayName, phoneE164, status, inviteCode, invitedBy, joinedAt, schemaVersion; membership: companyId, companyName, role, joinedAt, schemaVersion).
- Added beyond outline: owner may update `users/{x}/memberships/{cid}` (role/companyName only) to keep the role in sync on role change; members may edit their own displayName/phoneE164.
- Installment updates use the same key whitelist for owners and collectors (per outline); owners cannot edit amountDuePaise after creation.
- Rules/indexes NOT deployed to `microfinance-loan-mgr` (awaiting approval).

**kani-orchestrator:role-ui-team — Task 7 Auth & lock:**

Files created/modified:
- `lib/core/config/app_config.dart` — web OAuth client id (client_type 3) as `googleServerClientId`, MPIN length / 5-try limit / default auto-lock / biometric reason
- `lib/features/auth/data/auth_repository.dart` — `AuthRepository` + `FirebaseAuthRepository` (google_sign_in v7 `initialize(serverClientId)` → `authenticate()` → `GoogleAuthProvider.credential(idToken)` → `signInWithCredential`), `reauthenticateWithGoogle`, `signOut` (Google + Firebase), `authStateChanges`, AppFailure mapping, fire-and-forget `users/{uid}` upsert via TypedRefs; `GoogleSignInGateway` seam
- `lib/features/auth/data/secure_key_value_store.dart` — `SecureKeyValueStore` seam, flutter_secure_storage impl, in-memory fake
- `lib/features/auth/data/mpin_store.dart` — per-uid `sha256(salt + pin + uid)` hex + 16-byte random salt, failure counter, 5-try lockout (wipes), biometric flag, autoLockMinutes (default 1)
- `lib/features/auth/data/biometric_service.dart` — local_auth 3 wrapper (`canCheck`, `authenticate(reason: 'Unlock Nordic Ledger')`)
- `lib/features/auth/application/auth_providers.dart` (+ `.g.dart`) — keepAlive providers for repo / storage / MPIN store / biometric
- `lib/features/auth/application/session_controller.dart` (+ `.g.dart`) — `AuthStage` {loading, signedOut, needsMpinSetup, locked, unlocked}, `SessionState`, sign-in, MPIN setup, PIN/biometric unlock, forgot MPIN, lockout, lock, sign-out
- `lib/features/auth/application/lock_controller.dart` (+ `.g.dart`) — `AppLifecycleListener` auto-lock after ≥ autoLockMinutes in background
- `lib/core/routing/app_router.dart` (+ `.g.dart`) — go_router with pure `authRedirect(stage, location)`; `/splash`, `/sign-in`, `/mpin/setup`, `/mpin`, `/home` (theme gallery); TODO for the Sprint 4 hasActiveCompany guard
- `lib/app.dart` — `MaterialApp.router`, starts the lock listener
- `lib/core/widgets/brand_mark.dart` — navy tile + white 3-bar ledger glyph with sage dot (CustomPainter), 96dp/r24 or 64dp/r16
- `lib/features/splash/presentation/splash_screen.dart` — splash per Stitch
- `lib/features/auth/presentation/screens/sign_in_screen.dart`, `mpin_setup_screen.dart`, `mpin_unlock_screen.dart` — screens per Stitch "1. Authentication & MPIN"
- `lib/features/auth/presentation/widgets/auth_layout.dart`, `google_g_mark.dart`, `device_only_note.dart`, `inline_error.dart`, `shake.dart` — shared auth widgets (420dp max column, local 4-colour G, footer, terracotta error + icon, wrong-PIN shake)
- `lib/core/theme/app_theme.dart` — new tokens: Google brand colours, `brandTileLg/Md`, `authContentMaxWidth`, `splashProgressWidth`, `progressBarHeight`, `googleMark`, `shakeOffset`, `AppRadii.xlAll`
- `pubspec.yaml` — `crypto` added as a direct dependency
- `android/app/src/main/kotlin/com/nordicledger/app/MainActivity.kt` — `FlutterFragmentActivity`
- `android/app/src/main/AndroidManifest.xml` — `USE_BIOMETRIC` permission
- `android/app/src/main/res/values{,-night}/styles.xml`, `android/app/build.gradle.kts` — LaunchTheme/NormalTheme now AppCompat parents (+ `androidx.appcompat:appcompat:1.7.1`), as local_auth requires to avoid crashes on Android ≤ 8 (minSdk 23)
- Tests: `test/features/auth/auth_fakes.dart`, `mpin_store_test.dart`, `session_controller_test.dart`, `auth_repository_test.dart`, `auth_screens_test.dart`, `test/core/routing/app_router_test.dart` (77 new tests; suite now 405)

Key decisions:
- **flutter_secure_storage 11 has no `encryptedSharedPreferences` option** (removed in v10). Its default `AndroidOptions` is the replacement (AES-GCM data, Keystore-wrapped RSA-OAEP key), so that is what we use, with a dedicated `storageNamespace`.
- Cold start or a fresh Google sign-in with an MPIN already on the device → `locked`; no MPIN → `needsMpinSetup`. A repeat auth-stream event for the same active uid doesn't reset the stage.
- Lockout: verify() wipes the MPIN on the 5th failure; the controller sets `signedOut` + `kLockoutMessage` *before* signing out, so the sign-in screen shows the notice. Signing in again forces MPIN setup.
- Forgot MPIN uses `User.reauthenticateWithCredential`, so picking a different Google account fails with "Use the same Google account you signed in with." (`user-mismatch` → ValidationFailure) and the MPIN stays.
- `users/{uid}` upsert runs on every Google sign-in with `merge: true`, and `createdAt` = the Auth account creation time, so it is idempotent. It is never awaited, and errors (denied or pending) are only logged. Compatible with Task 6's `allow write: if isSelf(uid)`.
- Biometric opt-in at setup only shows when `canCheck()` is true. "Use fingerprint" runs one real prompt and enables only if it succeeds. Unlock auto-prompts on open when enabled. A successful biometric unlock resets the MPIN failure counter.
- Auto-lock: the first hidden/paused event records the time (IST clock). On resume it locks if away ≥ autoLockMinutes. It only arms when the stage is unlocked.
- Router: the redirect is a pure function (unit-tested per stage); a `ValueNotifier<AuthStage>` is the `refreshListenable`. Unknown paths go to `/home` when unlocked.

Known limitations:
- Needs a real device:
  - the Google account picker / Credential Manager with the debug SHA-1;
  - the fingerprint prompt (FragmentActivity + AppCompat theme);
  - the auto-lock timing after real backgrounding;
  - the secure-storage persistence across app restarts.
- The `users/{uid}` write is denied server-side until Task 6's rules are deployed. It is logged and sign-in continues.
- Privacy / Terms links are no-ops (Sprint 8). The company · role line on the MPIN screen and the hasActiveCompany guard come in Sprint 4.
- autoLockMinutes is device-local (secure storage) as the task specified. `UserSettings.autoLockMinutes` in Firestore is not read yet. Settings (Sprint 8) should pick one source.

**Module Lead — Sprint 3 Review (attempt 1):**
Date: 2026-11-21

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- **Re-ran independently:** `flutter analyze` is clean and `flutter test` passes 405/405. The rules suite reported 260/260 on the `demo-nordic` emulator, and the rules syntax validated OK. Nothing was deployed to `microfinance-loan-mgr`.
- **MPIN.** `sha256(salt+pin+uid)` with a 16-byte `Random.secure()` salt, per-uid keys, a 5-attempt lockout, and secure storage backed by the Android Keystore. There are no `print` calls in `lib/`.
  - *Accepted limitation:* a 4-digit PIN has only 10k combinations, so a fast hash would not resist offline brute force if the Keystore-encrypted storage were extracted from a rooted device. A future hardening option is PBKDF2/Argon2 with high iterations. The MPIN is a convenience lock, and real identity is Google auth, so this is acceptable for v1.
- **Secrets.** The web OAuth client id in `app_config.dart` is public by design.
- **Rules deviations accepted.** They are stricter or necessary.
- **Interface obligations for later sprints:**
  1. **Sprint 4, invite accept transaction:** when `invite.role == owner`, the transaction must also `arrayUnion(self)` into `companies/{cid}.ownerUids`, or the rules deny it and the user would join without owner powers.
  2. **Sprint 4, role change:** promoting or demoting a member must update `ownerUids` (arrayUnion/arrayRemove) and `users/{uid}/memberships/{cid}.role` in the same batch.
  3. **Sprint 8, delete account / leave company:** a non-last owner must `arrayRemove(self)` from `ownerUids` in the same batch as deleting their member doc.
  4. **Sprint 5/6:** collectors may only increase `totalPaidPaise`, so owner-only reversals do the decrement. Payment/reversal amounts must be > 0 and reschedule audit transactions exactly 0, and a reversal needs `reversesTxId`. Installment `amountDuePaise` is immutable after create. Contracts are created active with `totalPaidPaise` 0 and ≤ 366 installments.
  5. **Sprint 8:** pick one source for `autoLockMinutes`. Recommended: device-local, because the lock is per device.
- **Android changes accepted:** `FlutterFragmentActivity`, AppCompat launch themes and `androidx.appcompat` (required by local_auth). flutter_secure_storage 11 no longer has the `encryptedSharedPreferences` flag; its default options are the replacement.
- **Deploy needed before on-device sign-in can write `users/{uid}`:** `firebase deploy --only firestore:rules,firestore:indexes --project microfinance-loan-mgr`. Pending user approval.

**Tester — Sprint 3 Results (attempt 1):**

New adversarial tests:
- `firebase/test/tester.test.js`: 12 tests, run on the `demo-nordic` emulator.
- `test/features/auth/tester/mpin_store_tester_test.dart`: 7 tests.
- `test/features/auth/tester/lock_router_tester_test.dart`: 11 tests.
- `test/features/auth/tester/mpin_unlock_tester_test.dart`: 4 tests.

Full-suite results:
- Rules: `npm test` passes 272/272 (260 + 12).
- Flutter: `flutter test` passes 427/427 (405 + 22), and `flutter analyze` is clean.
- Nothing was deployed and no production code was changed.

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | Collector of A gets B's contract by guessed id | failure | denied | denied | pass |
| 2 | Collector of A lists B's contracts | failure | denied | denied | pass |
| 3 | Collector of A gets an A contract (control) | happy | allowed | allowed | pass |
| 4 | Collector deletes a transaction | failure | denied | denied | pass |
| 5 | Collector sets contract status `rolledOver` | failure | denied | denied | pass |
| 6 | Collector decreases `totalPaidPaise` (200000 → 100000) | failure | denied | denied | pass |
| 7 | Collector sets a non-integer `totalPaidPaise` | edge | denied | denied | pass |
| 8 | Collector increases `totalPaidPaise` (control) | happy | allowed | allowed | pass |
| 9 | Signed-in non-member gets an invite by exact code | happy | allowed | allowed | pass |
| 10 | Signed-in user lists `invites` | failure | denied | denied | pass |
| 11 | Signed-out user gets an invite | failure | denied | denied | pass |
| 12 | Signed-out user reads a contract | failure | denied | denied | pass |
| 13 | MPIN not stored in plain text (no stored value equals the PIN or its unsalted sha256; hash is 64 hex, salt is 32 hex) | happy | no plaintext | no plaintext | pass |
| 14 | Same PIN for two uids gives different hashes | edge | differ | differ | pass |
| 15 | Re-setting the same PIN rotates the salt and hash | edge | new hash | new hash | pass |
| 16 | 5 wrong tries wipe the MPIN; a 6th attempt with the right PIN fails (store) | failure | locked out, not ok | locked out, not ok | pass |
| 17 | Lockout of one uid leaves another uid's MPIN intact | edge | u2 unlocks | u2 unlocks | pass |
| 18 | Right PIN resets the failure counter | happy | counter 0 | counter 0 | pass |
| 19 | Invalid PIN formats (3 or 5 digits, letters, space, empty) are rejected at setup | failure | ArgumentError, no MPIN | ArgumentError, no MPIN | pass |
| 20 | Auto-lock: away 59.999 s with the 1-min default | edge | unlocked | unlocked | pass |
| 21 | Auto-lock: away exactly 60 s | edge | locked | locked | pass |
| 22 | Auto-lock: away 61 s | edge | locked | locked | pass |
| 23 | Auto-lock with a 5-min setting: 4:59 vs 5:01 | edge | unlocked / locked | unlocked / locked | pass |
| 24 | hidden then paused keeps the first timestamp (40 s + 30 s away) | edge | locked | locked | pass |
| 25 | Resume without a background event | edge | no-op | no-op | pass |
| 26 | Unlocked user opens /sign-in, /mpin, /mpin/setup or /splash | failure | → /home | → /home | pass |
| 27 | Unlocked user on /home | happy | no redirect | no redirect | pass |
| 28 | Unlocked user on an unknown path | edge | → /home | → /home | pass |
| 29 | Signed-out user opens /home or /mpin | failure | → /sign-in | → /sign-in | pass |
| 30 | Locked, needs-setup and loading users open /home | failure | → /mpin, /mpin/setup, /splash | as expected | pass |
| 31 | `wrongMpinMessage` pluralises the tries | happy | "4 tries" / "1 try" | as expected | pass |
| 32 | Unlock screen: each wrong PIN shows 4, 3, 2 tries left | happy | messages shown | shown | pass |
| 33 | Unlock screen: right PIN after a wrong one | happy | unlocked | unlocked | pass |
| 34 | Controller: 5 wrong PINs → signedOut and signOut called once; a 6th `unlockWithPin` with the right PIN | failure | not ok, stays signedOut, MPIN gone | as expected | pass |

Note: on its first run, test 13 failed once because of the test itself, not the app. It checked for the substring "4821" anywhere in the stored values, and a random hex salt or hash can contain that by chance. The check now uses exact equality, and 6 reruns passed.

**Needs human verification on a device** (cannot be automated here):
- Google account picker / Credential Manager with the debug SHA-1.
- Fingerprint prompt (FragmentActivity + AppCompat theme).
- Real auto-lock after the app is backgrounded.
- Secure-storage persistence across app restarts.
- The `users/{uid}` upsert stays denied until the rules are deployed.

**Bugs Found:** none.

**Sprint Test Summary:** 34 passed, 0 failed.

**Deploy:** on user approval (2026-11-21), `firestore.rules` and the 8 composite indexes were deployed to `microfinance-loan-mgr` (rules compiled and released).

**Human verification:** the orchestrator ran the build on the user's emulator: the sign-in screen rendered and the Google sign-in flow launched. The user completed Google sign-in and the MPIN flows on the emulator and reported "tested looks good". Firestore confirms a `users/{uid}` doc (schemaVersion 1) was created under the live rules. Sprint 3 approved.

### Sprint 4
**Sprint Goal:** A new user registers a company and becomes owner. The owner invites a collector via WhatsApp/SMS. The collector joins with the code, sees only that company, and switches companies. Revoke, role change and the last-owner guard work.

**kani-orchestrator:role-ui-team — Task 8 Companies & onboarding:**

Files created/modified:
- `lib/core/firebase/firebase_providers.dart` — `firestoreProvider` (tests override with FakeFirebaseFirestore); `auth_providers.dart` now uses it.
- `lib/core/phone/indian_phone.dart` — `IndianPhone.toE164 / format ("+91 98450 12890") / nationalDisplay` + `IndianMobileInputFormatter` (5+5 grouping).
- `lib/core/validation/onboarding_validators.dart` — company name 2–80 after trim, display name, `InviteCode` (alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ`, sanitize, `fromReferrer`).
- `lib/core/errors/app_failure.dart` — new `InviteUnavailableFailure` (accepted / revoked invite).
- `lib/core/widgets/phone_field.dart` — +91 prefix input, tabular, validator.
- `lib/core/theme/app_theme.dart` — tokens `onboardingMaxWidth`, `codeBoxWidth/Height`, `avatarSm/Md`.
- `lib/features/onboarding/data/company_repository.dart` — `registerCompany` (one WriteBatch: company + owner member + membership + user_settings merge; uuid v4 cid; nextLoanNo 0), `watchMemberships`, `watchCompany`, `watchMember`, `deleteOwnMembership`.
- `lib/features/onboarding/data/invite_repository.dart` — `InvitePreview`, `lookup` (server-only get), `accept` (online `runTransaction`; owner invites `arrayUnion` ownerUids).
- `lib/features/onboarding/data/user_settings_repository.dart` — get / watch / set `activeCompanyId` (merge patch).
- `lib/features/onboarding/data/cache_reset_flag.dart` — secure-storage flag for "clearPersistence on next cold start".
- `lib/features/onboarding/data/install_referrer_source.dart` — reads Play install referrer `code=` once per install; all failures ignored.
- `lib/features/onboarding/application/onboarding_providers.dart` — repo providers, `PendingInviteCode`, `installReferrerBootstrap`.
- `lib/features/company/application/company_providers.dart` — `currentUid`, `memberships`, `userSettings`, `activeCompanyId` (settings → first membership), `companyGate`, `activeMembership`, `activeCompany`, `currentMember`, `currentRole`, `activeCompanyName`, `CompanyNotice`, `CompanyAccessGuard` (removed-member flow), `CompanyActions` (register / lookup / accept / switchTo).
- `lib/features/company/presentation/widgets/{role_pill,company_avatar,company_switcher_sheet}.dart` — role pill, initials tile, adaptive switcher sheet.
- `lib/features/onboarding/presentation/screens/{register_company_screen,join_company_screen}.dart` — Stitch 0 / 0b.
- `lib/features/onboarding/presentation/widgets/{account_chip,onboarding_layout,invite_code_boxes,invite_preview_card}.dart`.
- `lib/features/dashboard/presentation/screens/home_screen.dart` — placeholder Dashboard in AdaptiveScaffold, header "{Company} ▾ · {Role}" opens the switcher, "Dashboard coming in Sprint 7".
- `lib/core/routing/app_router.dart` — `appRedirect` (auth + company guard, `/join?code=` deep link, pending code), onboarding routes, `/dev/gallery` (debug only); `authRedirect` kept as a ready-company wrapper.
- `lib/app.dart` — watches guard + referrer bootstrap; shows `CompanyNotice` as a snackbar.
- `lib/bootstrap.dart` — `clearFirestoreCacheIfScheduled` before any Firestore read.
- `lib/features/auth/presentation/screens/mpin_unlock_screen.dart` — "{Company} · {Role}" under the greeting.
- `android/app/src/main/AndroidManifest.xml` — `nordicledger://app/join?code=…` intent filter + `flutter_deeplinking_enabled`.
- `pubspec.yaml` — `android_play_install_referrer: ^0.4.0`.
- Tests: `test/core/phone/indian_phone_test.dart`, `test/core/validation/onboarding_validators_test.dart`, `test/core/routing/onboarding_redirect_test.dart`, `test/features/onboarding/{onboarding_repositories,onboarding_screens,cache_and_referrer}_test.dart`, `test/features/onboarding/onboarding_test_support.dart`, `test/features/company/{company_providers,company_switcher}_test.dart`; `test/features/auth/auth_fakes.dart` (AuthHarness now overrides Firestore + referrer); `test/core/routing/app_router_test.dart` (sign-up now lands on Register).
- `firebase/test/sprint4_flows.test.js` — replays the exact register batch, collector + owner accept transactions, and removal cleanup against the emulator (11 tests).

Key decisions:
- **Register is offline-tolerant:** the batch is committed with an 8 s grace (`commitGrace`). A rules rejection while online surfaces as an error; with no ack in time it is treated as queued (already in the cache) and the user proceeds.
- **user_settings uses an untyped merge patch** `{activeCompanyId, updatedAt: serverTimestamp, schemaVersion}`, so a second company never resets notification prefs. Reads still decode with `ModelCodecs.userSettings`.
- **Lookup is server-only** (`Source.server`) with a 20 s deadline → `offlineRequired`. Accept is `runTransaction` (online-only, per CLAUDE.md). Member displayName/phone default to the invite's invitee details. `activeCompanyId` is a separate queued write after the transaction.
- **Removed-member detection never fires on a cache miss:** `watchMember` ignores "does not exist" snapshots that come from the cache, and treats a server not-exists or `permission-denied` as removal. The guard handles two signals: (a) the member doc is gone, so the company is hidden and the stale membership is self-deleted; (b) the active company drops out of memberships (owner deleted the index). Either way the app shows "You no longer have access to {company}" once, writes the next membership (or null → onboarding) to `user_settings`, and sets the secure-storage flag. Sign-out and normal switches are excluded. Side effects run in a microtask to avoid re-entrant provider rebuilds.
- **Router:** onboarding screens stay reachable when a company exists (Join another / Register new). `/join?code=` while locked is held in `PendingInviteCode` and opened after unlock. The install referrer feeds the same pending code.
- `currentRoleProvider` = member doc role (rules' source of truth), falling back to the membership index while the member doc is not yet loaded (offline cold start).
- Owner mobile is required on Register. The business phone and city are optional.
- The join code boxes are one invisible TextField under 6 painted boxes, so keyboard paste and autofill work. Invalid letters (0/O/1/I/L) are kept and explained, not silently dropped. "Paste from clipboard" extracts `code: XXXXXX` from a pasted WhatsApp/SMS message.

Known limitations:
- **Deep link is a custom scheme** (`nordicledger://app/join?code=`). There is no verified https App Link because there is no web domain. The invite message (Task 9) must use this scheme, or the Play referrer URL `https://play.google.com/store/apps/details?id=com.nordicledger.app&referrer=code%3DXXXXXX`.
- The Play install referrer works only for Play-installed builds. It cannot be exercised with a sideloaded debug APK (it fails quietly by design). `android_play_install_referrer` 0.4.0 is old (compileSdk 33, Kotlin 1.8) but builds with the current toolchain.
- `fake_cloud_firestore` cannot simulate `permission-denied` or cache metadata. Those branches of `watchMember` are covered only by the emulator rules test (denied read after removal) and by code review.
- `firebase/test/sprint4_flows.test.js` mirrors the Dart payloads by hand. If the models change, update both.
- Home is a placeholder: the other nav destinations show an EmptyState.
- Not verified on a device: Google sign-in → register → home on the live project, the deep link via `adb shell am start -a android.intent.action.VIEW -d "nordicledger://app/join?code=XXXXXX"`, and `clearPersistence()` on the cold start after a removal.

**kani-orchestrator:role-ui-team — Task 9 Members & invites:**

Files created/modified:
- `firebase/firestore.rules` — **RULES CHANGE (needs redeploy):** `invites` `allow list: if signedIn() && owner(resource.data.companyId)` (was `if false`). Only a query constrained by `companyId == <cid>` where the caller is an owner passes. Unconstrained or foreign-company listing is still denied for everyone. No index change: the query is two equality filters, and it is sorted on the client.
- `firebase/test/sprint4_flows.test.js` — +27 tests replaying createInvite (collision get + set), the owner pending-invites query, revoke, resend-of-expired, changeRole promote/demote/self-demote, removeMember (collector / co-owner), the last-owner denials, and collector / other-owner / non-member denials for each.
- `firebase/test/rules.test.js` — the "denies listing invites" test now covers unconstrained listing; a new test checks that only the owner can run the `companyId`-scoped query (collector, other owner and non-member are denied). The matrix row (unconstrained list denied for all) is unchanged.
- `lib/features/onboarding/data/invite_repository.dart` — `generateCode` (`Random.secure()`, injectable), `createInvite` (online: server reads of company + caller member, up to 5 collision-checked `get`s, then set with pending status and +7 d expiry), `watchPendingInvites` (`companyId` + `status == pending`, newest first), `revokeInvite` (status only, offline-tolerant), `resendInvite` (same invite if unexpired; otherwise a fresh code, then revoke the old one).
- `lib/features/company/data/members_repository.dart` — `LastOwnerGuard` (client mirror of `soleOwner`), `watchMembers` (owners first), `changeRole` and `removeMember`, each one WriteBatch (member + `ownerUids` arrayUnion/arrayRemove + membership role/delete).
- `lib/features/company/data/invite_share_service.dart` — WhatsApp (`wa.me`, external app then browser fallback), SMS, share_plus and clipboard. The platform calls are injectable.
- `lib/features/company/application/invite_message.dart` — `InviteChannel` and `InviteMessage` (exact message text, Play referrer link, deep link, wa.me / sms URIs with `Uri.encodeComponent`).
- `lib/features/company/application/members_providers.dart` (+ `.g.dart`) — repo / share-service providers, `companyMembers`, `pendingInvites` (owner only; collectors get an empty list and no query), `activeOwnerUids`, `MembersActions`.
- `lib/features/company/presentation/members_screen.dart` — Stitch 9. App bar "Members" + company subtitle. Owner: invite card, pending invites, members with kebab. Collector: read-only list. Expanded owner view is two columns (form 5 | lists 7).
- `lib/features/company/presentation/invite_sender.dart` — `sendInvite` (snackbars for unavailable WhatsApp/SMS and for "Invite code X copied") and the Resend share sheet (`showAdaptiveSheet`).
- `lib/features/company/presentation/widgets/{invite_form_card,invite_send_buttons,invite_message_card,pending_invite_tile,member_tile,member_avatar}.dart`.
- `lib/core/validation/onboarding_validators.dart` — `inviteeName`.
- `lib/core/theme/app_theme.dart` — `AppTextStyles.codeMono` token for the code chip.
- `lib/core/routing/app_router.dart` — `AppRoutes.members = '/settings/members'`, `companyShell` set (home + members) allowed when the company is ready; route added.
- `lib/features/dashboard/presentation/screens/home_screen.dart` — temporary header kebab "Members & invites" (owner) / "Members" (collector) until Settings in Sprint 8.
- `android/app/src/main/AndroidManifest.xml` — `<queries>` for https VIEW, sms SENDTO/VIEW, text/plain SEND, and the `com.whatsapp` / `com.whatsapp.w4b` packages.
- Tests: `test/features/company/members_repository_test.dart`, `invite_message_test.dart`, `members_screen_test.dart` (owner and collector at 400 and 1200, validation, WhatsApp create + preview + copy reuse, WhatsApp-unavailable snackbar, last-owner disabled, co-owner enabled, revoke and remove confirmations, route redirect); `company_switcher_test.dart` (+ Home menu → MembersScreen).

Key decisions:
- **Pending-invite listing needed a rules change.** List was `false` for everyone, and the brief forbids mirror collections, so the minimal owner-scoped list rule was added. The `get(companyPath(resource.data.companyId))` check works for queries because the `companyId` equality is in the query. Emulator tests prove an unconstrained list is still denied, even for owners. Section 2's "list: false" line is now out of date; I left it for the Tech Lead / BA to update.
- `createInvite` takes `cid` + `uid` and reads the company name/city and the caller's `displayName` (for `createdByName`) from the server. These reads double as the online check. Any timeout maps to `OfflineRequiredFailure`. Running out of collision attempts throws `UnknownFailure`.
- The form creates the invite on the first send action (WhatsApp / SMS / Share / Copy). Later actions reuse it until name, mobile or role changes, so trying several channels never mints several codes. "Invite someone else" resets the form.
- Pending invites include expired-but-pending ones, shown in terracotta as "Code X · expired" with "Resend new code". Expiry copy: "expires in N days" (ceil), or "expires today" when under 24 h.
- `changeRole` / `removeMember` read the company and member with a default `get` (cache-capable) and commit with an 8 s grace, so they queue offline like other batches. `revokeInvite` is also offline-tolerant. Only create (and resend-of-expired) needs a connection.
- Last-owner guard: in the kebab, "Make collector" and Remove are disabled, the Remove item reads "Last owner can't be removed", and a lock note appears under the row. The repository rejects these too, before the rules would.
- An owner can demote or remove themselves when another owner exists. The confirmation copy changes ("Leave {company}?"), and the existing `CompanyAccessGuard` handles the switch-out.

Known limitations:
- **Redeploy needed:** `firestore.rules` changed (invites `list`). `firestore.indexes.json` is unchanged. Until the rules are redeployed, the live project denies the owner's pending-invites query, and the section shows "Pending invites can't be loaded right now." Creating, revoking, role change and removal work under the deployed rules.
- WhatsApp / SMS / share intents, the browser fallback when WhatsApp is not installed, and the Android 11+ `<queries>` were not exercised on a device. Unit tests use a fake launcher.
- `fake_cloud_firestore` ignores rules and `Source.server`, so the offline path of `createInvite` and the rule denials are covered only by the emulator tests and code review.
- Members are listed by `displayName` from the member doc. There is no profile edit yet (Sprint 8).

**Module Lead — Sprint 4 Review (attempt 1):**
Date: 2026-11-21

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- **Re-ran independently:** `flutter analyze` is clean and `flutter test` passes 548/548. The rules suite reported 310/310, including `sprint4_flows.test.js`, which replays the exact client payloads for register, accept (owner + collector), create/revoke invite, change role and remove member. There are no `print` calls in `lib/`.
- **Sprint 3 interface obligations met:**
  - the owner-invite accept does `arrayUnion` on `ownerUids` inside the transaction (a test proves it is denied without it);
  - changeRole and removeMember keep the member doc, `ownerUids` and the membership role in one batch;
  - the last-owner guard is enforced on the client and by the rules.
- **Rules change (accepted):** `invites` `list` is now allowed only for an owner of `resource.data.companyId`, with the query constrained by `companyId == cid`. An unconstrained list is still denied for everyone, so codes can't be enumerated. Section 2's rules outline is updated to match. **This needs a redeploy of `firestore.rules`.** Indexes are unchanged.
- **Accepted decisions:**
  - register works offline with an 8 s server-ack timeout;
  - removal is detected only on server-confirmed absence or permission-denied, never on cache-only misses;
  - deep link `nordicledger://app/join?code=` plus the Play referrer `code%3D…`;
  - one invite is reused across share channels until the form changes;
  - owner mobile is required on Register.
- **Validation:** company name 2–80, +91 10-digit phones, code alphabet and length, and invitee name/phone are all covered by widget tests.
- **Known residual risks:** `android_play_install_referrer` 0.4.0 is old but builds. fake_cloud_firestore can't simulate permission-denied, so those branches are covered by the emulator rules tests plus review.

**Tester — Sprint 4 Results (attempt 1):**

New test files: `test/features/company/tester/s4_message_and_code_test.dart` (10), `s4_invite_lookup_test.dart` (8), `s4_members_widgets_test.dart` (4), `firebase/test/tester_s4.test.js` (10). Full runs: `flutter analyze` clean; `flutter test` 570/570 (was 548); `npm test` 320/320 (was 310).

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | Invite message text ("Raju & Sons Finance", Collector, K7Q2MD) | happy | Company in `*…*`, role, code, Play referrer `code%3D…`, deep link | as expected | pass |
| 2 | wa.me URI for "+91 98450 12890" | edge | `wa.me/919845012890` (no `+`), `&`→`%26`, no raw spaces, `text` decodes to the exact message | as expected | pass |
| 3 | sms URI body | edge | `sms:+919845012890?body=`, body encoded, decodes back exactly | as expected | pass |
| 4 | Owner role label | happy | "as Owner." | as expected | pass |
| 5 | 5000 generated codes (seeded Random) | edge | Only the allowed alphabet, never 0/O/1/I/L; all 31 chars appear | as expected | pass |
| 6 | `InviteCode.isValid` with 0/O/1/I/L, 5 chars, lowercase | failure | rejected | rejected | pass |
| 7 | Company name of 1 char (and " A ") vs 2 chars | edge | 1 rejected, 2 ok | as expected | pass |
| 8 | Company name 80 / 81 / whitespace-only / padded 80 | edge | 80 ok, 81 rejected, blank rejected, trim before length | as expected | pass |
| 9 | Phone with spaces, +91, 91, 0 prefix, dash | edge | all normalise to +919845012890 | as expected | pass |
| 10 | Bad phones (starts with 1, 9 digits, +1, 12 digits), empty required | failure | rejected | rejected | pass |
| 11 | Lookup of an invite expired 1 minute ago | failure | ExpiredFailure | ExpiredFailure | pass |
| 12 | Accept an expired invite | failure | ExpiredFailure, no member/membership written | as expected | pass |
| 13 | Lookup + accept an already-accepted code | failure | InviteUnavailableFailure | as expected | pass |
| 14 | Accept the same code twice | failure | 2nd accept → InviteUnavailable; invite accepted by the first uid | as expected | pass |
| 15 | Revoked code lookup | failure | InviteUnavailableFailure | as expected | pass |
| 16 | Lowercase/padded code; unknown code | edge | normalised and found; unknown → NotFound | as expected | pass |
| 17 | Malformed code (has O; 3 chars) | failure | ValidationFailure | as expected | pass |
| 18 | Accept an owner invite | happy | uid in ownerUids, member role owner, name from the invite | as expected | pass |
| 19 | Collector on Members screen | auth | No invite card, send buttons, pending codes, revoke or kebab | as expected | pass |
| 20 | Last owner kebab vs a collector's kebab | edge | Own Remove disabled with "Last owner can't be removed"; Remove on the collector enabled | as expected | pass |
| 21 | Repository removeMember / changeRole(collector) for the last owner | failure | ValidationFailure, member doc unchanged | as expected | pass |
| 22 | Switcher with 2 companies | happy | Both rows; A row pill = Owner, B row pill = Collector; tap B → user_settings.activeCompanyId = b | as expected | pass |
| 23 | Rules: owner of A lists A's invites (control) | happy | allowed | allowed | pass |
| 24 | Rules: collector of A lists A's invites | auth | denied | denied | pass |
| 25 | Rules: owner of A lists B's invites | auth | denied | denied | pass |
| 26 | Rules: owner lists with no companyId filter (status only / bare collection) | auth | denied | denied | pass |
| 27 | Rules: owner lists with `companyId in [A, B]` | auth | denied | denied | pass |
| 28 | Rules: collector invite accepted as collector (control) | happy | allowed | allowed | pass |
| 29 | Rules: collector invite accepted with member role owner | auth | denied | denied | pass |
| 30 | Rules: self-create a member doc with no invite | auth | denied | denied | pass |
| 31 | Rules: removed collector reads company / members / another member afterwards | auth | allowed before, all denied after | as expected | pass |
| 32 | Rules: removed member re-creates their own member doc | auth | denied | denied | pass |

**Bugs Found:** None.

**Needs human verification on a device (not testable here):** WhatsApp launch (`wa.me`, browser fallback when WhatsApp is missing) and the SMS app opening with the pre-filled body; the `nordicledger://app/join?code=` deep link (cold and warm, locked and unlocked); the Play install-referrer pre-fill (Play-installed build only); the two-account end to end flow (owner invites → collector installs, signs in, joins, sees only that company; owner removes them → switch-out notice + cache cleared on the next cold start); and the rules redeploy for invite `list` (redeploy to the real project is not done by the tester).

**Sprint Test Summary:** 32 passed, 0 failed.

**Deploy:** on user approval (2026-11-21), the updated `firestore.rules` (owner-scoped invite list) was redeployed to `microfinance-loan-mgr`.

**Human verification:** the build was installed on the user's emulator (reinstalled after `INSTALL_FAILED_INSUFFICIENT_STORAGE`, which reset the local sign-in and MPIN). The user verified and approved Sprint 4 (2026-11-21). Sprints 1–4 committed and pushed to `main` per the user's request.

### Sprint 5
**Sprint Goal:** An owner adds borrowers and creates contracts, including offline, with a correct net-disbursed figure and an auto-generated schedule. The owner views the timeline and reschedules an installment. Data syncs to the second device.

---

## 5. Final Review & Full Regression
> Filled by: Module Lead (combined review) + Tester (full feature regression)

_Pending..._

---

## 6. Project Update
> Filled by: Business Analyst (final pass)

_Pending..._
