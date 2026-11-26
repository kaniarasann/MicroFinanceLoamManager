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

*Full settlement & early-closure discount (added 2026-11-23, user request)*
- [ ] The Record Payment sheet has a 4th quick chip, **"Close loan ₹X"**, that fills the exact outstanding. When the amount equals the outstanding, the confirm button reads **"Confirm & close loan"**.
- [ ] **Early-closure discount (owner only).** When closing a loan, the owner may settle for less than the outstanding by entering a **waiver**: "Waive ₹W · reason (required)". The cash received C plus the waiver W must equal the outstanding exactly. The app records both in one atomic batch:
  - a `payment` transaction of C (if C > 0);
  - a `waiver` transaction of W.
  
  The contract then closes.
  - Example: outstanding ₹64,000, borrower pays ₹62,000 → waive ₹2,000 → contract closed.
- [ ] **Waivers are not cash.** They reduce the outstanding and settle installments like a payment, but they are **excluded** from Total Collected, the collections chart, received-today and receipts. The contract header and the borrower ledger show "Waived ₹W" with the reason. Dashboard metrics may later show "Waived" separately.
- [ ] A waiver is only allowed as part of closing (C + W == outstanding), never as a standalone partial write-off. It is owner only (enforced in rules), immutable, and can be undone only by an owner reversal, which reopens the loan like a payment reversal.
- [ ] A collector cannot see the waiver option, and the rules deny a collector writing a `waiver`.

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

### Addendum 2026-11-24: Onboard an existing loan
> Filled by: Business Analyst (feature request from the user, 2026-11-24)

**Knowledge Sources Consulted:**
- `docs/kani/knowledge/KNOWLEDGE_BASE.md`: no completed runs indexed yet (marker only).
- `README.md`: Flutter template text, nothing relevant.
- This living doc: Section 0, Section 1 (contract, payment, overdue, auto-extension, waiver and dashboard criteria), Section 2 (schema, rules outline, write paths), Section 3 and the Section 4 logs of Sprints 5–7.
- `CLAUDE.md` (project rules).
- Code: `lib/features/contracts/` (`create_contract_screen.dart`, `loan_terms_controller.dart`, `loan_schedule_fields.dart`, `date_field.dart`, `contract_draft.dart`, `contract_repository.dart`), `lib/features/payments/` (`payment_repository.dart`, `payment_providers.dart`, `record_payment_sheet.dart`), `lib/domain/ledger/` (`validators.dart`, `schedule_generator.dart`, `contract_projection.dart`, `portfolio_metrics.dart`), `lib/core/firebase/chunked_batch.dart`, `firebase/firestore.rules`, and the borrower profile "New loan" action.

**Request Summary:**
A lender moving to Nordic Ledger already has loans running on paper or in another system. Many of them are part-way through repayment. The owner needs a screen to **onboard an existing, in-progress loan**: enter the original terms and dates plus what the borrower has already paid. The app then shows that loan exactly as if it had been run in the app from day one: what is paid, partly paid and overdue today, and what is still to come. Without this, a lender cannot move their existing book into the app, and the dashboard would show only part of the business.

**Where backdating is blocked today (verified in code, 2026-11-24):**
- **UI (the only real block for contracts).**
  - `LoanTermsController.draft()` always sets `disbursedOn: today`. The form has no disbursement-date field.
  - The "First collection date" `DateField` in `loan_schedule_fields.dart` is limited to `first: today`, `last: today + 366`.
  - The rollover screen reuses the same controller, so it has the same limits.
- **UI (payments).** The Record Payment date picker allows `today − maxBackdateDays` (30, in `payment_providers.dart`) up to today. No future dates are allowed.
- **Domain validators.** `validateContractTerms` checks only `firstDueDate ≥ disbursedOn`. It has no check against today in either direction. `validatePaymentAmount` does not look at dates at all. `validateReschedule` blocks a new date before today; that rule is unrelated to this feature.
- **Repositories.** `createContract` and `recordPayment` pass the command's dates through unchanged. Reversals and reschedule audits are dated `today`.
- **Firestore rules.** Contract create checks only that `firstDueDate` and `disbursedOn` are `yyyy-MM-dd` strings, and that `totalPaidPaise == 0`. Transaction create checks only that `paidOn` is a `yyyy-MM-dd` string. **The rules have no date window.** A past or future `disbursedOn`, `firstDueDate` or `paidOn` is accepted today. The only server-side obstacle to onboarding is `totalPaidPaise == 0` on contract create.

**User decisions (fixed; not to be changed downstream):**
1. **How past payments are entered: BOTH.**
   - **Opening total (quick):** one "Already collected ₹X" figure.
   - **Itemised (optional, detailed):** a list of individual past payments, each with a date, an amount and a mode (UPI / Cash / Bank).
2. **Past cash counts everywhere**, as real payments on their dates: Total collected, the collections chart, the calendar, collected this month and the borrower's receipts and Collected tile.
3. **Shortfall is shown as overdue**, like any loan. Unpaid past installments show as Overdue with days late, and they auto-extend at the end through the existing projection. There is no special roll-forward.
4. **Owner only**, enforced in the UI and in `firestore.rules`.

**BA decision: the date of an opening total (recommendation, pending user confirmation; see open question 1).**
- **Option A: one payment dated on the onboarding day (today).** This creates a one-day spike:
  - Received today, the "Today's due" progress, collected this month and the current chart bar all jump by the whole historic amount. For example, ₹60,000 shows as "received today" when nothing was collected today.
  - Past chart periods show that loan's installments as *due* with ₹0 collected, so past collection rates look poor. The current period can go far above 100%.
  - The daily digest and any handover reconciliation for today would be wrong.
- **Option B (recommended): spread across the covered installments' due dates.** The opening total is allocated oldest-first over the schedule rows due on or before today. Each covered row gets one payment dated on its due date, for its amount; the last covered row may be partial.
  - Any amount beyond the dues up to today is an advance. It is dated on the latest of (disbursedOn, last past due date), so it never lands on today.
  - The chart, calendar and monthly figures then look as they would have if the loan had been run in the app. Received today is untouched.
  - **Cost:** the spread payments are reconstructed dates, not dates the lender actually recorded. They are labelled "Opening balance" in the contract ledger and receipts so nobody mistakes them for real collections. A daily loan can produce hundreds of payment docs. The Tech Lead handles that with chunking.
- If the lender knows the real dates, they use the itemised mode, which records exactly what they enter.

**Stakeholder Impact:**
- **Owner:** can bring the existing book into the app, loan by loan, offline, and sees an "as of today" preview before saving. Onboarding mistakes are corrected with the existing owner reversal.
- **Collector:** cannot onboard (the screen and entry points are hidden, and the rules deny it). After sync, collectors see onboarded loans like any other loan: due today, overdue and calendar. They can record new payments on them.
- **Dashboard and reports:** Total net disbursed rises by the onboarded loan's net cash. Total collected, the chart, the calendar and collected-this-month include the historic cash on its dates. Sanctioned receivable and Total overdue include the loan's balance and its overdue shortfall.
- **Notifications:** an onboarded loan with past shortfall triggers the overdue nudge from the next scheduling run.
- **Borrowers (not app users):** their outstanding balance and overdue days match the paper record, provided the owner enters it correctly.

**Acceptance Criteria:**

*Entry and access*
- [ ] An owner can start "Onboard existing loan" from two places:
  - the New loan screen, through a "New loan · Existing loan" toggle at the top;
  - the borrower profile, through an "Existing loan" action beside "+ New loan".
  
  Both open the same onboarding screen, preselecting the borrower when started from the profile.
- [ ] A collector never sees either entry point. Opening the onboarding route directly as a collector shows "Only owners can onboard loans." and leaves the screen. Firestore rules deny a collector creating an onboarded contract or an onboarding payment (verified by rules tests).

*Original terms and dates*
- [ ] The screen captures the same terms as a new loan: borrower, sanctioned amount, upfront interest (flat ₹ or %), frequency, installment amount and preferred weekday or month day. It also captures an optional previous reference number (the paper or old-system loan number), guarantor, purpose and notes. Net cash handover and effective % update live as on the New loan screen.
- [ ] **Disbursed on** is a required date from **today − 3 years to today**. Future dates cannot be picked.
- [ ] **First collection date** is a required date from **disbursedOn to disbursedOn + 366 days**. It may be in the past, today or the future.
- [ ] The full base schedule is generated from the original first collection date with the existing rules: tenor, remainder on the last row, month-end clamping and the 366-installment limit. Some or all rows may fall in the past.

*Past payments*
- [ ] A "Collected so far" section has a segmented control: **Opening total** (default) and **Itemised payments**. Either mode may be left at ₹0, which onboards a backdated loan with nothing collected.
- [ ] **Opening total mode:** one ₹ amount and one payment mode (default Cash). A helper line explains how it will be dated, for example "Spread across 7 installments due up to today", per the confirmed option for open question 1.
- [ ] **Itemised mode:** the owner adds, edits and removes payment rows (date, amount, mode, optional reference). Rows are listed newest first with a running total.
  - A **"Fill from schedule"** helper pre-fills one row per installment due up to a chosen date, at its due date and amount. The owner then edits the rows.
  - At most 1,100 rows are allowed.
- [ ] **Validation, blocking save with an inline message:**
  - every amount > ₹0;
  - every payment date within **[disbursedOn, today]**, so no future dates and nothing before disbursement;
  - total collected **< sanctioned** (see open question 2 for the fully repaid case);
  - Disbursed on and First collection date within the limits above;
  - all existing new-loan term validations.
- [ ] Past payments are stored as ordinary, immutable `payment` transactions with their past dates, marked as recorded at onboarding. The contract's running paid total starts at the total collected. Paid, partial and overdue rows are derived by the existing FIFO projection and are never stored.

*"As of today" preview*
- [ ] Before saving, the screen shows a live preview computed by the same projection the app uses after saving:
  - tiles for Collected, Outstanding and Overdue (₹, number of installments, highest days late);
  - the schedule timeline with paid, partially paid, overdue (with "N days late"), due today, upcoming and auto-extension ("Added") rows;
  - the maturity date and cycles n/N.
  
  The preview matches what the contract detail shows after saving, to the paisa.
- [ ] The save button reads **"Onboard loan"** with a summary line ("Outstanding ₹X · N overdue"). Saving **works offline** and confirms with "Saved · will sync". After saving, the app opens the contract detail.

*After onboarding*
- [ ] The contract detail and borrower profile show an "Onboarded {date}" marker and the previous reference, if one was given. Onboarding payments are labelled "Recorded at onboarding" (itemised) or "Opening balance" (opening total) in the ledger and recent receipts. The receipt-share action is not offered for them.
- [ ] Unpaid past installments show as Overdue with days late, in the Overdue tracker, Total overdue, the calendar and the overdue nudge. The shortfall auto-extends at the end, exactly like a loan created in the app.
- [ ] The onboarding payments count as cash on their own dates in Total collected, the collections chart (8W / 6M / 12M), the calendar, collected this month and the borrower's Collected tile. They do **not** add to "Received today" unless a payment is actually dated today.
- [ ] Total net disbursed includes the onboarded loan's net cash. Its disbursement is dated on the original Disbursed on date.
- [ ] New payments, reschedules, rollover, the close-loan chip and the early-closure waiver work on an onboarded loan exactly as on any other loan.
- [ ] An owner can reverse any single onboarding payment with the existing reversal (reason required). The reversal is dated on the original payment's date, so history is corrected in place and today's figures do not go negative. An owner can also reverse a whole opening total in one action ("Reverse opening balance").
- [ ] Every document written stamps `recordedBy`, `recordedByName`, `recordedAt` and `clientRecordedAt`. Every amount and date renders with tabular figures and ₹ Indian grouping. The screen follows the Nordic Ledger tokens and adaptive layout rules on phone and tablet, and survives text scale 1.3×.

**Scope:**

In scope:
- One onboarding screen, two owner entry points, a past-payments section with both modes, the "as of today" preview, and the offline write path.
- Labels and markers on the contract detail, the ledger and receipts.
- Reversal dating for onboarding payments, and the bulk opening-balance reversal.
- Rules and rules tests, plus domain and widget tests.

Out of scope:
- Bulk import from a spreadsheet or CSV. Onboarding is one loan at a time.
- Onboarding a loan that is already fully repaid or closed (see open question 2), and onboarding a past waiver, rollover or reschedule. A past reschedule is entered by choosing the schedule that is actually in force.
- Editing an onboarded loan's terms after saving. As with any loan, corrections are reversals.
- Cancelling or deleting an onboarded contract. No hard deletes; see open question 4.
- Late fees or interest beyond the upfront deduction (unchanged).

**Risks & Dependencies:**
- **Data-entry errors** are the main business risk. A wrong first date or total makes a borrower look overdue when they are not. Mitigations: the preview is shown before saving, payments can be reversed, and there is an onboarded marker for audits.
- **Write size:** a daily loan can have up to 366 installments plus hundreds of past payments, which is more than one Firestore batch. The write must stay consistent if it is split. This is for the Tech Lead.
- **History window:** the dashboard and calendar load closed-loan history for 12 months only. Past payments of an **active** onboarded loan are all loaded and counted in Total collected. The chart and calendar show only the last 12 months, so older onboarding payments appear only in the contract ledger.
- **Trusted devices:** as elsewhere, rules can check role, dates and bounds, but not that the payment amounts add up to the contract total.
- **Depends on** Sprints 5–7 (create contract, payments and reversal, dashboard and calendar). All are passed.

**Open questions for the user** (each with the BA recommendation):
1. **Date of an opening total:** (A) one payment dated on the onboarding day, which spikes Received today, this month and the current chart bar; or (B) spread across the covered installments' due dates? **Recommend B.** It keeps today's figures and past collection rates truthful, and it is labelled "Opening balance".
2. **Fully repaid loans:** if the past payments equal the sanctioned amount, should the app block the save, or onboard the loan and close it immediately (for borrower history and lifetime figures)? **Recommend blocking in this sprint** ("This loan is already fully repaid"). The goal is moving *active* loans, and closing on create adds a second write path. Importing closed loans can be a later request.
3. **How far back:** is **3 years** for Disbursed on enough? **Recommend 3 years.** That covers any running daily, weekly or monthly loan within the 366-installment limit.
4. **Undo a wrong onboarding:** today a mistaken onboarded loan can only be corrected by reversals, and it stays in the books. Should there be an owner "Cancel onboarded loan" (status `cancelled`, excluded from all totals, audit kept), for example within 7 days? **Recommend deferring** and relying on the preview plus reversals. Raise it as a follow-up if owners hit it in practice.
5. **Upfront interest on old loans:** owners may not know the exact upfront figure. Is entering ₹0 acceptable when unknown? Net disbursed then equals sanctioned and inflates Total net disbursed. **Recommend allowing ₹0** with a helper line, "Enter what was deducted at disbursement; ₹0 if none".

**User answers (2026-11-24), first approval gate: plan APPROVED, start Sprint 7b.**
1. Opening total: **spread over the covered installments' due dates**, labelled "Opening balance".
2. Fully repaid loans: **blocked for now**. Collected must be less than sanctioned.
3. How far back: **3 years** (accepted as recommended).
4. Undo a wrong onboarding: **deferred**. Corrections are made by reversals.
5. Upfront ₹0 when unknown: **allowed**, with a helper note.

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
- type: 'disbursement'|'payment'|'rolloverSettlement'|'reversal'|'reschedule'|'waiver' (waiver added 2026-11-23: owner only, amount > 0, note required; counts toward the paid pool P for allocation and closing, but is NOT cash: it is excluded from collected/chart/receipts. Contract gets `totalWaivedPaise: increment(W)` alongside it. A reversal of a waiver decrements `totalWaivedPaise` and reopens the loan)
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

### Addendum 2026-11-24: Onboard an existing loan (Technical Design)
> Filled by: Tech Lead. Requirements: Section 1, "Addendum 2026-11-24: Onboard an existing loan".

**Assumed answers to the open questions** (the design is built on these; changing them changes the noted tasks):
- Q1: the opening total is **spread** across covered due dates (Task 18 `spreadOpeningTotal`).
- Q2: **block** a fully repaid onboarding, so total collected < sanctioned (Tasks 18, 19).
- Q3: **3 years** back (`maxOnboardBackdateDays = 1096`).
- Q4: no cancel.
- Q5: an upfront of ₹0 is allowed. Existing validation already permits it.

If the user picks Q1 = A, `spreadOpeningTotal` is replaced by a single payment dated `onboardedOn`. Nothing else changes.

**Tech Stack Detected:** unchanged (Flutter 3.41 / Dart 3.11, Riverpod code-gen, go_router, freezed, cloud_firestore with offline persistence, Node rules tests with `@firebase/rules-unit-testing` + vitest). No new packages.

**Architecture Decision:**

*1. The core idea: an onboarded loan is an ordinary contract plus ordinary past `payment` transactions, written by the owner in one logical write.* Nothing downstream needs a special case:
- `contract_projection.dart` already FIFO-allocates every payment regardless of date. It marks rows `dueDate < today` and short as `overdue` with `daysOverdue`, and appends auto-extension rows rolled forward to today or later (`_extensionRows`). This holds even when the whole base schedule is in the past.
- `schedule_generator.dart` accepts any `firstDueDate`; past dates are fine.
- `portfolio_metrics.dart`:
  - Net disbursed = Σ `contract.netDisbursed`. This is a lifetime figure, not windowed, so the disbursement's date has no effect on it.
  - Collected, received-today, collected-this-month and the chart all key off `tx.paidOn` of cash transactions, so past payments land on their own dates automatically.
  - The active-transactions listener (`contractActive == true`) has no date filter, so **every** past payment of an active onboarded loan is loaded and counted in Total collected. The chart and calendar show only the 12-month window (`chartWindowStart`), which is expected and documented.
- `computePortfolio`, `contract_projection`, `borrower_summary`, `overdue_tracker` and the calendar need **no formula change**. Task 22 adds regression tests that prove it.

*2. Where backdating is blocked today:* the UI only (see the Section 1 addendum). `LoanTermsController.draft()` hard-codes `disbursedOn: today`, the first-due `DateField` has `first: today`, and the pay sheet allows 30 days back. Validators and rules have no date window. The New loan and Rollover screens **keep** their current limits. Onboarding gets its own controller fields and limits, so no existing flow loosens.

*3. Marking.*
- Contract:
  - `origin: 'standard' | 'onboarded'` (missing means `standard`, via `@Default` + `unknownEnumValue`). `new` is a reserved word in Dart, so the value is `standard`.
  - `onboardedOn: 'yyyy-MM-dd'` (IST today at save).
  - `previousRef: string?` (≤ 40 chars).
- Every transaction written by onboarding (disbursement, payments) and every reversal of one carries `origin: 'onboarding'` (missing means `live`). Opening-total rows also carry `openingBalance: true`.
- Onboarding payments **must carry a `mode`**. `_cashDelta` in `portfolio_metrics.dart:879` treats a reversal with an unknown original and no mode as a waiver reversal (not cash), so a mode-less onboarding payment reversed outside the window would be miscounted. The opening total therefore takes the mode chosen on the form (default `cash`). Rules enforce this (see the rules delta).

*4. Dates and limits* (domain `onboarding.dart`, mirrored in rules with slack for the offline queue):

| Field | Device rule (UI picker + validator) | Rules |
|---|---|---|
| `disbursedOn` | today − 1096 days … today | ≥ request.time − 1275 days (3 y + 180 d slack for a long offline queue); ≤ IST tomorrow (1-day clock-skew tolerance); ≤ `onboardedOn` |
| `firstDueDate` | disbursedOn … disbursedOn + 366 | ≥ disbursedOn and ≤ disbursedOn + 366 d |
| `onboardedOn` | = IST today (not editable) | ≤ IST tomorrow |
| payment `paidOn` | disbursedOn … today | ≥ contract.disbursedOn, ≤ contract.onboardedOn, ≤ IST tomorrow |

*5. Disbursement.* The disbursement tx is dated on the **original `disbursedOn`**, with amount = sanctioned − upfront and `origin: 'onboarding'`. Its effect on Net disbursed is the full net cash, because that KPI is lifetime Σ contract.netDisbursed. No chart or cash figure uses disbursement transactions (`_cashDelta` returns 0), so a past date moves nothing else.

*6. Opening-total spread* (`spreadOpeningTotal`, pure):
- Walk the base schedule rows with `dueDate ≤ today` in `(dueDate, seq)` order. Give each row `min(remaining, amountDue)` as one payment dated on that `dueDate`, until the total is used.
- Any remainder (an advance beyond the dues up to today) is one more payment dated on `max(disbursedOn, last row dueDate ≤ today)`. If no row is due yet, it is dated on `disbursedOn`.
- Every row gets `openingBalance: true`, the chosen mode, and `note: 'Opening balance'`.
- Because FIFO allocation is date-agnostic, this produces exactly the same paid / partial / overdue projection as a single payment, but with truthful dated cash.

*7. Write path: chunk-balanced batches (offline, no transactions).* Each chunk is a `WriteBatch`, and **each chunk balances itself**: the Σ of the payment amounts in a chunk equals the `totalPaidPaise` increment applied in that same chunk.
- **Chunk 1 (always):**
  - the contract;
  - all N base installments (N ≤ 366);
  - the disbursement tx;
  - the company `nextLoanNo: increment(1)`;
  - the first k past payments.
  
  This is 3 + N + k ≤ 450 ops (`maxOpsPerBatch`). The contract is written with a raw-map `set` whose `totalPaidPaise` is `FieldValue.increment(Σk)`. On a new doc this resolves to Σk, so the aggregate is **initialised via increment**, as CLAUDE.md requires. All other fields come from `Contract.toJson()`. `lastPaymentOn` is the latest `paidOn` overall.
- **Chunks 2…m:** up to 449 payments + 1 contract `update {totalPaidPaise: increment(Σchunk), updatedAt}`.
- **Bounds:** at most 1,100 payments and 366 installments, so at most 4 batches. A typical weekly or monthly loan is 1 batch.
- **Commit:** all chunks are committed together, in order, exactly like `ChunkedBatch` (each lands in the offline cache immediately and queues in submission order). The call awaits the server ack with the existing `commitGrace` / `awaitServerAck`.
- **Failure model:** a later chunk can only be rejected if chunk 1 was, because its rules depend on `getAfter(contract)` with `origin == 'onboarded'`. If chunk 1 is rejected, the follow-up `update` fails (no doc) and the onboarding payments fail their rule, so nothing orphaned lands. Even a partial landing keeps the `totalPaidPaise` cache equal to Σ of the landed payments, because each chunk is balanced. The projection remains the source of truth either way.
- **IDs:** all IDs are client uuid v4, generated once when the plan is built. A queued batch retried by the SDK is idempotent. The screen guards against a double tap with `_busy`, as on create.
- **Fully paid:** blocked by the validator and the rules (`totalPaidPaise < sanctionedPaise` on create). That means no close path and no `contractActive` flips are needed.

*8. Reversal.*
- `PaymentRepository.reversePayment` keeps its current shape, with one change: when `original.origin == onboarding`, the reversal's `paidOn` is the **original's `paidOn`** instead of today, and it copies `origin: 'onboarding'`. History is then corrected in place, and Received today or this month do not go negative for a historic correction. Live reversals are unchanged (dated today).
- New `reverseOpeningBalance(ReverseOpeningCommand)` (owner, reason required) reverses every unreversed `openingBalance` tx of the contract. Each chunk holds ≤ 449 reversals plus `totalPaidPaise: increment(−Σchunk)`, and the chunks are balanced as in point 7.
- Double reversal is still blocked through `snapshot.reversedIds`.

*9. Preview equals the saved result.* `OnboardingDraft.preview(today)` builds the **same** `OnboardingPlan` in memory, using a deterministic placeholder id generator, and calls `projectContract(contract, installments, transactions, today)`. The preview tiles and timeline render that `ContractProjection`, the same object the contract detail renders after the save, so the two cannot disagree.

*10. UI and screens.*
- **Route:** `AppRoutes.onboardContractPath = '/contracts/onboard'` (`?borrowerId=`). It is declared **before** `'/contracts/:id'` in `app_router.dart`, like `newContractPath`. It is owner only: a collector gets `_leave('Only owners can onboard loans.')`, mirroring `CreateContractScreen`.
- **Entry points (owner only):**
  1. A `SegmentedToggle` "New loan · Existing loan" at the top of `CreateContractScreen`. "Existing loan" calls `pushReplacement` to the onboard route, carrying `borrowerId`. The onboard screen shows the same toggle with "Existing loan" selected.
  2. A secondary (white, 1px border) "Existing loan" button beside "+ New loan" on `borrower_profile_view.dart`. The dashboard and rail "New loan" entry points reach it through the toggle; no extra FAB.
- **Screen `OnboardContractScreen`** (`lib/features/contracts/presentation/screens/onboard_contract_screen.dart`). It reuses `BorrowerCard`, `LoanAmountFields`, `LoanSummaryCard`, `LoanScheduleFields` (with new `firstDueMin` / `firstDueMax` params; the defaults keep today's behaviour) and `DateField`. Sections follow the Stitch "4. Create New Loan Contract" pattern (label `Step n` + `headlineSm` title):
  1. Borrower.
  2. **Step 1 · Original loan:** sanctioned, upfront (helper "Enter what was deducted at disbursement; ₹0 if none") and the summary card.
  3. **Step 2 · Original dates & schedule:**
     - "Disbursed on" `DateField` (today−1096 … today);
     - frequency, collection day;
     - "First collection date" (disbursedOn … +366);
     - the maturity line.
  4. **Step 3 · Collected so far:**
     - A `SegmentedToggle` with **Opening total · Itemised payments**.
     - **Opening total:** a `CurrencyField` "Already collected" (₹ prefix PJS 600 textSecondary), a `PaymentModeSelector`, and a helper "Spread across N installments due up to today · ₹X advance".
     - **Itemised:** a header row with the running total `MoneyText` vs sanctioned; "+ Add payment" and "Fill from schedule"; and a `ListView.builder` of payment rows (date · mode · amount, tabular), with edit and delete.
     - **Editing a row** opens `PastPaymentSheet` (new) through `AdaptiveSheetPage` / `showAdaptiveSheet` (bottom sheet on compact, 560 dialog on expanded), with a DateField [disbursedOn, today], a CurrencyField, the mode selector and a reference.
     - **"Fill from schedule"** asks for an "up to" date and pre-fills one row per installment due up to it.
     - Switching modes keeps both inputs, but only the selected mode is saved.
  5. **Step 4 · As of today:**
     - three tiles in a `KpiTile` row: Collected (sage), Outstanding, Overdue (terracotta + warning icon + "N installments · highest D days late");
     - the existing `schedule_preview.dart`, extended to render `ProjectedRow`s with `StatusPill`s (Paid, Partially paid, Overdue · N days, Due today, Upcoming, Added with the dashed `DashedBorderCard`);
     - an info note on `primarySubtle`: "Unpaid past installments show as overdue and are added to the end of the schedule."
     
     Status colour is always paired with a label.
  6. **Optional:** previous reference no., guarantor, purpose chips, notes.
  
  - **Sticky footer:** an "Outstanding ₹X · N overdue" `labelLgTabular` line, a primary button **"Onboard loan"**, and "Works offline · syncs automatically".
  - **Layout:**
    - Compact and medium: a single column (`AppSizes.formMaxWidth`).
    - Expanded (`WindowSize.of(context)`, the breakpoint API already used by the create screen, with no raw MediaQuery maths): two columns inside the 1280 max. The form takes 7 of 12 columns, and the "As of today" preview takes 5, sticky at the top-right. On compact the preview stays inline as Step 4.
    - Touch targets ≥ 48dp. Must survive 1.3× text scale.
  - No new tokens are expected. Any that turn out to be needed go into `app_theme.dart`.
- **Stitch:** no onboarding mock exists. The screen is composed from screen 4 (form) and screen 7 (timeline). A Stitch mock is optional and not blocking.
- **After save:**
  - `contract_detail_screen.dart` / `contract_header_card.dart` show a pill "Onboarded {dd MMM yyyy}" (`primarySubtle` + `textSecondary`, history icon) and "Ref {previousRef}".
  - `payment_ledger_list.dart` and the borrower Recent receipts label rows "Opening balance" or "Recorded at onboarding". `receipt_share_panel` is not offered for `origin == onboarding`.
  - An owner-only "Reverse opening balance" overflow action appears on the contract detail when unreversed opening rows exist. It uses the reverse dialog pattern, with the reason required.

*11. Impact check: dashboard, calendar, notifications.*
- **Due vs collected:** chart "due" buckets include the onboarded loan's past installments by `dueDate`, and the spread or itemised payments fill "collected" on their dates, so past collection rates stay realistic.
- **Older history:** rows older than `chartWindowStart` are outside the chart and calendar navigation but count in Total collected. The active listener is unwindowed.
- **History window:** `historyTransactionsProvider` (inactive contracts, `paidOn ≥ since`) is unaffected, because an onboarded loan is active.
- **Overdue:** the Overdue tracker and Total overdue pick up past shortfall immediately. The notification scheduler's overdue nudge includes it on the next run; past rows are never scheduled as reminders.
- **Performance:** a 3-year daily onboarding adds ≤ 1,100 transactions to the active listener. That is within the 100k target. `ProjectionMemo` keeps the cost at one recompute per change.

**Component Breakdown:**

| Component | Responsibility | Owner (skill) | Depends On |
|-----------|---------------|-------|------------|
| Domain: onboarding | model deltas, `onboarding.dart` validators / spread / fill-from-schedule, field names | `kani-orchestrator:role-ui-team` | none |
| Rules: onboarding | contract-create onboarded branch, date helpers, immutability, onboarding-tx owner rule, rules tests | `kani-orchestrator:role-database-admin` | Domain: onboarding (field names) |
| Data: onboarding write | `OnboardContractCommand`, `planOnboarding`, `BalancedChunks`, `onboardContract`, reversal dating, `reverseOpeningBalance` | `kani-orchestrator:role-ui-team` | Domain: onboarding |
| UI: onboarding screen | route, entry points, form, past-payments section, preview, footer, adaptive layout, detail/ledger labels | `kani-orchestrator:role-ui-team` | Data: onboarding write |
| Regression | portfolio / calendar / overdue / reversal tests on onboarded loans | `kani-orchestrator:role-ui-team` | Data: onboarding write |

**API Contracts (if applicable):** no REST API. Internal Dart contracts:

```dart
// lib/domain/ledger/onboarding.dart  (pure Dart)
const int maxOnboardBackdateDays = 1096;   // ~3 years
const int maxFirstDueAfterDisbursalDays = 366;
const int maxPastPayments = 1100;

final class PastPaymentInput {              // also the spread output
  const PastPaymentInput({required this.paidOn, required this.amount,
      required this.mode, this.reference, this.openingBalance = false});
  final CivilDate paidOn; final Money amount; final PaymentMode mode;
  final String? reference; final bool openingBalance;
}

/// Empty = valid. Adds to validateContractTerms: disbursedOn window,
/// firstDue in [disbursedOn, +366], each payment amount > 0 and paidOn in
/// [disbursedOn, today], count ≤ maxPastPayments, Σ < sanctioned
/// ("This loan is already fully repaid…" when Σ == sanctioned).
List<ValidationError> validateOnboarding({
  required List<ValidationError> termErrors, required Money sanctioned,
  required CivilDate disbursedOn, required CivilDate firstDueDate,
  required CivilDate today, required List<PastPaymentInput> payments});

List<PastPaymentInput> spreadOpeningTotal({
  required List<PlannedInstallment> schedule, required Money total,
  required PaymentMode mode, required CivilDate disbursedOn, required CivilDate today});

List<PastPaymentInput> fillFromSchedule({
  required List<PlannedInstallment> schedule, required CivilDate upTo,
  required PaymentMode mode});

// lib/features/contracts/data/contract_repository.dart
final class OnboardContractCommand implements LoanTermsInput { // + cid, borrower, today,
  final List<PastPaymentInput> pastPayments;  // already spread when opening mode
  final String? previousRef;
}
Future<LedgerWriteResult> onboardContract(OnboardContractCommand cmd); // owner; returns contractId

// lib/features/payments/data/payment_repository.dart
Future<PaymentWriteResult> reverseOpeningBalance(ReverseOpeningCommand cmd); // {cid, snapshot, reason, today, actor, role}
```

`planNewContract` gains the optional `origin`, `onboardedOn` and `previousRef` parameters. With them set, the disbursement tx gets `origin: onboarding`. Create and rollover callers are unchanged.

**Data Models (delta only):**

Collection: `companies/{cid}/contracts/{contractId}`
- `origin`: `'standard' | 'onboarded'`. Absent on old docs, read as `standard`. Immutable after create.
- `onboardedOn`: `string 'yyyy-MM-dd'?`. Required when onboarded; IST date of the save; immutable.
- `previousRef`: `string?` (≤ 40). The paper or old-system loan number.
- `totalPaidPaise`: when onboarded, it starts at Σ of chunk 1's payments via `increment` (rules: 0 ≤ value < sanctioned).
- `disbursedOn` / `firstDueDate`: may be in the past when onboarded (windows above).

Collection: `companies/{cid}/transactions/{txId}`
- `origin`: `'live' | 'onboarding'`. Absent means `live`. Set on onboarding disbursement and payments, and on reversals of onboarding txs.
- `openingBalance`: `bool`. Absent means `false`. True on spread opening-total payments.
- Onboarding payments always have `mode`.

Dart: `ContractOrigin { standard, onboarded }` and `TxOrigin { live, onboarding }` in `enums.dart`, serialised lowercase. `Contract` gets `@Default(ContractOrigin.standard) origin`, `CivilDate? onboardedOn` and `String? previousRef`. `LedgerTransaction` gets `@Default(TxOrigin.live) origin` and `@Default(false) bool openingBalance`. Converter round-trip tests cover docs with and without the fields. No new indexes.

**Rules delta (`firebase/firestore.rules`):**
```
// helpers
function civilTs(s) { let p = s.split('-'); return timestamp.date(int(p[0]), int(p[1]), int(p[2])); }
function istNow() { return request.time + duration.value(330, 'm'); }
function notFutureIst(s) { return civilTs(s) <= istNow() + duration.value(1, 'd'); } // 1-day skew tolerance

// contracts: validNewContract(d): replace `d.totalPaidPaise == 0 && isInt(...)` with
   && isInt(d.totalPaidPaise)
   && ((d.get('origin', 'standard') == 'standard' && d.totalPaidPaise == 0
        && d.get('onboardedOn', null) == null)
       || validOnboarded(d))

function validOnboarded(d) {
  return d.origin == 'onboarded'
      && d.get('rolledOverFromContractId', null) == null
      && d.netDisbursedPaise == d.sanctionedPaise - d.upfrontPaise
      && d.totalPaidPaise >= 0 && d.totalPaidPaise < d.sanctionedPaise
      && isCivilDate(d.onboardedOn) && notFutureIst(d.onboardedOn)
      && notFutureIst(d.disbursedOn)
      && civilTs(d.disbursedOn) >= request.time - duration.value(1275, 'd')
      && d.disbursedOn <= d.onboardedOn
      && d.firstDueDate >= d.disbursedOn
      && civilTs(d.firstDueDate) <= civilTs(d.disbursedOn) + duration.value(366, 'd')
      && (d.get('previousRef', null) == null
          || (d.previousRef is string && d.previousRef.size() <= 40));
}
// contracts create stays `owner(cid) && validNewContract(...)`, so an onboarded create is owner only.
// contracts update (owner branch): add 'origin', 'onboardedOn', 'disbursedOn' to the
//   !affectedKeys().hasAny([...]) list. Collector branch is already hasOnly([...]), unchanged.

// transactions create: append
   && (request.resource.data.get('origin', 'live') == 'live'
       || onboardingTx(request.resource.data))
function onboardingTx(d) {
  let c = getAfter(/databases/$(database)/documents/companies/$(cid)/contracts/$(d.contractId)).data;
  return d.origin == 'onboarding'
      && owner(cid)
      && d.type in ['disbursement', 'payment', 'reversal']
      && c.get('origin', 'standard') == 'onboarded'
      && d.paidOn >= c.disbursedOn && d.paidOn <= c.onboardedOn
      && notFutureIst(d.paidOn)
      && (d.type == 'disbursement' || d.get('mode', null) in ['upi', 'cash', 'bank'])
      && d.get('openingBalance', false) is bool;
}
// transactions update stays onlyChanged(['contractActive']), so origin / openingBalance are immutable.
// installments: unchanged (past dueDate already allowed; owner creates base rows).
```
- **Not adopted:** a date window on *live* payments or new contracts. An offline batch rejected at sync is silently dropped from the cache, so tightening existing paths risks losing real collections. This known gap stays the same: live `paidOn` is limited by the UI only.
- **Rules call budget:** member + company + contract (`getAfter`) are 3 distinct docs per evaluation, and repeated lookups of the same doc are de-duplicated within a request. Task 19 must prove that a 450-op chunk-1 batch passes on the emulator.

**Rules tests** (`firebase/test/sprint7b_onboarding.test.js`, roles: owner / collector / other-company owner / signed-out):

| Case | Expected |
|---|---|
| Owner: chunk-1 batch (contract onboarded + 366 inst + disbursement + 81 payments, totalPaid = Σ) | allowed |
| Owner: chunk-2 batch (449 payments + contract increment) | allowed |
| Collector / other-company owner / signed-out: same chunk-1 batch | denied |
| Collector: an `origin: 'onboarding'` payment on an onboarded contract | denied |
| Collector: a live payment on an onboarded contract | allowed (unchanged) |
| Onboarded contract with totalPaid == sanctioned; > sanctioned; negative | denied |
| Standard contract with totalPaid > 0, or with onboardedOn set | denied (unchanged guarantee) |
| disbursedOn = IST tomorrow + 1; disbursedOn older than 1275 d; disbursedOn > onboardedOn | denied |
| firstDue < disbursedOn; firstDue > disbursedOn + 366 | denied |
| onboardedOn in the future (> tomorrow) | denied |
| Onboarding payment: paidOn < disbursedOn; > onboardedOn; future; missing mode; on a `standard` contract | denied |
| Onboarding reversal by owner dated at original paidOn | allowed; by collector, denied |
| Owner update changing `origin` / `onboardedOn` / `disbursedOn` | denied |
| Update of `origin` / `openingBalance` on a tx | denied |
| Every existing test in `rules.test.js`, `sprint5_*`, `sprint6_*`, `tester_*` | still passes |

**Non-Functional Requirements:**
- **Security.**
  - Owner only, in three places: the UI (`currentRoleProvider`), the repository (`cmd.role != owner` gives `PermissionDeniedFailure`) and the rules (above).
  - Inputs are validated in the domain and again in the rules.
  - Accepted risk, unchanged: the rules cannot prove Σ payments == totalPaid. Chunk balancing keeps honest clients consistent.
  - `FLAG_SECURE` applies to the screen, as on other balance screens.
- **Error handling.**
  - Inline field errors from `validateOnboarding`, using new `LedgerFields`: `disbursedOn`, `pastPayments`, `openingTotal`, `previousRef`. An error on an itemised row highlights that row.
  - The "fully repaid" error appears under the Collected-so-far total.
  - `permission-denied` maps to `AppFailure`. "Saved · will sync" appears when queued.
- **Performance.**
  - The preview recomputes on every edit. `projectContract` over ≤ 366 rows + ≤ 1,100 payments must stay below 16 ms on a mid-range phone; add a benchmark test, as for portfolio.
  - Itemised rows use `ListView.builder` inside a bounded height, or a sliver.
  - At most 4 batches per onboarding.
- **Data integrity.**
  - No `runTransaction`. All IDs are client uuids. Transactions are append-only.
  - `totalPaidPaise` is only ever changed through `increment`. No paid or status field is stored. Extensions are computed.
  - Every doc is stamped `recordedBy`, `recordedByName`, `recordedAt` (serverTimestamp), `clientRecordedAt` and `deviceId`. "Today" comes from `todayProvider` / `IstClock` only.

**Assignable Tasks:**

| # | Task Name | Owner (skill) | Depends On |
|---|-----------|-------|------------|
| 18 | Domain for onboarding: `ContractOrigin` / `TxOrigin` enums; the `Contract` fields `origin`, `onboardedOn`, `previousRef`; the `LedgerTransaction` fields `origin`, `openingBalance` (freezed + JSON, converter round-trip with and without the fields); `lib/domain/ledger/onboarding.dart` (`PastPaymentInput`, limits, `validateOnboarding`, `spreadOpeningTotal`, `fillFromSchedule`); the new `LedgerFields`; export from `ledger.dart`. 100% branch coverage: windows at their edges, Σ == sanctioned blocked, spread with exact / partial / advance / no row due yet, whole schedule in the past, a projection over spread payments equal to a projection over a single payment | `kani-orchestrator:role-ui-team` | none (Sprints 5–7 passed) |
| 19 | Firestore rules delta (helpers `civilTs` / `istNow` / `notFutureIst`, the `validOnboarded` branch, origin immutability on contract update, the `onboardingTx` rule) plus the `firebase/test/sprint7b_onboarding.test.js` matrix above. The full existing suite must stay green. `firebase deploy --only firestore:rules` is listed as a human step | `kani-orchestrator:role-database-admin` | Task 18 |
| 20 | Data write path: `planNewContract` optional `origin` / `onboardedOn` / `previousRef`; `OnboardingPlan` + `planOnboarding`; `lib/core/firebase/balanced_chunks.dart` (chunk-1 raw-map contract set with `totalPaidPaise: increment(Σ)`, follow-up chunks of ≤ 449 payments + a contract increment, ordered commit, `batchCount`); `ContractRepository.onboardContract` (owner check, `validateOnboarding`, company `nextLoanNo` increment); `reversePayment` dates onboarding reversals at the original `paidOn` and copies `origin`; `PaymentRepository.reverseOpeningBalance` (balanced chunks); `contractActionsProvider.onboard(...)`. Tests with `fake_cloud_firestore`: 1-, 2- and 4-batch plans, Σ chunk payments == Σ increments == totalPaid, unique ids, stamps, mode always present, collector refused | `kani-orchestrator:role-ui-team` | Task 18 |
| 21 | UI:<br>- `OnboardingDraft` (application) with a live `preview(today)` via `planOnboarding` + `projectContract`;<br>- route `/contracts/onboard` declared before `/contracts/:id`;<br>- entry points: the "New loan · Existing loan" toggle on `CreateContractScreen`, and the "Existing loan" button on `borrower_profile_view.dart`, both owner only;<br>- `OnboardContractScreen` (Steps 1–4 + optional, sticky footer, collector `_leave`);<br>- `LoanScheduleFields` first-due min/max params;<br>- `PastPaymentSheet` via `AdaptiveSheetPage`, Fill from schedule;<br>- `schedule_preview.dart` rendering `ProjectedRow` statuses;<br>- expanded 7/5 two-pane;<br>- contract header "Onboarded" pill + Ref;<br>- ledger / receipts labels, receipt share hidden for onboarding txs;<br>- owner "Reverse opening balance" action.<br>Widget tests at compact and expanded widths (form, both modes, validation messages, preview equals detail after save, collector redirect, 1.3× text scale) | `kani-orchestrator:role-ui-team` | Task 20 |
| 22 | Regression on onboarded loans (domain + provider tests). Given an onboarded loan:<br>- Total collected includes all past payments, including any older than 12 months;<br>- the chart buckets and calendar days show the cash on its own dates;<br>- the collection rate stays ≤ 100% with spread;<br>- received today and collected this month are unaffected unless a payment is dated in them;<br>- Total net disbursed includes the net;<br>- overdue tracker / Total overdue / extension rows are correct;<br>- an onboarding reversal moves cash on the original date only, and an opening-balance reversal restores the outstanding;<br>- the notification scheduler includes the overdue nudge and no past reminders.<br>Projection benchmark (≤ 16 ms, 366 rows × 1,100 payments) | `kani-orchestrator:role-ui-team` | Task 20 |

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
| 5 | 10 Borrowers · 11 Contracts (create, detail timeline, reschedule) | `kani-orchestrator:role-ui-team` | 4 | passed | An owner adds borrowers and creates contracts, including offline, with a correct net-disbursed figure and an auto-generated schedule. The owner views the timeline and reschedules an installment. Data syncs to the second device. |
| 6 | 12 Payments, reversal & rollover · 12b Close-loan chip + early-closure waiver (added 2026-11-23) | `kani-orchestrator:role-ui-team` | 5 | passed | Full, partial and advance payments update the schedule. A partial or missed installment shows as overdue and auto-extends at the end. A contract closes at ₹0, including a one-tap "Close loan" and an owner-only early-closure waiver. An owner rolls over a contract with the correct net cash. Excess is flagged after a concurrent offline collection. |
| 7 | 13 Dashboard · 14 Calendar & Overdue tracker | `kani-orchestrator:role-ui-team` | 6 | passed | The dashboard shows the 4 KPIs, the collections chart and the receivable breakdown matching the recorded data. The calendar dots and day lists are correct, and the overdue tracker filters and Call/WhatsApp/Record actions work. |
| 7b | 18 Onboarding domain (models, validators, opening-total spread) · 19 Onboarding rules + rules tests · 20 Onboarding write path (balanced chunks, reversal dating, opening-balance reversal) — added 2026-11-24 | `kani-orchestrator:role-ui-team`, `kani-orchestrator:role-database-admin` | 7 | passed | Verifiable through the automated suites alone (like Sprint 2). The domain tests show a backdated loan's validation windows and the opening-total spread, and a projection with correct paid, partial, overdue and extension rows. The emulator rules tests show an owner's onboarding batches (1 and 2 chunks, 450 ops) are allowed and collector, other-company and out-of-window writes are denied. The `fake_cloud_firestore` tests show Σ payments == Σ increments == totalPaid across 1–4 batches. |
| 7c | 21 Onboard existing loan screen, entry points, preview, labels · 22 Regression on onboarded loans — added 2026-11-24 | `kani-orchestrator:role-ui-team` | 7b | pending | On a device, as owner, onboard a weekly loan disbursed 3 months ago with an opening total, and a daily loan with itemised past payments, both while offline. The "As of today" preview matches the saved contract. Unpaid past installments show overdue with days late and auto-extend. The past cash appears on its own dates in Total collected, the chart and the calendar, without changing Received today. A collector cannot see or open onboarding. Reversing an onboarding payment corrects its original date. |
| 8 | 15 Settings & notifications · 16 Responsive pass | `kani-orchestrator:role-ui-team` | 7, 7c | pending | Settings works end to end (notification prefs, MPIN change, sign out, delete account). Digest, overdue and per-installment local notifications fire and deep-link correctly. Every screen adapts correctly on phone and tablet widths. |
| 9 | 17 Release & Play readiness | `kani-orchestrator:role-ui-team` | 8 | pending | A signed release `.aab` builds with the launcher icon and splash, Google sign-in works in the release build, and the Play publishing checklist is ready for internal-testing upload. |

**Total sprints:** 9 (originally) + 7b and 7c (added 2026-11-24) = 11

**Testing Strategy:** per-sprint

**Chunking notes:**
- Ledger maths (Sprint 2) and security rules (Sprint 3) sit on their own ahead of any feature UI. They are the highest-risk logic, they are fully verifiable through automated tests alone, and every later sprint builds on them.
- Feature sprints pair each data path with its screen, so a human can exercise a real flow on a device at the end of every sprint.
- Release is isolated last, matching the user's "publish to Play is the last step".
- **Onboard an existing loan (added 2026-11-24).** The work runs next, before Sprint 8, so the Sprint 8 responsive pass and notification work also cover the new screen and onboarded overdue items.
  - **Why two sprints, not one:** there are five tasks (18–22), and the per-sprint cap is three. Rather than renumber, the sprints are named **7b** and **7c**. Sprints 8 and 9 keep their numbers, because the Section 4 logs already refer to "Sprint 8".
  - **7b** holds everything verifiable without UI: domain, rules and the write path. This mirrors how Sprints 2 and 3 isolated ledger maths and rules. Inside 7b, Task 18 lands first; Tasks 19 and 20 can then run in parallel, since both need only the field names from 18.
  - **7c** pairs the screen with the regression tests, so the on-device goal is checked against proven metrics.
  - **Sprint 8 dependency:** Sprint 8 now depends on 7c.
  - **Deploy:** the rules must be deployed (`firebase deploy --only firestore:rules`) before 7c's on-device test. Without that, the onboarding batches are rejected at sync.

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

**kani-orchestrator:role-ui-team — Task 10 Borrowers:**

Files created/modified:
- `lib/features/borrowers/data/borrower_repository.dart`: `watchBorrowers` (archived == false, orderBy nameLower), `watchBorrower`, `createBorrower` (uuid v4, nameLower, E.164, client timestamps, one doc write), `updateBorrower`, `archiveBorrower`. Also `WriteOutcome` {synced, queued} and `awaitServerAck`, which uses a 2 s ack grace.
- `lib/features/borrowers/data/contact_launcher.dart`: `tel:` dialer and `wa.me` with a browser fallback. Injectable for tests.
- `lib/features/contracts/data/ledger_snapshot_repository.dart`: the shared read side. It holds the active contracts, installments and transactions listeners, plus on-demand queries: borrower history contracts and transactions, and per-contract contract, installments and transactions.
- `lib/features/contracts/application/ledger_providers.dart`: the three live stream providers, `ProjectionMemo`, `projectionMemoProvider`, `activeProjectionsProvider` and `projectionsByBorrowerProvider`.
- `lib/features/contracts/application/loan_label.dart`: "Loan #04", and the frequency and payment-mode labels.
- `lib/features/contracts/presentation/screens/contract_placeholder_screen.dart`: placeholders for `/contracts/new?borrowerId=`, `/contracts/{id}` and `/contracts/{id}/pay`.
- `lib/features/borrowers/application/borrower_providers.dart`: `borrowersProvider`, `borrowerProvider(id)`, `BorrowerQueryState`, `borrowerItemsProvider`, `borrowerSearchProvider`, the history providers, `borrowerSummaryProvider(id)`, `BorrowerActions` and `contactLauncherProvider`.
- `lib/features/borrowers/application/reminder_message.dart`: the polite WhatsApp reminder text, naming the earliest open installment.
- `lib/domain/ledger/borrower_summary.dart` (exported from `ledger.dart`): pure `Standing`, `contractStanding`, `dueWithinWeek`, `borrowerListStats`, `LedgerEntry` (balance after) and `summarizeBorrower`.
- `lib/core/time/today_provider.dart`: the `Today` notifier (`todayProvider`, `refresh()`, `untilMidnight()`).
- `lib/core/widgets/day_ticker.dart`: refreshes `todayProvider` at IST midnight and on resume. It wraps the home shell.
- `lib/core/validation/borrower_validators.dart`: name 2–80, duplicate-phone lookup and its message.
- `lib/features/borrowers/presentation/screens/borrowers_screen.dart`: the Borrowers tab, using `ListDetailLayout` (40/60 split on expanded, push on compact/medium).
- `lib/features/borrowers/presentation/screens/borrower_profile_screen.dart`: the `/borrowers/{id}` page.
- `lib/features/borrowers/presentation/widgets/`:
  - `borrower_list_pane.dart`: search, filter chips, owner-only "Add borrower", and the empty states.
  - `borrower_row.dart`: a list row, with the selected state shown as a navy 1px border on the pressed tint.
  - `standing_pill.dart`: the status pill.
  - `borrower_profile_view.dart`: the header, tiles, Call/WhatsApp/New loan, the Active/Ledger/Closed toggle and Recent receipts. Owners also get Edit and Archive.
  - `active_contract_card.dart`, `closed_contract_card.dart` and `ledger_entry_tile.dart`.
  - `borrower_form.dart`: an adaptive sheet with the "Saved · will sync" copy.
- `lib/core/routing/app_router.dart`: `AppRoutes.borrower/newContract/contract/recordPayment` and `inCompanyShell()` prefix matching, plus the routes.
- `lib/features/dashboard/presentation/screens/home_screen.dart`: the Borrowers destination is wired, with `DayTicker` around the shell.
- `lib/core/theme/app_theme.dart`: new tokens `AppSizes.avatarLg`, `AppSizes.clearedBarHeight` and `AppInsets.listRow`.
- `android/app/src/main/AndroidManifest.xml`: a `tel` scheme in `<queries>` for Android 11+.
- Tests:
  - `test/domain/ledger/borrower_summary_test.dart` (12);
  - `test/features/borrowers/borrower_test_support.dart`;
  - `borrower_repository_test.dart` (9), `borrower_providers_test.dart` (12) and `borrowers_screen_test.dart` (14);
  - `test/core/routing/onboarding_redirect_test.dart` (+1 test, +1 assertion block);
  - `firebase/test/sprint5_borrowers.test.js` (14).

Key decisions:
- **Writes are offline-tolerant.**
  - A borrower write is one `set`/`update`. It lands in the cache at once and waits at most 2 s for the server ack.
  - On a timeout the result is `queued`, and the snackbar says "Saved · will sync". Otherwise it says "Borrower added" / "Borrower updated" / "Borrower archived".
  - Errors from the rules are mapped to `AppFailure` and shown inline.
- **Client timestamps.** `createdAt`/`updatedAt` come from the clock (`nowIst().toUtc()`), not `serverTimestamp`. The `Borrower` model needs non-null timestamps, and a pending server timestamp reads back as null from the cache.
- **Duplicate phone blocks the save.** Uniqueness within the company is checked on the client against the cached non-archived list. It shows a terracotta warning ("This mobile is already saved for {name}.") and disables Save. Rules can't enforce uniqueness, so a concurrent offline duplicate is still possible.
- **History queries need no new index.**
  - `contracts` uses `borrowerId == x && status in [closed, rolledOver]`, which is covered by the existing (status, borrowerId) index.
  - `transactions` uses `borrowerId == x && contractActive == false` (equality-only merge).
  - Active-contract transactions come from the live listener, so they are not read twice.
- **Aggregates:**
  - exposure = Σ projection outstanding;
  - lifetime lent = Σ sanctioned of all known contracts, excluding cancelled ones;
  - collected = Σ payment − Σ reversal of payments (the same rule as portfolio metrics);
  - "Bal ₹X" = sanctioned − running paid pool (payment + settlement − reversal) per contract, floored at 0;
  - reschedule audit rows are left out of the ledger, which lists newest first.
- **Status:** Overdue Nd (terracotta) beats Due today (amber), which beats On track (sage), then "No active loan". "Due this week" means an open installment due today through today + 6, not counting overdue rows.
- **Memoisation.** `ProjectionMemo` compares the contract doc, its installments and its transactions (each sorted by id, compared by value) and `today`. Unchanged inputs return the identical `ContractProjection`. There is one memo per active company. `activeProjectionsProvider` returns `AsyncLoading` while any listener `isLoading`, so a company switch never mixes data from two companies.
- **Day ticker.** The midnight timer and the resume hook live in a widget (`DayTicker`), not in the provider. Widget tests that never mount the shell then have no pending timers.
- **Archive** is owner-only. It is refused while the borrower has active loans, and it needs a confirmation.
- **Copy.** "+ New loan" is shown to owners only. Record ₹X is shown to everyone, since collectors record payments. The Record button sits under "Next ₹X" (full width) so the card survives 1.3× text at 360dp.

Known limitations:
- `firestore.rules` and `firestore.indexes.json` are **unchanged**, so no redeploy is needed. The new rules tests pass against the deployed rules file.
- The "Saved · will sync" path, the `tel:` / `wa.me` launches and the Android 11 `<queries>` were not exercised on a device. The queued path is unit-tested through `awaitServerAck`.
- `/contracts/new`, `/contracts/{id}` and `/contracts/{id}/pay` are placeholders. Task 11 replaces the first two and Sprint 6 the third.
- The closed tab shows sanctioned, paid and disbursed date. It does not show a closed date, because `closedAt` → IST civil date needs the tz database in UI code (left for Task 11's detail screen).
- `ProjectionMemo` compares each contract's lists by value on every snapshot. That is O(docs), and fine at the target scale. It has not been benchmarked separately at 1,000 contracts.
- Stitch HTML for T5 / screen 5 could not be downloaded (auth required). The layout follows the Section 0 inventory and CLAUDE.md tokens.

Verification: `dart run build_runner build` ok; `flutter analyze` no issues; `flutter test` 618/618 (was 570); `cd firebase && npm test` 334/334 (was 320); `flutter build apk --debug` built `build/app/outputs/flutter-apk/app-debug.apk`. Not deployed, not committed.

**kani-orchestrator:role-ui-team — Task 11 Contracts:**

Files created/modified:
- `lib/features/contracts/data/contract_repository.dart` — `createContract` (validate → one batch: contract + N base installments + disbursement tx + company `nextLoanNo: increment(1)`) and `reschedule` (source `rescheduledOutPaise: increment(x)` + `rescheduledToIds: arrayUnion`, new `rescheduled` installment at maxSeq + 1, 0-amount `reschedule` tx with `rescheduleInfo`). `CreateContractCommand`, `RescheduleCommand`, `LedgerActor`, `LedgerWriteResult`.
- `lib/core/firebase/write_outcome.dart` — `WriteOutcome` + `awaitServerAck` moved here from the borrower repository (re-exported there, so existing imports still work).
- `lib/features/contracts/application/contract_draft.dart` — pure `ContractDraft` (live upfront / net / effective bps / cycles / errors / schedule), `defaultFirstDue`, `parsePercentBps`, `formatBpsPercent`.
- `lib/features/contracts/application/contract_providers.dart` — `contractRepositoryProvider`, per-contract `contractDoc/Installments/Transactions` streams, `contractViewProvider(id)` (projection + docs + row settlements, any status), `TimelineFilter`, `ledgerActorNameProvider`, `ContractActions` (create / reschedule).
- `lib/features/auth/application/device_id_provider.dart` — per-install uuid in secure storage, stamped as `deviceId`.
- `lib/domain/ledger/row_settlement.dart` (exported) — `rowSettlements`: cleared date + mode of each paid row (FIFO replay, reversals un-clear). `validators.dart`: `validateReschedule` + `LedgerFields.newDueDate`.
- `lib/features/contracts/presentation/screens/create_contract_screen.dart` — `/contracts/new?borrowerId=` (owner only).
- `lib/features/contracts/presentation/screens/contract_detail_screen.dart` — `/contracts/{id}`; two panes (40/60) on expanded.
- `lib/features/contracts/presentation/widgets/` — `borrower_card.dart`, `borrower_picker_sheet.dart`, `loan_summary_card.dart`, `collection_day_picker.dart`, `date_field.dart`, `schedule_preview.dart`, `contract_header_card.dart`, `ledger_banner.dart`, `installment_row_card.dart`, `dashed_border_card.dart`, `reschedule_sheet.dart`.
- `lib/core/routing/app_router.dart` — real create/detail routes; the create route redirects collectors to `/home`. `/pay` stays a placeholder.
- `lib/core/theme/app_theme.dart` — tokens `AppSizes.formMaxWidth`, `timelineRail`, `dashLength`, `dashGap`.
- `lib/features/borrowers/data/borrower_repository.dart` — uses the moved `write_outcome.dart`.
- Tests: `test/features/contracts/` (`contract_test_support.dart`, `contract_widget_harness.dart`, `contract_repository_test.dart` 3, `contract_repository_reschedule_test.dart` 2, `contract_draft_test.dart` 6, `create_contract_screen_test.dart` 7, `contract_detail_screen_test.dart` 7, `reschedule_sheet_test.dart` 3); `test/domain/ledger/row_settlement_test.dart` (6); `firebase/test/sprint5_contracts.test.js` (15).

Key decisions:
- **loanNo** = cached `company.nextLoanNo + 1` (the company is created with 0), and the same batch increments the counter. The create screen watches `activeCompanyProvider` so the cached value is loaded before submit. Two owners offline can still share a number (known case, Section 2).
- **Stored `firstDueDate`** is the first generated row's date (the anchor-adjusted one), not the raw picker value. Weekday is stored only for weekly and month day only for monthly.
- **Timestamps:** contract / installment `createdAt` and `updatedAt` are client clock instants (same reason as borrowers). Transaction `recordedAt` is `serverTimestamp()` via the codec, and `clientRecordedAt` / `deviceId` / `recordedByName` are stamped.
- **Reschedule validation** is in the domain (`validateReschedule`): 0 < x ≤ the row's unpaid remainder (from the projection), date ≥ today. The audit tx `paidOn` is today. Any stored open row can be moved; the sheet is offered on overdue rows, to owners and collectors.
- **Detail data:** the screen projects from per-contract listeners (`where contractId ==`, single-field, no new index), so closed and rolled-over contracts render too. `activeProjectionsProvider` stays the source for lists and dashboards.
- **Copy:** following CLAUDE.md (no ALL CAPS), "NET CASH HANDOVER", "OUTFLOW" and the "ACTIVE / CLOSED / ROLLED OVER" pill read "Net cash handover", "Outflow ₹X · N × ₹Y" and "Active / Closed / Rolled over". Extension captions are the projection's `sourceLabel` capitalised ("Missed on 28 Nov (Inst. 5)"). The excess banner asks the owner to review and reverse duplicates.
- **Filters:** Missed = overdue rows (incl. partial overdue); Upcoming = due today / upcoming / planned (incl. extensions); Paid = paid. Rescheduled-away rows show only under All. "Maturity" sits on the last row that counts as a cycle.
- **Footer:** "Immediate action · Collect ₹X" uses the overdue shortfall, else what is due today, else shows the next due. Label and button are stacked so 360dp at 1.3× text fits.
- **Collector guard:** a route-level redirect in `app_router.dart` plus an in-screen guard ("Only owners can create loans." then pop / go home). The rules deny it anyway (replayed).

Known limitations:
- `firestore.rules` and `firestore.indexes.json` are **unchanged** (no redeploy). The 15 new replay tests pass against the deployed rules file.
- `/contracts/{id}/pay` is still the placeholder (Sprint 6). "Collect ₹X" and "Record repayment" route there.
- The date pickers (first collection, reschedule) aren't driven in widget tests. The defaults and the validation behind them are tested.
- The "Saved · will sync" path wasn't exercised on a device (fake Firestore acks at once). It shares `awaitServerAck` with borrowers.
- `deviceId` is per installation (secure storage), so a reinstall gets a new id.
- Notifications aren't rescheduled on create / reschedule yet (the scheduler arrives in a later sprint).

Verification: `dart run build_runner build` ok; `flutter analyze` no issues; `flutter test` 653/653 (was 618); `cd firebase && npm test` 349/349 (was 334); `flutter build apk --debug` built `build/app/outputs/flutter-apk/app-debug.apk`. Not deployed, not committed.

**Module Lead — Sprint 5 Review (attempt 1):**
Date: 2026-11-22

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- **Re-ran independently:** `flutter analyze` is clean and `flutter test` passes 653/653. The rules suite reported 349/349, including `sprint5_borrowers.test.js` and `sprint5_contracts.test.js`, which replay the exact client batches. Rules and indexes are unchanged, so there is no redeploy. There are no `print` calls in `lib/`.
- **Create-contract batch matches Section 2 write paths:** the contract (active, totalPaid 0), N base installments, the disbursement transaction (stamped, amount = netDisbursed), and `companies.nextLoanNo: increment(1)`. The reschedule batch matches too: source `rescheduledOutPaise` increment + `rescheduledToIds` arrayUnion, the new `rescheduled` installment, and a ₹0 audit transaction. Both run through `validateContractTerms` / `validateReschedule`.
- **Accepted:**
  - duplicate phone blocks Save; checked against the cached list, so an offline duplicate across two devices remains possible;
  - archive requires no active loans;
  - "Record" is visible to collectors;
  - `WriteOutcome` is shared in `core/firebase/write_outcome.dart`;
  - `deviceIdProvider` uses a per-install uuid in secure storage;
  - copy is sentence case per CLAUDE.md;
  - footer CTAs are stacked to survive 1.3× text at 360 dp.
- **Interfaces for Sprint 6:**
  - `/contracts/{id}/pay` is a placeholder, linked from Collect, Record repayment and the borrower card's Record.
  - The payment repository must reuse `WriteOutcome`, `deviceIdProvider` and `ledgerActorNameProvider`, and stamp transactions the same way.
  - The notification rescheduling hook is pending (Sprint 8).

**Tester — Sprint 5 Results (attempt 1):**

New test files (no production code changed):
- `test/features/borrowers/tester/s5_borrower_search_aggregates_test.dart` (5)
- `test/features/contracts/tester/s5_create_contract_test.dart` (8)
- `test/features/contracts/tester/s5_reschedule_test.dart` (5)
- `test/features/contracts/tester/s5_timeline_test.dart` (2)
- `test/features/contracts/tester/s5_collector_guard_test.dart` (3)
- `firebase/test/tester_s5.test.js` (11, including 3 positive controls, so each denial is shown to come from the rule under test)

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | Search "98450", "+91 98450" and " +91-98450 " | happy | All three find Anita (+919845012890), not Ravi | Same borrower found for all three | pass |
| 2 | Name search "ANITA"; digits "77777" | edge | Case-insensitive match; no match on unrelated digits | As expected | pass |
| 3 | Duplicate phone: 9845012890 / +91 98450 12890 / 098450-12890 against b1 | failure | Each one detected as b1, with message "This mobile is already saved for Anita Sharma." | As expected | pass |
| 4 | Duplicate check when editing b1 itself, or for a different number | edge | null (Save not blocked) | null | pass |
| 5 | Aggregates, 2 active + 1 closed (₹20k with ₹5k paid, ₹10k with ₹2k paid and 31 Oct missed, ₹6k closed) | happy | Exposure ₹23,000; lifetime lent ₹36,000; collected ₹13,000 (disbursement excluded); 2 active, 1 closed; overdue, 7 days | As expected | pass |
| 6 | Create ₹1,00,000 monthly on the 31st from 31 Jan 2025 at ₹30,000 | happy | Stored due dates 31 Jan, 28 Feb, 31 Mar, 30 Apr; amounts 30k/30k/30k/10k; baseInstallmentCount 4; weekday null | As expected | pass |
| 7 | Monthly on the 31st from 31 Jan 2024 (leap year) | edge | 2nd row is 2024-02-29 | 2024-02-29 | pass |
| 8 | 7.5% upfront on ₹1,00,000 | happy | upfront ₹7,500; net ₹92,500 on the contract and on the disbursement tx | As expected | pass |
| 9 | Flat upfront = sanctioned | failure | ValidationFailure(upfrontInput); no contract/installment/tx written; nextLoanNo stays 3 | As expected | pass |
| 10 | 100% upfront | failure | Rejected, nothing written | As expected | pass |
| 11 | Daily ₹1 on ₹367 (367 installments) | failure | ValidationFailure(installmentCount); nothing written | As expected | pass |
| 12 | Daily ₹1 on ₹366 | edge | Allowed; 366 installments | 366 rows | pass |
| 13 | Monthly with no preferred day | failure | Rejected | Rejected | pass |
| 14 | Missed fixture (₹30k weekly ₹10k, ₹4k paid, today 14 Nov) | happy | Inst 1 unpaid ₹6,000; outstanding ₹26,000 | As expected | pass |
| 15 | Reschedule ₹6,001 of a ₹6,000 unpaid remainder | failure | ValidationFailure; source untouched; no new row | As expected | pass |
| 16 | Reschedule to yesterday, then to today | failure/edge | Past date rejected; today allowed (4th installment row) | As expected | pass |
| 17 | After rescheduling missed inst 2 (₹10k) to 25 Nov | happy | Outstanding and totalPaid unchanged; non-extension rows sum to ₹30,000; one fewer extension row; overdue ₹6,000 | As expected | pass |
| 18 | Partial reschedule of inst 1's ₹6,000 shortfall | edge | Outstanding ₹26,000; overdue ₹10,000 (inst 2 only) | As expected | pass |
| 19 | Timeline: missed fixture (nothing paid, today 14 Nov) | happy | "Installment 4 · Added" and "Installment 5 · Added" shown; no 6 | As expected | pass |
| 20 | Timeline when today = first due date | edge | No "· Added" rows | None | pass |
| 21 | Real app router: collector navigates to /contracts/new?borrowerId=b1 | failure/auth | Redirected to HomeScreen; CreateContractScreen never built | As expected | pass |
| 22 | Real app router: owner navigates to /contracts/new | happy | CreateContractScreen opens | Opens | pass |
| 23 | In-screen guard: collector on CreateContractScreen (router without redirect) | failure/auth | Leaves to /home with "Only owners can create loans." | As expected | pass |
| 24 | Rules: control, owner create batch | happy | Allowed | Allowed | pass |
| 25 | Rules: collector create batch | auth | Denied | Denied | pass |
| 26 | Rules: totalPaidPaise = 1 at create | failure | Denied | Denied | pass |
| 27 | Rules: owner updates an installment's amountDuePaise | failure | Denied | Denied | pass |
| 28 | Rules: control, reschedule batch with audit amount 0 | happy | Allowed | Allowed | pass |
| 29 | Rules: reschedule audit tx with amount 5 | failure | Denied | Denied | pass |
| 30 | Rules: owner deletes a borrower | failure | Denied | Denied | pass |
| 31 | Rules: collector deletes a borrower | failure | Denied | Denied | pass |
| 32 | Rules: control, own collector reads an installment | happy | Allowed | Allowed | pass |
| 33 | Rules: owner/collector of company B reads (get) A's installment | auth | Denied | Denied | pass |
| 34 | Rules: owner of B lists A's installments by contractId | auth | Denied | Denied | pass |

**Bugs Found:**
None.

Observations (not bugs):
- `RescheduleCommand.remaining` is supplied by the caller (the sheet, from the projection). The repository trusts it, and the rules only cap the move at the source's `amountDuePaise`. So a caller passing a stale `remaining` could move an already-paid portion. This is acceptable today because the only caller derives it live.
- Extension rows ("· Added") repeat the overdue shortfall at the end of the schedule by design. Any sum over `rows` must exclude `isExtension` rows. Sprint 7 dashboard/calendar totals should keep this in mind.

**Needs human verification on a device:**
- Offline contract and borrower create ("Saved · will sync"), then sync to a second device.
- The first-collection and reschedule date pickers.
- `tel:` and `wa.me` launches, including the Android 11+ `<queries>`.

**Verification:** `flutter analyze` no issues; `flutter test` 676/676 (was 653, +23); `cd firebase && npm test` 360/360 (was 349, +11). Not deployed, not committed.

**Sprint Test Summary:** 34 passed, 0 failed.

**kani-orchestrator:role-ui-team — Sprint 5 fix (attempt 2): false member-removal after register:**

Files created/modified:
- `lib/features/company/application/member_access_monitor.dart` — new. `watchMemberAccess()` applies the conservative removal rule, re-attaches with backoff (1/2/4/8/16/30 s), and defines `MemberWatch` (`member` + `removed`).
- `lib/features/company/application/company_providers.dart` — new providers `serverConfirmedMembers` (session set), `memberRetryBackoff` and `PendingRegistrations`. `activeMemberWatch` uses the monitor and is held back while a register is pending. `CompanyAccessGuard` rewritten: it acts only on a confirmed removal and never deletes membership docs. When the active company drops from the index it acts only if that company was server-confirmed AND a fresh server read says missing or denied. `CompanyActions.registerCompany` de-duplicates in-flight calls and pre-generates the cid.
- `lib/features/onboarding/data/company_repository.dart` — `watchMember` replaced by `watchMemberDoc` (raw `MemberDocEvent`s with `serverConfirmed = !isFromCache && !hasPendingWrites`, permission-denied becomes `MemberDocDenied`). Added `fetchMemberDocFromServer` (returns null when unknown). **`deleteOwnMembership` removed.** `registerCompany` takes an optional `companyId`.
- `lib/features/onboarding/presentation/screens/register_company_screen.dart` — `_busy` is set before validation and before any await, so a double tap is a no-op. After a success, re-submitting goes home and never creates a second company.
- `test/features/company/member_access_test.dart` — new, 14 tests: the pure rule; the guard with a fake member-doc stream (fake_cloud_firestore asserts the membership docs remain); the router with cache-only/pending memberships staying on /home; register de-dup and listener-after-ack; widget double-tap → 1 call.
- `test/features/company/company_providers_test.dart` — updated the tests that encoded the old wrong behaviour:
  - "member doc deleted…" now asserts the membership docs are KEPT;
  - "membership doc deleted by the owner also switches out" is now "owner removeMember (index + member doc)…";
  - new: "index gone but server still has member doc: not a removal".
- `test/features/onboarding/onboarding_repositories_test.dart` — "watchMember emits null…" was replaced by `watchMemberDoc` metadata and `fetchMemberDocFromServer` tests.

Key decisions:
- The repository reports facts; the decision about "removed" needs session history, so it lives in the application layer, as a pure, testable stream function.
- A snapshot carrying pending local writes never counts as server confirmation, even when `isFromCache` is false.
- On register, the member listener attaches only after the batch ack, or after the 8 s offline grace. Until then the role comes from the membership index. Pending local docs already count as memberships, so the router stays on /home.
- On a confirmed removal the app may only do three things: hide the company for the session, show the one-time message, and set the clear-cache flag. The owner's removeMember batch is the only client path that deletes a membership doc. Rules are unchanged.

Known limitations:
- Because the client no longer deletes its own membership doc, removal can go unconfirmed in one case. If a user was removed while the app was closed, the stale `users/{uid}/memberships/{cid}` doc is only deleted when the owner's removeMember batch did it. If it was not deleted, the server never confirms membership in the new session. The company then stays listed, with denied reads and listener retries capped at 30 s, until the user leaves it (Sprint 8). removeMember deletes both docs, so this only arises from manual or partial data.

**Verification (fix attempt 2):** `dart run build_runner build` OK; `flutter analyze` No issues found; `flutter test` 692/692 (was 676, +16); `cd firebase && npm test` 360/360; `flutter build apk --debug --target-platform android-x64` built `build/app/outputs/flutter-apk/app-debug.apk`. Not deployed, not committed.

**Human verification, attempt 1 (2026-11-22): FAILED.**
- **Bug:** registering a company showed "You no longer have access…" and bounced back to Register, and each retry created another company.
- **Root cause:**
  - the member-doc listener got PERMISSION_DENIED before the server had applied the register batch;
  - the removed-member handler treated that as a removal;
  - the handler then **deleted the user's membership docs**.
- **Data repair (user chose "delete all 3, start fresh"):** the orchestrator deleted the 3 duplicate companies and their member docs via admin tools. `user_settings.activeCompanyId` was already null.

**Human verification, attempt 2 (2026-11-23): PASSED** (Reschedule check deferred).
- Live data confirms one company "Kani & CO" and the owner membership is intact. `nextLoanNo` = 2 (two loans created).
- The user verified registration, borrowers, and loan creation with net/effective % and the schedule.
- **Reschedule:** the button shows only on overdue rows, and new loans can't be backdated. The user created a Daily loan to verify Reschedule on the next day.
- The user approved Sprint 5, with Reschedule to be confirmed then. If it fails, the fix is folded into Sprint 6.
- **Open question raised to the user:** should Reschedule also be offered on upcoming rows? Currently it is overdue only, per the requirements.
- **Emulator note:** storage is ~850 MB free. Use the x64-only debug APK. A full reinstall needed an uninstall, which reset the sign-in.

### Sprint 6
**Sprint Goal:** Full, partial and advance payments update the schedule. A partial or missed installment shows as overdue and auto-extends at the end. A contract closes at ₹0. An owner rolls over a contract with the correct net cash. Excess is flagged after a concurrent offline collection.

**kani-orchestrator:role-ui-team — Task 12 Payments, reversal & rollover:**

Files created/modified:
- `lib/features/payments/data/payment_repository.dart` — `ContractSnapshot` (outstanding, reversed ids), `RecordPaymentCommand`, `ReversePaymentCommand`, `PaymentWriteResult` (closed, balanceAfter), `recordPayment` (auto-close and contractActive flips) and `reversePayment` (reopens a closed contract; double reversal blocked).
- `lib/features/rollover/data/rollover_repository.dart` — `RolloverCommand` (implements `LoanTermsInput`) and `rollover`, using `computeRollover` for the quote and `planNewContract` for the new docs.
- `lib/core/firebase/chunked_batch.dart` — `ChunkedBatch`: the atomic ops plus spill ops (contractActive flips), at most 450 per batch, all committed at once.
- `lib/features/contracts/data/contract_repository.dart` — extracted `LoanTermsInput`, `validateCommandTerms`, `NewContractPlan` / `planNewContract` and `optionalText`; `createContract` uses them, with an unchanged batch shape.
- `lib/features/contracts/application/contract_providers.dart` — shared `requireActiveCid` and `readLedgerActor` (ContractActions uses them).
- `lib/features/payments/application/payment_providers.dart` — `paymentRepositoryProvider`, `ContractView.snapshot`, `QuickAmounts`, `validateRecordAmount`, `receiptMessage` and `PaymentActions` (record / reverse).
- `lib/features/rollover/application/rollover_providers.dart` — `rolloverRepositoryProvider` and `RolloverActions`.
- `lib/features/contracts/presentation/widgets/loan_terms_controller.dart`, `loan_amount_fields.dart` and `loan_schedule_fields.dart` — the create-contract term inputs, extracted with the same keys and shared by create and rollover. `create_contract_screen.dart` now uses them.
- `lib/features/payments/presentation/screens/record_payment_sheet.dart` — `RecordPaymentSheet` and `recordPaymentPage` for `/contracts/{id}/pay`.
- `lib/features/payments/presentation/widgets/` — `payment_mode_selector.dart`, `receipt_share_panel.dart`, `payment_ledger_list.dart` and `reverse_payment_dialog.dart`.
- `lib/features/rollover/presentation/screens/rollover_screen.dart` — `/contracts/{id}/rollover`.
- `lib/features/rollover/presentation/widgets/` — `closing_contract_card.dart`, `rollover_settlement_card.dart` and `rollover_link_banner.dart`.
- `lib/core/widgets/adaptive_sheet.dart` — `AdaptiveSheetPage`, a router page that opens as a bottom sheet on compact windows and a 560 dialog on wider ones.
- `lib/core/widgets/currency_field.dart` — `large` option (currencyDisplay digits).
- `lib/core/routing/app_router.dart` — the real `/pay` page and the `/rollover` route, which redirects collectors back to the contract. `AppRoutes.rollover(id)` added.
- `lib/features/contracts/presentation/screens/contract_detail_screen.dart` — the Ledger list with owner Reverse, the rollover link banners, and the excess copy "Excess collected ₹X. Review and reverse the duplicate payment."
- Tests:
  - `test/features/payments/`: `payment_test_support.dart`, `payment_widget_harness.dart`, `payment_repository_test.dart` (6), `payment_reversal_test.dart` (5), `payment_projection_test.dart` (3), `payment_helpers_test.dart` (6), `record_payment_sheet_test.dart` (8), `contract_ledger_test.dart` (5).
  - `test/features/rollover/`: `rollover_repository_test.dart` (5), `rollover_screen_test.dart` (5).
  - `test/features/contracts/contract_detail_screen_test.dart`: the ₹93,000 assertion is scoped to the header card, because the disbursement now also shows in the ledger.
  - `firebase/test/sprint6_payments.test.js` (13).

Key decisions:
- **The repository validates against the device's snapshot.** Commands carry `ContractSnapshot` (contract, installments, transactions from the per-contract listeners) rather than a bare contractId:
  - outstanding = sanctioned − paid pool (payments + settlements − reversals);
  - the docs to flip come from the same snapshot;
  - "already reversed" is checked there.
  
  No server read is needed, so all of it works offline.
- **Auto-close:**
  - only an `active` contract closes;
  - the new payment is written with `contractActive: false` when it closes the loan, and with false on any non-active contract;
  - the money ops (tx + contract update) are always in the first batch;
  - flips spill past 450 ops: a 366-installment close is 2 + 467 ops, so 2 batches.
- **Late payment on `rolledOver`:** accepted without the outstanding cap (excess path), status unchanged, tx `contractActive: false`. The sheet shows "This loan was rolled over…" and "After this: excess of ₹X to review". Closed or cancelled contracts refuse payments.
- **Reversal:**
  - owner only (UI plus rules);
  - a reason is required (stored in `note`); amount = original; `paidOn` = today; mode copied;
  - reopens only a `closed` contract that has a balance again. Reversing a duplicate on a closed contract that is still settled keeps it closed;
  - rolled-over contracts never reopen.
- **Rollover with ₹0 net cash:** no disbursement transaction is written. The rules would allow a 0 disbursement (`nonNeg`), but no cash moves; `netDisbursedPaise: 0` records it. Both variants are replayed against the rules.
- **Rollover dates:** the settlement tx and the new contract's `disbursedOn` are today (IST). The form prefills the old sanctioned, installment, frequency and collection day; the upfront starts empty.
- **Quick amounts:**
  - Full due = the next open row's remainder;
  - Advance = the remainders of the next two open non-extension rows, capped at outstanding (extension rows re-plan overdue money, so they are not double-counted);
  - the amount is prefilled with Full due.
  
  The date picker allows today back to today − 30, never the future. Mode defaults to UPI.
- **Receipt:** sent from the user's phone through the existing `InviteShareService` (`wa.me` / `sms:`), with the exact text "Received ₹X from {borrower} for Loan #N on {d MMM yyyy} via {mode}. Balance: ₹Y. — {Company}".
- **Navigation:** Rollover from the sheet pops the sheet first and then pushes `/rollover`. Replacing a popup page in place left the sheet in the overlay. A successful rollover `pushReplacement`s to the new contract.

Known limitations:
- `firestore.rules` and `firestore.indexes.json` are **unchanged** (no redeploy). The 13 new replay tests pass against the current rules.
- Two devices that both close the same loan offline both flip the docs. That is harmless: the excess shows on the closed contract. A closed contract drops out of the active listeners, so its excess is seen from the contract or borrower history, not the dashboard.
- If follow-up flip batches fail independently (very large contracts only), some old docs keep `contractActive: true`. The projections ignore them, because the contract is not active, but they stay in the active listeners until rewritten.
- The date picker and the WhatsApp / SMS hand-off were not exercised on a device. The launcher URIs are unit-tested.
- Notification rescheduling after a payment or rollover is pending (Sprint 8).

Verification: `dart run build_runner build` ok; `flutter analyze` No issues found; `flutter test` 735/735 (was 692, +43); `cd firebase && npm test` 373/373 (was 360, +13); `flutter build apk --debug --target-platform android-x64` built `build/app/outputs/flutter-apk/app-debug.apk`. Not deployed, not committed.

**Module Lead — Sprint 6 Review (attempt 1):**
Date: 2026-11-23

Checklist:
- [x] Component alignment with tech design
- [x] Interface consistency (API contracts match)
- [x] No hardcoded secrets
- [x] Input validation present
- [x] Error handling at integration points

**Findings:**
- **Re-ran independently:** `flutter analyze` is clean and `flutter test` passes 735/735. The rules suite reported 373/373, with `sprint6_payments.test.js` replaying the collector payment (+ close), owner reversal, rollover and late payment on a rolledOver contract. Rules and indexes are unchanged, so there is no redeploy.
- **Write paths match Section 2:**
  - Payment: one batch with `totalPaidPaise: increment(+amt)`.
  - Reversal: owner only, `reversesTxId`, `increment(−amt)`, reopens if closed; double reversal is blocked by a check against existing `reversesTxId`s.
  - Rollover: old → rolledOver with `increment(oldOutstanding)` and a `rolloverSettlement` transaction; the new contract via the shared builder; disbursement = netCash (skipped when 0); `nextLoanNo` increment.
- **Close/reopen flips** are chunked at 450 ops in follow-up batches. The money fields stay atomic in the first batch, so a partial flip failure can't corrupt balances (projections ignore inactive contracts).
- **Accepted:**
  - net-cash-0 rollover writes no disbursement transaction;
  - payment validation runs against the cached projection (offline-safe);
  - term widgets are shared between create and rollover;
  - `AdaptiveSheetPage` renders a sheet on compact and a 560 dialog on wider screens.
- **Known gap (acceptable for v1, tracked for Sprint 7):** excess on a *closed* contract, e.g. a stale offline payment arriving after closure, shows only on the contract page and in borrower history, not on the dashboard, because closed contracts leave the live snapshot. Sprint 7 could add an "Excess to review" count from a lightweight query, `contracts where status == closed and totalPaidPaise > sanctionedPaise`. That isn't directly expressible in Firestore, so a client check over closed contracts loaded on demand is the likely route. Logged for the Tech Lead.

**Tester — Sprint 6 Results (attempt 1):**

New tests: `test/features/payments/tester/s6_partial_advance_test.dart` (3), `s6_close_reverse_test.dart` (5), `s6_ledger_roles_test.dart` (5), `test/features/rollover/tester/s6_rollover_test.dart` (3), `firebase/test/tester_s6.test.js` (9).

| # | Test Case | Type | Expected | Actual | Result |
|---|-----------|------|----------|--------|--------|
| 1 | ₹1,00,000 weekly ₹10,000: pay ₹6,000 on installment 1 | happy | row 1 partial, outstanding ₹94,000 | as expected | pass |
| 2 | After the due date, then pay ₹4,000 late | edge | extension row ₹4,000 at the end; late ₹4,000 removes it, row 1 paid, no overdue, outstanding ₹90,000 | as expected | pass |
| 3 | Advance ₹30,000 | happy | rows 1–3 paid, next due #4 (21 Nov), outstanding ₹70,000 | as expected | pass |
| 4 | Pay exactly the outstanding (₹40,000 of ₹1,00,000 remaining) | happy | closed, closedAt set, contractActive false on every installment and transaction | as expected | pass |
| 5 | Pay ₹40,001 (above the outstanding) | failure | ValidationFailure, nothing written | as expected | pass |
| 6 | Pay ₹0 | failure | ValidationFailure | as expected | pass |
| 7 | Reverse the final (closing) payment | happy | reopens: active, closedAt null, docs contractActive true, outstanding ₹40,000 | as expected | pass |
| 8 | Reverse the same payment twice | failure | second is rejected ("already been reversed"), totals unchanged | as expected | pass |
| 9 | Collector on contract detail | auth | no `reverse_*` action anywhere, no Rollover | as expected | pass |
| 10 | Collector on the pay sheet | auth | no Rollover segment or card | as expected | pass |
| 11 | Two "offline" payments from devices A and B exceed the balance | edge | "Excess collected ₹6,000. Review and reverse the duplicate payment." | as expected | pass |
| 12 | Receipt text | happy | contains ₹ amount, borrower, Loan #, date, "Balance: ₹Y", company | as expected | pass |
| 13 | Receipt text with no company | edge | no dangling "—" | as expected | pass |
| 14 | Rollover: ₹18,000 outstanding, new ₹1,00,000 flat ₹7,000 | happy | net ₹75,000 disbursement; old rolledOver + rolledOverToContractId; new has rolledOverFromContractId; old docs inactive | as expected | pass |
| 15 | Rollover with negative net (₹20,000 − ₹7,000 − ₹18,000) | failure | ValidationFailure, nothing written | as expected | pass |
| 16 | Rollover of a closed loan | failure | ValidationFailure | as expected | pass |
| 17 | Rules: control collector payment / owner reversal | happy | allowed | allowed | pass |
| 18 | Rules: collector reversal | auth | denied | denied | pass |
| 19 | Rules: collector decreasing totalPaidPaise (direct update and negative-amount batch) | auth | denied | denied | pass |
| 20 | Rules: payment amount 0 (collector and owner) | validation | denied | denied | pass |
| 21 | Rules: owner reversal without reversesTxId | validation | denied | denied | pass |
| 22 | Rules: collector sets status rolledOver (direct and inside a payment batch) | auth | denied | denied | pass |
| 23 | Rules: editing a payment transaction's amount (owner and collector) | auth | denied | denied | pass |

Full runs: `flutter analyze` no issues; `flutter test` 751/751 (was 735, +16); `cd firebase && npm test` 382/382 (was 373, +9).

**Human verification (on device):** the date picker on the pay sheet (today back to −30 days, no future dates); the WhatsApp / SMS receipt hand-off; two real devices collecting offline at the same time and syncing (excess banner after reconnect).

**Bugs Found:** None.

**Sprint Test Summary:** 25 passed, 0 failed.

**kani-orchestrator:role-ui-team — Task 12b Close-loan chip + early-closure waiver:**

Files created/modified:
- `lib/domain/models/enums.dart` — `TxType.waiver`.
- `lib/domain/models/contract.dart` (+ regenerated `.freezed` / `.g`) — `Money totalWaived` (JSON `totalWaivedPaise`, `MoneyPaiseConverter`, default 0).
- `lib/domain/ledger/contract_projection.dart` — `paidPool` adds waivers (P = payment + rolloverSettlement + waiver − reversal); `waivedTotal()`; `ContractProjection.totalWaived`. `excess` / `outstanding` are unchanged (both still derive from P).
- `lib/domain/ledger/row_settlement.dart` — waivers count when replaying row clearing (a waiver-completed row has a null mode).
- `lib/domain/ledger/portfolio_metrics.dart` — `_cashDelta` returns 0 for a waiver; a reversal of a known waiver already returns 0 (same path as a rolloverSettlement reversal). Added a `totalWaived` portfolio figure (not displayed).
- `lib/domain/ledger/borrower_summary.dart` — a waiver adds to the balance pool but not to `collected`; recent receipts stay payments only.
- `lib/features/payments/data/payment_repository.dart` — `CloseWithWaiverCommand`, `WaiverWriteResult`, `closeWithWaiver` (owner only; cash ≥ 0, W > 0, cash + W == outstanding, reason required, mode required when cash > 0; one batch of payment? + waiver + contract update + chunked flips). `reversePayment` now also reverses a waiver (`totalWaivedPaise: increment(−W)`, `totalPaidPaise` untouched, reopens; the double-reversal block applies).
- `lib/features/payments/application/payment_providers.dart` — `WaiverSplit`, `PaymentActions.closeWithWaiver` (passes `currentRoleProvider`), and `receiptMessage(waived:)`: "Received ₹C from … via Cash. Loan #N closed (₹W waived). — {Company}" (the "Received" sentence is dropped when C = 0).
- `lib/features/payments/presentation/screens/record_payment_sheet.dart` — the 4th chip "Close loan ₹X"; "Confirm & close loan" whenever the amount closes the loan; owner-only "Settle for less (waive the rest)" switch under Close loan, with "Cash received", read-only "Waive ₹W", a required "Reason for waiver", and the preview "Cash ₹C + waived ₹W = closes the loan".
- `lib/features/payments/presentation/widgets/receipt_share_panel.dart` — `waived` ("Loan closed · ₹W waived").
- `lib/features/payments/presentation/widgets/payment_ledger_list.dart` — waiver rows read "Waived ₹W · {reason}" in neutral `textSecondary`, with the owner Reverse action; when reversed, the title and amount are struck through.
- `lib/features/payments/presentation/widgets/reverse_payment_dialog.dart` — "Reverse waiver?" copy.
- `lib/features/contracts/presentation/widgets/contract_header_card.dart` — "Waived ₹W" line when totalWaived > 0.
- `lib/features/borrowers/presentation/widgets/ledger_entry_tile.dart` — the "Waived" label, no sign, `textSecondary`.
- `firebase/firestore.rules` — see the **redeploy** note below.
- Tests:
  - `test/domain/ledger/waiver_ledger_test.dart` (5);
  - `test/features/payments/waiver_repository_test.dart` (8);
  - `test/features/payments/waiver_sheet_test.dart` (7);
  - `firebase/test/sprint6_waiver.test.js` (11);
  - `test/domain/models/models_round_trip_test.dart`: enum list + 'waiver'.

Key decisions:
- **The command carries the snapshot, not a bare contractId.** That matches `RecordPaymentCommand`: outstanding and the flips come from the device's snapshot, so the close works offline. It also carries `role`, so the repository rejects a collector before any write, and the rules deny it as well.
- **The Dart field is `totalWaived`** (JSON `totalWaivedPaise`), following the `totalPaid` / `totalPaidPaise` convention.
- **Waiver tx:**
  - `paidOn` is the sheet's collection date (default today), the same as the cash payment;
  - mode is null;
  - `contractActive: false` on both new docs, because the loan closes.
- **Turning the waiver switch on** clears the amount field for the cash actually received. Turning it off restores the full outstanding. Cash ₹0 (a full write-off at close) is allowed, as in the spec (C ≥ 0); no payment doc is written then.
- **Collectors** see the Close loan chip (a full payment), never the switch.

Known limitations:
- **REDEPLOY REQUIRED** (`firebase deploy --only firestore:rules`). Until then, every waiver write is denied by the live rules. Contract creation stays compatible: the app now sends `totalWaivedPaise: 0` and the old create check has no key whitelist. The changes:
  1. contract create: `totalWaivedPaise` must be absent or int 0;
  2. contract owner update: `totalWaivedPaise` must be ≥ 0. The collector branch's `onlyChanged` list is unchanged, so collectors can never touch it;
  3. `txTypes()` gains `'waiver'`. It is owner only, because the non-owner create clause still only admits payment / reschedule;
  4. `validNewTx`: a waiver needs amount > 0 and a non-empty string `note`.
- **A reversal whose original is outside the loaded transactions window counts as a payment reversal** in cash metrics (existing behaviour). A waiver reversal far from its waiver would understate cash there. Contract-level figures are unaffected.
- The "Waived" portfolio figure is computed but not shown yet, per the spec.

Verification:
- `dart run build_runner build` ok;
- `flutter analyze`: No issues found;
- `flutter test`: 771/771 (was 751, +20);
- `cd firebase && npm test`: 393/393 (was 382, +11);
- `flutter build apk --debug --target-platform android-x64` built `build/app/outputs/flutter-apk/app-debug.apk`.

Not deployed, not committed.

**Module Lead — Sprint 6 Task 12b Review (attempt 1):**
Date: 2026-11-23

- Re-ran independently: `flutter analyze` is clean, `flutter test` passes 771/771 and `npm test` passes 393/393.
- Checklist: the design aligns, the interfaces are consistent, there are no secrets or hard-coded tokens, and validation is in both the UI and the repository. Error handling: two gaps, below.
- Verified:
  - the close is offline-safe: one primary batch with only the flips spilling, and no transaction;
  - a waiver reversal decrements only `totalWaivedPaise`, and a double reversal is blocked;
  - the rules' `nonNeg(totalWaivedPaise)` rejects the double-reversal race;
  - there is no collector bypass;
  - waivers are excluded from cash, the calendar, borrower `collected` and receipts.
- **F1 (Major):**
  - The bug: a waiver reversal whose waiver is outside the loaded window is counted as a cash reversal, at `portfolio_metrics.dart:499` and `borrower_summary.dart:222`.
  - The fix: an unknown original with `mode == null` is a waiver reversal, so its cash delta is 0. Payments always carry a mode and reversals copy it.
  - Add a unit test.
- **F2 (Minor):** the payment and the waiver from one close tie on every sort key, so their order falls to the random uuid. The fix is a type rank before the id tie-break (payment first; newest-first list shows the waiver above). It applies in `row_settlement.dart:58`, `borrower_summary.dart:180` and `payment_ledger_list.dart:46-51`. Add a tie test.
- Advisory:
  - **A1:** reversing only the cash part of a waiver close reopens the loan with a standing partial waiver. Add a warning in the reverse dialog, or accept it.
  - **A2:** optionally, enforce in the rules that a waiver goes with `status == closed`, using `getAfter`.
  - **A3:** the "Paid" label should be `totalPaid − totalWaived`.
  - **A4:** a rules redeploy is required.
  - **A5:** add a rules test for an owner update that drives `totalWaivedPaise` below 0.
- **Verdict: CHANGES REQUESTED** (F1, F2).

**Tester — Sprint 6 Task 12b Results (attempt 1):**

New tests:
- `test/features/payments/tester/s6b_waiver_test.dart` (17 + 1 skip);
- `s6b_waiver_sheet_test.dart` (4);
- `firebase/test/tester_s6b.test.js` (11 + 1 skip).

31 cases covered:
- happy paths: cash + waiver close, ₹0 write-off, both receipt texts, chip prefill at 400 and 1024 widths;
- failures: C + W ≠ outstanding, W = 0, blank reason, missing mode, collector or null role, closed or rolledOver contract;
- edges: waiver reversal reopens with totalPaid untouched, double reversal blocked, re-close, portfolio and borrower cash exclude the waiver;
- auth: the collector gets the chip but no switch;
- rules: collector waiver, collector waiver inside a payment batch, note missing or non-string, amount 0 / negative / fractional, immutable waiver, create with totalWaivedPaise ≠ 0, owner update taking it below 0, collector updates.

Full runs: `flutter analyze` is clean, `flutter test` gives 792 passed + 1 skipped, and `npm test` gives 404 passed + 1 skipped.

Bugs Found:
- **Bug 1 (low):** the rules accept a whitespace-only waiver note, because `validNewTx` checks `note.size() > 0`. The fix is `note.trim().size() > 0`.
- **Bug 2 (low):** the payment and waiver from one close sort at random in the borrower ledger, through `_chronological`'s uuid tie-break. This is the same issue as Module Lead F2.

Human verification (on device), after `firebase deploy --only firestore:rules`:
- owner cash + waiver close;
- receipt hand-off;
- offline close + restart + sync;
- collector sees no switch;
- waiver reversal strikes the row and reopens the loan.

Sprint Test Summary: 29 passed, 2 failed (skipped; Bug 1 and Bug 2).

**Fixes for the Module Lead and Tester findings (Task 12b, attempt 2):**
- **F1:** a reversal whose original isn't loaded and that carries no mode is treated as a waiver reversal and moves no cash. Changed in `portfolio_metrics.dart` (`_cashDelta`) and `borrower_summary.dart`.
- **F2 / Bug 2:** a new `lib/domain/ledger/tx_order.dart` adds `compareTxChronological`, which sorts by paidOn → recordedAt → type rank (waiver after payment) → id.
  - It is used by `row_settlement`, `borrower_summary` and `payment_ledger_list` (reversed there, so newest is first and the waiver shows above its cash).
  - The cash now always clears the earlier rows and the waiver clears the tail.
- **Bug 1:** in `firestore.rules`, the waiver note check is now `note.trim().size() > 0`.
- **A3:** the "Paid" figure on the borrower's active-contract card and on the rollover closing card is now `totalPaid − totalWaived`.
- **A5:** already covered by Tester row 30.
- **A1 and A2 accepted for v1:**
  - the owner can reverse the cash leg and the waiver separately;
  - waivers are owner-only and the owner is trusted.
- Test fixtures (`ledger_fixtures.tx` and `txFor`) now give payments and reversals a mode, as real data has. A reversal copies its original's mode.
- New tests in `waiver_ledger_test.dart` (+5):
  - an orphan waiver reversal moves no cash, while an orphan payment reversal still does;
  - same-timestamp tie with both id orders;
  - the id fallback.
- The two skipped Tester tests are un-skipped and pass.
- Verification: `flutter analyze` is clean, `flutter test` passes 798/798 with 0 skipped, and `npm test` passes 405/405 with 0 skipped.
- **Rules deployed 2026-11-23** to `microfinance-loan-mgr` (waiver rules + trim). The debug APK is installed on emulator-5554 and awaiting human verification.

**Human verification (2026-11-23): PASSED.**
- The user verified the early-closure waiver on the emulator and approved Sprint 6.
- The rules are deployed. The debug APK was reinstalled with an uninstall, because the emulator was out of storage, so the user signed in again.
- **Not separately confirmed by the user; carry forward to a later on-device pass:**
  - the pay-sheet date picker range;
  - the WhatsApp / SMS receipt hand-off;
  - two-device offline excess;
  - the collector-device view;
  - the Sprint 5 Reschedule check on the daily loan.

### Sprint 7
**Sprint Goal:** The dashboard shows the 4 KPIs, the collections chart and the receivable breakdown matching the recorded data. The calendar dots and day lists are correct, and the overdue tracker filters and Call/WhatsApp/Record actions work.

**kani-orchestrator:role-ui-team — Task 13 Dashboard:**

Files created/modified:
- `lib/domain/ledger/portfolio_metrics.dart`:
  - `DueRowItem` (borrower id/phone, frequency, status, daysOverdue, cyclesTotal, `remaining`); `TodayDueItem` is now a typedef of it.
  - `TodayDue.collectedCount/pendingCount/progressBps` (capped 0–100%).
  - `CollectionBucket.rateBps` and `SeriesTotals` (sum, rate, peak).
  - `CalendarDay.settled/settledCount/pending/pendingCount` and the dot getters; `CalendarTotals`.
  - `OverdueItem` gains `borrowerId`, `borrowerPhoneE164` and `frequency` (defaulted, so existing callers compile); `severityFor`.
  - `ExcessItem` and `PortfolioMetrics.excessToReview`, `activeContractCount`, `overdueRiskBps`, `overdueLoanCount`, `dueItemsBetween` / `dayItems`.
  - `chartWindowStart(today)` (1st of the month 11 months back).
  - `computePortfolio(historyContracts:)`, an optional parameter (default empty, so earlier behaviour and tests are unchanged).
- `lib/features/contracts/data/ledger_snapshot_repository.dart` — `watchHistoryContracts(cid)` (`status in [closed, rolledOver]`) and `watchHistoryTransactions(cid, since)` (`contractActive == false`, `paidOn >= since`, `orderBy paidOn desc`).
- `lib/features/dashboard/application/portfolio_providers.dart` — `historyWindowStartProvider`, `historyContractsProvider`, `historyTransactionsProvider`, `portfolioProvider` (AsyncValue<PortfolioMetrics>), memoised `collectionsSeriesProvider(period)`, `calendarMonthProvider(y, m)`, `overdueLoansProvider`, `activeProjectionProvider(id)`.
- `lib/features/dashboard/application/dashboard_filters.dart` — `DueTodayFilter`, `filterDueToday`, `wholePercent`, chart period labels.
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — the Dashboard (loading / error / data).
- `lib/features/dashboard/presentation/screens/home_screen.dart` — Dashboard, Calendar and Borrowers wired; Settings stays a placeholder (Sprint 8). Owners get a "New loan" FAB in the expanded rail.
- `lib/features/dashboard/presentation/contact_actions.dart` (`callBorrower`, `whatsAppBorrower` through the existing `ContactLauncher`) and `due_row_status.dart` (pill label / kind / icon, `daysLate`).
- `lib/features/dashboard/presentation/widgets/` — `kpi_grid.dart`, `collections_chart.dart` (+ `niceAxisStep`), `receivable_breakdown_card.dart`, `today_due_card.dart`, `due_today_list.dart`, `due_row_card.dart` (shared with the calendar), `overdue_alert_card.dart`, `excess_review_card.dart`.
- `lib/core/widgets/share_bar.dart` — thin bps bar on the track colour.
- `lib/core/theme/app_theme.dart` — `AppColors.collectedSoft`, `chartDue`, `tooltip`; `AppSizes.chartHeight`, `chartDueBar`, `chartCollectedBar`, `chartAxisReserved`, `chartBottomReserved`, `chartGridLine`, `chartTooltipMaxWidth`, `chartMinLabelSlot`, `legendSwatch`, `chartTouchSlop`, `shareBarHeight`, `calendarCell`, `calendarDayBadge`, `alertBadge`; `AppInsets.tooltip`, `pageBody`.
- `lib/core/time/civil_date.dart` — `civilMonthName`, `civilWeekdayShortName`.
- Tests:
  - `test/domain/ledger/dashboard_views_test.dart` (25): history, excess, calendar, today, series and overdue maths.
  - `test/features/dashboard/dashboard_test_support.dart` and `dashboard_screen_test.dart` (17), at 400 and 1024, plus 1.3× text at 360 / 400 / 1024.
  - `test/core/routing/onboarding_redirect_test.dart` — the placeholder text assertion replaced.

Key decisions:
- **Lifetime KPIs without aggregation queries:**
  - The active listeners only hold active contracts, so the dashboard also listens to the company's closed and rolled-over contracts, plus inactive-contract transactions inside the 12-month chart window.
  - Net disbursed adds the history contracts' `netDisbursed`.
  - Total collected adds each history contract's cached cash, `totalPaid − rolloverSettled` (waivers never touch `totalPaid`). Their windowed transactions are not counted a second time, but they still feed the chart, the calendar, received-today and collected-this-month.
  - Both queries are served by existing indexes: a single-field `in`, and (contractActive ASC, paidOn DESC).
- **Excess to review (Sprint 6 carry-over): done.** `excessToReview` lists:
  - active projections with excess;
  - history contracts whose `totalPaid + totalWaived > sanctioned`.

  The card shows the total and one row per loan, and a row opens the contract, where the owner reverses the duplicate. It is visible to all roles; only owners can reverse.
- **Dedupe.** During a close or reopen, a document can sit in both listeners for a moment. Transactions are deduped by id (the active copy wins), and history contracts whose id is active are ignored in the domain.
- **Chart:**
  - one y-axis in short ₹, with "nice" steps (1 / 2 / 2.5 / 5 × 10ⁿ, minimum ₹1k);
  - due is the neutral `#E5E7EB` rod, collected the sage rod inside it (`groupVertically`); the current period uses `collectedSoft`;
  - 4dp rounded tops, 1dp track gridlines, 12sp tabular labels, every other x label when bars are narrower than 52dp;
  - the tooltip shows "{label} week · Due · Collected (n%)", with ±12dp touch slop;
  - 12M is offered on medium and expanded windows only;
  - the semantics label lists every bucket plus the summary line.

  Negative net-collected periods draw as 0, but the tooltip shows the true value.
- **Receivable breakdown:** three separate labelled rows (sage dot, amber dot, terracotta warning icon), each with ₹, % and a 6dp bar. There is never a stacked bar.
- **Layout:**
  - compact: KPI 2×2, then the overdue alert, excess, chart, breakdown, today card and due list;
  - expanded: KPI 4-up, chart (8) | breakdown (4), due list (8) | today card + alert + excess (4).

  It uses `WindowSize.of` / `tileColumns` (the breakpoint API), not raw MediaQuery maths. "New loan" sits in the header on compact and medium, and in the rail FAB on expanded (owner only).
- **Due today:** the All / Pending / Collected chips show counts. Open rows have Record (`/contracts/{id}/pay`) and Call; collected rows show a "Collected" pill with no actions. Received today counts net cash for the day, including payments for other rows, so the progress bar is capped at 100%.

Known limitations:
- `firestore.rules` and `firestore.indexes.json` are **unchanged**, so no deploy is needed. The new queries use the existing (contractActive, paidOn DESC) index, and the contracts `in` query needs no composite index.
- History contracts are listened to in full, which grows with the book. That is fine at the target scale; materialised summaries remain the Blaze-plan route.
- Inactive-contract transactions older than the 12-month window are not loaded. Lifetime collected still covers them through the contract cache, but calendar navigation stops at the window start.
- The chart tooltip is drawn on the canvas, so the widget test only checks that a tap doesn't throw; the content was not asserted. The deep link `/dashboard?tab=today` is Sprint 8.

Verification: see the end of Task 14.

**kani-orchestrator:role-ui-team — Task 14 Calendar & Overdue tracker:**

Files created/modified:
- `lib/domain/ledger/overdue_tracker.dart` (exported from `ledger.dart`) — `OverdueFilter`, `OverdueLoan`, `groupOverdueByLoan`, `matchesOverdueFilter`, `OverdueSummary.of`.
- `lib/features/calendar/presentation/screens/calendar_screen.dart` — month navigation (back to `chartWindowStart`, forward 12 months), the Month / List toggle, and a grid | day-list split on expanded via `ListDetailLayout`.
- `lib/features/calendar/presentation/widgets/` — `month_grid.dart` (Monday-first, 48dp+ cells, sage / amber / terracotta dots, navy selected circle, outlined today, a spoken summary per cell), `calendar_legend.dart` (Collected / Pending / Overdue chips with the month totals), `day_agenda.dart` (day header with "N collections · ₹X", then `DueRowCard`s).
- `lib/features/overdue/presentation/screens/overdue_screen.dart` — `/overdue`: the totals, All / Critical >3 days / Recent 1–3 days chips with counts, and loan cards. Compact taps open the loan; expanded shows a 40/60 detail pane.
- `lib/features/overdue/presentation/widgets/` — `overdue_summary_cards.dart` (Total overdue + Collection risk %), `overdue_loan_card.dart`, `overdue_actions.dart` (Call / WhatsApp / Record ₹X), `overdue_detail_pane.dart` (missed installments + "Open loan schedule").
- `lib/core/routing/app_router.dart` — `AppRoutes.overdue` (`/overdue`, inside the company shell) and its route.
- Tests: `test/features/calendar/calendar_screen_test.dart` (9) and `test/features/overdue/overdue_screen_test.dart` (9), each at compact and expanded widths and at 1.3× text.

Key decisions:
- **The calendar is row based, so the dots, list and legend agree:**
  - sage = some amount paid on rows due that day (FIFO);
  - amber = open rows not yet late (due today / upcoming / planned);
  - terracotta = overdue rows.

  A partial row counts its paid part as collected and the rest as pending or overdue. Extension rows are included, and rows rescheduled away are excluded. Cash-by-paidOn stays in `CalendarDay.collected` for the dashboard figures.
- **The day list order** is open rows before paid ones, then loanNo, contractId and seq. List mode groups the month's rows by date. On tablets, tapping a date header selects that day in the detail pane.
- **The overdue tracker groups per loan.** It shows one card per contract: Σ shortfall, the highest delay, the oldest scheduled date and the installment count. The severity (critical > 3 days) uses the loan's highest delay. Collection risk = total overdue ÷ sanctioned receivable (one decimal).
- **Actions reuse the Sprint 5 / 6 interfaces:**
  - Call → `ContactLauncher.call` (`tel:`);
  - WhatsApp → `ContactLauncher.whatsApp`, with the existing polite `ReminderMessage` naming the loan's earliest open installment ("₹5,000 for Loan #05 was due on 31 Oct 2023");
  - Record → `/contracts/{id}/pay` (`RecordPaymentSheet`).

  `InviteShareService` was not needed; `ContactLauncher` already wraps `wa.me` / `tel:`.
- The Stitch overdue mock's "Broadcast reminders / Send batch payment links (UPI QR)" block was **not** built. It is borrower SMS / UPI-link copy of the kind CLAUDE.md lists as mock errors, and it isn't in the requirements.

Known limitations:
- `/overdue` is a pushed full screen (no nav rail), reached from the dashboard alert, the overdue KPI and the breakdown link. The notification payload wiring is Sprint 8.
- The expanded overdue detail pane shows the loan's missed installments and actions, not the full contract timeline. "Open loan schedule" pushes `/contracts/{id}`, because the contract screen has its own two-pane layout.
- The `tel:` / `wa.me` hand-offs were not exercised on a device (the launcher URIs are asserted in widget tests).

Verification: `dart run build_runner build --delete-conflicting-outputs` ok; `flutter analyze` No issues found; `flutter test` 858/858 (was 798, +60); `cd firebase && npm test` not run (rules untouched, baseline 405); `flutter build apk --debug --target-platform android-x64` built `build/app/outputs/flutter-apk/app-debug.apk`. New ledger maths has 100% line coverage (`portfolio_metrics.dart`, `overdue_tracker.dart`) in `flutter test --coverage test/domain`. Not deployed, not committed, not installed.


**Module Lead — Sprint 7 Review (attempt 1):**
Date: 2026-11-23

- Re-ran independently: `flutter analyze` is clean and `flutter test` passes 858/858. Rules and indexes are unchanged, and both new listeners are allowed by `allow read: if member(cid)`. They are served by existing or single-field indexes.
- **Verified correct:**
  - lifetime Total collected, with no double count at the active / history boundary;
  - waiver, rollover and reversal cash handling;
  - lifetime net disbursed;
  - the excess-to-review condition;
  - calendar dot and day-list consistency;
  - IST week and month boundaries;
  - the overdue fold and its Critical / Recent filters;
  - chart rules, tokens, adaptive layouts, role gating and the Stitch mock-error exclusions.
- **M1 (Major):** the receivable breakdown `upcoming30` includes extension rows, which double counts overdue money (`portfolio_metrics.dart:694-697`). In the probe the rows summed to 166% of receivable. Fix: skip `row.isExtension`.
- **M2 (Major):**
  - The problem: past chart buckets lose the *due* of closed or rolled-over loans but keep their *collected*, so the rate can go above 100% (`portfolio_metrics.dart:461-473`).
  - The fix: add a `watchHistoryInstallments(cid, since)` listener (contractActive == false, dueDate >= since; existing index) and add its `amountDue − rescheduledOut` into the buckets by `dueDate`.
- **m1:** the calendar legend "Pending" includes extension rows (`:513-521`). Keep the dot, but leave them out of the total.
- **m2:** extension rows show only "Added"; the AC needs "Added · missed/partial on {date}" (`due_row_card.dart:31`).
- **m3:** `StatusPill` labels are not tabular (`status_pill.dart:74`). Add `labelMdStrongTabular`.
- **m4:** the Record button uses the short form "₹5.3k" (`overdue_actions.dart:64`). Use `formatInr`.
- **m5:** `portfolioProvider` drops back to loading on a listener reload (`portfolio_providers.dart:62-70`). Gate on `!hasValue`.
- **n1 (optional):** memoise `dayItems` / `dueItemsBetween`.
- **Verdict: CHANGES REQUESTED** (M1, M2, m1–m5).

**Tester — Sprint 7 Results (attempt 1):**

New tests (test only):
- `test/domain/ledger/tester/s7_dashboard_metrics_test.dart` (17 + 2 skip)
- `test/features/dashboard/tester/s7_tester_support.dart`
- `s7_dashboard_test.dart` (14)
- `test/features/calendar/tester/s7_calendar_test.dart` (10 + 1 skip)
- `test/features/overdue/tester/s7_overdue_test.dart` (7)

45 cases covered:
- **KPIs:** lifetime collected across active, closed, rolledOver and waiver loans with no double count; net disbursed; reversals.
- **Chart:** 8W / 6M / 12M IST boundaries, including a leap February.
- **Breakdown, Due Today and filters.**
- **Calendar:** dots, legend = list, toggle, navigation and empty states.
- **Overdue tracker:** grouping, Critical / Recent, Call / WhatsApp / Record, tablet split.
- **Excess:** duplicate, waiver, late rollover and active cases.
- **Roles and layout:** 360 at 1.3× text and 1024, with no overflow.

Full run: `flutter analyze` is clean; `flutter test` gives 906 passed + 3 skipped.

Bugs Found:
- **Bug 1 (= ML M2):** the chart's Due leaves out closed and rolled-over loans' installments while Collected keeps their cash, so the 8-week rate showed 128% / 217%.
- **Bug 2 (= ML M1 / m1):** "Upcoming 30 days" (and the calendar Pending total) include extension rows; 142% of receivable.
- **Bug 3 (low):** closed and rolled-over loans vanish from past calendar months, with no dots, no rows and legend Collected ₹0.

Observations:
- collectors see Excess to review with owner-only "reverse" copy;
- short-form money in the calendar legend chips ("₹60k") and on the Record button ("₹5k").

Human verification (on device):
- the tel: and wa.me hand-offs;
- the chart tooltip;
- no KPI flicker while a loan closes, online and offline;
- 1.3× text on a 360dp phone;
- the tablet rail FAB.

Sprint Test Summary: 48 passed, 3 failed (skipped; Bugs 1–3).

**Fixes for Module Lead + Tester findings (Sprint 7, attempt 2):**
- **M1 / Bug 2:** "Upcoming next 30 days" now skips extension rows (`row.isExtension`), so overdue + upcoming30 ≤ receivable.
- **m1:** the calendar Pending total skips extension rows. Those rows still add to `pendingCount` (the amber dot) and stay in the day / month lists.
- **M2 / Bugs 1 and 3:**
  - New listener `watchHistoryInstallments(cid, since)`: `contractActive == false`, `dueDate >= since`, `orderBy dueDate`. It is served by the existing (contractActive ASC, dueDate ASC) index and allowed by the member read rule.
  - New `historyInstallmentsProvider`, passed as `computePortfolio(historyInstallments:)`.
  - In the domain, only installments of non-active history contracts are kept (active wins), deduped by id. Rows with an effective due (`amountDue − rescheduledOut`) of 0 are dropped.
  - **Chart:** each history row adds its effective due to its bucket by `dueDate`, so a loan closed in the window no longer pushes the rate above 100%.
  - **Calendar:** history rows are settled rows, with a sage dot and counted in the legend's Collected total.
    - Closed and waiver-closed loans were paid to zero; a rolled-over loan's unpaid rows were settled by the rollover.
    - Day and month lists show them as paid `DueRowItem`s (`contractStatus` set, `isHistory`) with no Record or Call.
    - A rolled-over loan's rows read "Settled by rollover".
- **m2:** `DueRowItem.sourceLabel` carries `ProjectedRow.sourceLabel`. Extension cards read "Added · missed on 31 Oct (Inst. 2)" (or "partial on …").
- **m3:** new `AppTextStyles.labelMdStrongTabular` (also in `tabularStyles`), used by `StatusPill`.
- **m4 / Tester observation:** the overdue Record button ("Record ₹5,000") and the calendar legend chips now use the full `formatInr` form. The legend amount is `Flexible` so long amounts can't overflow. Short form remains only on chart axes.
- **m5:** `portfolioProvider` no longer drops back to loading on a reload.
  - A per-company `PortfolioHolder` (`portfolioHolderProvider`, reset when the active company changes) keeps the last figures.
  - While any input is loading or valueless, the provider returns the held figures. It shows a loading state only before the first figures for the company (including right after a switch, so a stale value never crosses companies).
  - Errors still surface.
- **Collector copy:** `ExcessReviewCard(isOwner:)`. Collectors still see the card, with "Ask an owner to review and reverse the duplicate payment."; owners keep "Open the loan to review and reverse the duplicate payment."
- **n1:** new `dueItemsProvider(from, to)` (memoised family), used by the calendar's day and month lists. The unused `activeProjectionProvider` was removed.
- **Tests:**
  - Un-skipped and renamed (no "BUG" prefix):
    - "Due includes rows of loans closed in the window, so the rate stays within 100%" (now passes `historyInstallments: scheduleFor(closed)`);
    - "Upcoming next 30 days leaves out the auto-extension rows of overdue money";
    - "S7-C10 a closed / rolled-over loan stays on past months" (legend now `₹30,000`).
  - Expectations updated where the fixes legitimately change a figure:
    - dashboard 8W summary: 128% → "100% · ₹45,000 of ₹45,000";
    - 6M summary: "40% · ₹45,000 of ₹1,10,000";
    - `portfolio_metrics_test` upcoming30: ₹91,000 → ₹90,000 (7826 bps);
    - S7-C1 / S7-C2 October: the closed c7 and rolled-over c8 rows now appear, so 24 Oct shows ₹20,000, the legend collected ₹45,000, and the day lists 3 / 4 collections;
    - the S7 legend-equals-lists check skips extensions in Pending;
    - short-form amounts changed to the full form.
  - New tests:
    - `dashboard_views_test.dart` +3: overdue + upcoming30 ≤ receivable with an extension inside 30 days (plus the calendar dot / Pending / source label); a history loan in the window keeps the bucket rate ≤ 100%; history rows on the calendar (settled totals, ordering, `isHistory`, rolled-over status, id dedupe, active wins, effective-due-0 and unknown-contract rows ignored).
    - `test/features/dashboard/portfolio_provider_test.dart` (2): a reload keeps the figures, a company switch goes to loading, and an error surfaces.
    - `dashboard_screen_test.dart` +3: excess copy for owner and for collector, and the "Added · missed on 31 Oct (Inst. 2)" card.
- **Verification:**
  - `dart run build_runner build --delete-conflicting-outputs` ok;
  - `flutter analyze` No issues found;
  - `flutter test` 917/917 with 0 skipped (was 906 + 3 skipped);
  - new ledger maths at 100% line coverage (`portfolio_metrics.dart`, `overdue_tracker.dart`);
  - `flutter build apk --debug --target-platform android-x64` built `build/app/outputs/flutter-apk/app-debug.apk`.
- `firestore.rules` and `firestore.indexes.json` are unchanged, so no deploy is needed; the rules suite was not re-run. Not committed, not deployed, not installed.

**Independent re-run by the orchestrator (attempt 2):** `flutter analyze` is clean and `flutter test` passes 917/917, with 0 skipped. Every tracked change is in Sprint 7 scope.

**Human verification (2026-11-24): PASSED.**
- The user tested on the emulator with two loans:
  - an active daily loan, ₹1,00,000 sanctioned, ₹90,000 net;
  - a closed loan, ₹1,00,000 sanctioned with ₹7,000 upfront, ₹93,000 net.
- The user questioned Net disbursed showing ₹1,83,000. It was explained as the lifetime Σ net disbursed (as specified in Section 1 and Sprint 2 decision #4). The user accepted it ("looks good"), and the tile is unchanged.
- The emulator data partition was enlarged to 8 GB, which wiped it, and the user signed in again.
- Carried forward:
  - the tel: and wa.me hand-offs;
  - the chart tooltip;
  - the 1.3× text check on a real phone;
  - the Sprint 6 carry-forward items.

---

### Sprint 7b

**Sprint Goal:** An owner can onboard an existing, in-progress loan offline: the domain validates the backdated windows and spreads an opening total, the rules accept the owner's chunk-balanced onboarding batches and deny everything else, and the write path keeps Σ payments == Σ increments == totalPaid across 1–4 batches.

**kani-orchestrator:role-database-admin — Task 19 Onboarding rules:**

Files created/modified:
- `firebase/firestore.rules`: adds the IST date helpers `civilTs`, `istNow` and `notFutureIst`; the `validOnboarded` contract-create branch; `origin`, `onboardedOn` and `disbursedOn` immutability on the owner contract update; and the `onboardingTx` transaction rule.
- `firebase/test/sprint7b_onboarding.test.js` (new, 61 tests): the Task 19 matrix. Dates are relative to IST today, so the suite does not age.

Key decisions:
- **Exactly the rules delta in the Technical Design.** Field names and values:
  - contract: `origin: 'standard' | 'onboarded'`, `onboardedOn`, `previousRef`;
  - tx: `origin: 'live' | 'onboarding'`, `openingBalance`.
- **Standard contracts are unchanged.** When `origin` is absent or `'standard'`, a contract still needs `totalPaidPaise == 0` and `onboardedOn` absent or null. Any other `origin` value must pass `validOnboarded`, so unknown values are denied.
- **Onboarded contract create.** Owner only, through the existing `owner(cid)` create gate. It requires:
  - no rollover link;
  - net == sanctioned − upfront;
  - 0 ≤ totalPaid < sanctioned (fully repaid is blocked);
  - `onboardedOn` a civil date, ≤ IST tomorrow;
  - `disbursedOn` ≤ IST tomorrow and ≥ request.time − 1275 days (3 years plus 180 days of offline slack);
  - `disbursedOn` ≤ `onboardedOn`;
  - `firstDueDate` from `disbursedOn` to `disbursedOn` + 366 days;
  - `previousRef` null or a string of ≤ 40 characters.
- **1-day skew tolerance.** `civilTs(s)` is the date's 00:00 on a UTC-labelled scale, and `istNow()` is `request.time` + 330 min on the same scale. `notFutureIst` therefore accepts IST tomorrow and denies the day after.
- **`onboardingTx`.** This branch applies when tx `origin == 'onboarding'`. It requires:
  - an owner;
  - type `disbursement`, `payment` or `reversal`;
  - `getAfter(contract)` with `origin == 'onboarded'`, so a later chunk works once chunk 1 has landed, and is denied if the contract does not exist;
  - `paidOn` within [contract.disbursedOn, contract.onboardedOn] and ≤ IST tomorrow;
  - a `mode` in `upi` / `cash` / `bank`, except on a disbursement;
  - `openingBalance`, if present, a bool.
- **Live txs.** `origin` absent or `'live'` keep every existing rule, and **no date window was added (deliberate)**. One small tightening: a live tx may not carry `openingBalance: true`. This is safe because Dart writes `false` or omits the field.
- **Transaction immutability is already covered.** `origin` and `openingBalance` cannot change because tx update is still `onlyChanged(['contractActive'])`. The collector contract-update branch is `hasOnly`, so it already could not touch the immutable fields.
- **Rules call budget.** The 450-op chunk 1 (contract + 366 installments + disbursement + `nextLoanNo` + 81 payments) passes on the emulator. It touches only three distinct documents: member, company and contract.

Known limitations:
- As before, the rules cannot prove that Σ onboarding payments == `totalPaidPaise`. Chunk balancing on the client keeps honest clients consistent (accepted risk in the design).
- A later-chunk `update` is checked only by the generic owner contract-update branch, which requires totalPaid ≥ 0. It is not re-checked against `< sanctioned`. The domain validator guards this.
- `previousRef` stays editable by an owner after create. The design did not ask for it to be immutable.
- The emulator is lenient about some production limits, so the 450-op budget should be re-checked once on the live project after deploy.

Verification:
- `cd firebase && npm test`: **12 files, 466 tests passed** (baseline 405 + 61 new). All earlier suites are unchanged and green.

**REDEPLOY REQUIRED** (`firebase deploy --only firestore:rules`, a human step that was not run). Until it is deployed, the live rules deny every onboarded contract create, because they still require `totalPaidPaise == 0`. They would also accept onboarding txs without the date and mode checks. Standard create, payment, reversal and rollover writes are compatible both before and after the deploy.

**kani-orchestrator:role-ui-team — Task 18 Onboarding domain:**

Files created/modified:
- `lib/domain/models/enums.dart`: adds `ContractOrigin { standard, onboarded }` and `TxOrigin { live, onboarding }`, both serialised as lowercase names.
- `lib/domain/models/contract.dart`: adds three fields and an `isOnboarded` getter.
  - `origin`: `@Default(standard)`, with `unknownEnumValue: standard`.
  - `onboardedOn`: `CivilDate?`.
  - `previousRef`: `String?`.
- `lib/domain/models/ledger_transaction.dart`: adds two fields and an `isOnboarding` getter.
  - `origin`: `@Default(live)`, with `unknownEnumValue: live`.
  - `openingBalance`: `@Default(false)`.
- `lib/domain/ledger/validators.dart`: adds the new `LedgerFields` `disbursedOn`, `pastPayments`, `openingTotal` and `previousRef`, plus row helpers `pastPayment(i)` (gives `pastPayments.i`) and `pastPaymentIndex(field)`.
- `lib/domain/ledger/onboarding.dart` (new, exported from `ledger.dart`):
  - limits: `maxOnboardBackdateDays` 1096, `maxFirstDueAfterDisbursalDays` 366, `maxPastPayments` 1100, `maxPreviousRefLength` 40;
  - `openingBalanceNote`;
  - `PastPaymentInput`;
  - helpers `earliestOnboardDisbursal`, `latestOnboardFirstDue` and `pastPaymentsTotal`;
  - `validateOnboarding`, `spreadOpeningTotal` and `fillFromSchedule`;
  - `balancedChunkSizes`, the pure chunk planner.
- Generated: `contract.freezed.dart` / `.g.dart` and `ledger_transaction.freezed.dart` / `.g.dart`.
- Tests (new):
  - `test/domain/ledger/onboarding_test.dart` (44 tests);
  - `test/domain/models/onboarding_fields_test.dart` (10 tests): JSON and Firestore-converter round trips with and without the new fields, and unknown enum values.

Key decisions:
- **Deviation: `PastPaymentInput.mode` is `PaymentMode?`, not `PaymentMode`.** This lets a missing mode be a real validation failure ("Choose a payment mode.") instead of something the type system hides, and it lets a Task 21 row editor hold a row with no mode yet. `validateOnboarding` rejects null. `planOnboarding` throws `ArgumentError` if a null mode ever reaches it. Spread and fill always set the mode.
- **Deviation (additive): `validateOnboarding` takes an optional `previousRef`.** It checks the ≤ 40-character limit, so that `LedgerFields.previousRef` has a source.
- **Firestore fields follow the design exactly.**
  - Every contract now writes `origin` (`'standard'` or `'onboarded'`), `onboardedOn` and `previousRef`. A standard contract writes null for the last two, which the Task 19 rules accept.
  - Every tx writes `origin` (`'live'` or `'onboarding'`) and `openingBalance`. A live tx always writes `false`.
  - Old docs without these fields read as `standard` / `live` / `false`.
- **Validation rules.**
  - The windows are inclusive at both edges:
    - `disbursedOn` from today − 1096 to today;
    - `firstDueDate` from `disbursedOn` to `disbursedOn` + 366;
    - each `paidOn` from `disbursedOn` to today.
  - A `firstDueDate` error already reported by the term validator is not repeated.
  - Each row gets at most one error, on the field `pastPayments.i` (checked in this order: amount > 0, mode, before disbursement, future).
  - Σ == sanctioned gives "already fully repaid", and Σ > sanctioned is rejected. These total errors go on `openingTotal` when every row is an opening-balance row, and on `pastPayments` otherwise.
- **The spread follows the design.**
  - It walks the rows due on or before today, in (dueDate, seq) order, and gives each one `min(left, amount)`.
  - The advance is dated on max(disbursedOn, the last such due date), or on disbursedOn when no row is due yet.
  - Every spread row is `openingBalance` and carries the chosen mode.
  - A row that falls due today is covered on today, as the design specifies (`dueDate ≤ today`).
- **Chunk planner.** `balancedChunkSizes` is pure domain code, so the chunk maths can have 100% branch coverage. `BalancedChunks` (Task 20) is a thin Firestore wrapper around it.

Known limitations:
- No helper text ("Spread across N installments · ₹X advance") is pre-built. Task 21 can derive it from the `spreadOpeningTotal` output: the rows plus a trailing advance row.

Verification:
- `flutter test test/domain/ledger/onboarding_test.dart --coverage --branch-coverage`: `onboarding.dart` has **101/101 lines and 43/43 branches** covered (lcov).
- The tests include:
  - the projection over the spread equals the projection over a single payment, for ₹0, partial, exact, advance and ₹99,999 totals;
  - a whole past schedule with overdue rows and extension rows;
  - the 366 + 1,100 worst case gives chunks [81, 449, 449, 121].

**kani-orchestrator:role-ui-team — Task 20 Onboarding write path and reversal:**

Files created/modified:
- `lib/core/firebase/balanced_chunks.dart` (new): `BalancedChunks`.
  - Batch 1 holds the `firstBalance` op, the fixed ops and as many items as fit. Batches 2…m hold the `laterBalance` op and up to `limit − 1` items.
  - Spill ops fill the last batch, then new batches.
  - Getters: `chunkSizes`, `chunkSums`, `batchCount`, `opsPerBatch`.
  - `commit()` commits every batch at once, in order (no transactions).
- `lib/features/contracts/data/onboarding_plan.dart` (new; exported from `contract_repository.dart`):
  - `OnboardContractCommand implements LoanTermsInput`. It adds `role`, `today`, `pastPayments` and `previousRef`.
  - `validateOnboardCommand`.
  - `OnboardingPlan`: `contract`, `installments`, `transactions` and `totalCollected`, plus `chunks(db, cid)`.
  - `planOnboarding`.
- `lib/features/contracts/data/contract_repository.dart`:
  - `planNewContract` gains the optional `origin`, `onboardedOn` and `previousRef`. When onboarded, the disbursement gets `origin: onboarding`. The defaults leave create and rollover unchanged.
  - New `batchLimit` setting.
  - New `onboardContract(cmd)`: owner check, then `validateOnboardCommand`, then `planOnboarding`, then the balanced commit with `awaitServerAck`.
- `lib/features/payments/data/payment_repository.dart`:
  - `reversePayment` dates the reversal on the original's `paidOn` when `original.origin == onboarding`, and copies `origin`. Live reversals are still dated today.
  - New `ReverseOpeningCommand {cid, snapshot, reason, actor, role}` and `unreversedOpeningBalance(snapshot)`.
  - New `reverseOpeningBalance(cmd)` (balanced chunks). It reopens a closed loan and flips `contractActive` back, like `reversePayment`.
  - `_flipActive` now takes a spill callback, so `ChunkedBatch` and `BalancedChunks` share it.
- `lib/features/contracts/application/contract_providers.dart`: `ContractActions.onboard(...)`. Role comes from `currentRoleProvider`, today from `todayProvider`, and the actor from `readLedgerActor`.
- `lib/features/payments/application/payment_providers.dart`: `PaymentActions.reverseOpeningBalance(view, reason)`.
- Tests (new):
  - `test/core/firebase/balanced_chunks_test.dart` (5 tests);
  - `test/features/contracts/onboard_contract_repository_test.dart` (20 tests);
  - `test/features/payments/onboarding_reversal_test.dart` (8 tests).

Key decisions:
- **Chunk 1 writes the contract with a raw-map `set`.** The map is `ModelCodecs.contract.toFirestore(contract)` with `totalPaidPaise: FieldValue.increment(Σ chunk-1 payments)`, so the aggregate is initialised through increment. `lastPaymentOn` is the latest `paidOn` overall.
- **Later chunks.** Each later chunk is `update {totalPaidPaise: increment(Σ chunk), updatedAt}` plus at most 449 payments. Every batch balances itself; the tests check this per batch by object identity.
- **The aggregate op is the first op of every batch.** In batch 1 the contract `set` comes before the installments and payments. In later batches the contract `update` comes first. Firestore ignores order inside a batch, but `fake_cloud_firestore` applies the batches' tasks interleaved, and a later chunk's `update` must never run before the contract exists.
- **Payment order.** Payments are sorted oldest first (a stable sort with an index tiebreak), so batch 1 always carries the oldest cash. All IDs are drawn once in `planOnboarding` with client uuid v4, so a retried batch is idempotent.
- **What every onboarding payment carries:**
  - `origin: 'onboarding'`;
  - the mode;
  - `openingBalance` (true for spread rows, whose `note` is `'Opening balance'`; null note for itemised rows);
  - `recordedBy`, `recordedByName`, `deviceId`, `clientRecordedAt`, and `recordedAt` as serverTimestamp through the converter.
- **Reversals of onboarding payments.** An opening-balance reversal keeps `openingBalance: false`; only the original payment is marked. The reversal copies the original's mode, as the rules require.
- **Deviation:** `ReverseOpeningCommand` has no `today` field. Every reversal is dated on its original's `paidOn`, so `today` would be unused.
- **Owner checks.** A `role` other than owner (collector, or null) gets `PermissionDeniedFailure` in both `onboardContract` and `reverseOpeningBalance`. This mirrors the Task 19 rules.

Known limitations:
- No screen yet; that is Task 21 (Sprint 7c).
  - `OnboardingDraft.preview` should call `planOnboarding` and then `projectContract`. The repository test "preview of the plan equals the saved projection" already proves that equality.
  - `planOnboarding` takes a `Uuid`, so the preview can pass `const Uuid()`, or a deterministic subclass if needed.
- `reversePayment` still does not check the role on the client, as before; the rules enforce owner only. `reverseOpeningBalance` does check it.
- If chunk 1 is rejected at sync, the later chunks fail too, as designed: their rules need `getAfter(contract)`. The SDK drops the rejected writes from the cache. This is the accepted design risk.

Verification:
- `dart run build_runner build --delete-conflicting-outputs`: OK.
- `flutter analyze`: **No issues found.**
- `flutter test`: **1004 passed, 0 failed** (baseline 917 + 87 new).
- The repository tests cover:
  - a weekly opening total (exact docs, nothing dated today, projection: 3 overdue, 35 days late, extension rows);
  - ₹0 collected, and upfront ₹0 (net = sanctioned);
  - a daily loan with 366 rows and 300 itemised payments, giving 2 batches with ops [450, 220];
  - 81, 82, 600 and 1,100 payments, giving 1, 2, 3 and 4 batches, with every batch balanced and Σ payments == Σ increments == `totalPaidPaise`;
  - unique IDs, the stamps, and a mode always present;
  - validation failures that write nothing: a date before disbursedOn, a date after today, a missing mode, total == sanctioned, total > sanctioned, disbursedOn in the future or older than 3 years, first due later than +366 days, and a term error;
  - a collector or a null role refused;
  - an onboarding reversal dated on the original date with `origin` copied, while a live reversal is still dated today;
  - an opening-balance reversal across 3 batches, skipping rows already reversed, reopening a closed loan, owner only with a reason required.
- `cd firebase && npm test` (read-only check): **466/466 passed**. The first run had one failure, `sprint5_borrowers` "owner changing createdAt", which I did not touch; it passed on the immediate rerun, so it looks like a flaky emulator timing issue.


**Module Lead — Sprint 7b Review (attempt 1):**
Date: 2026-11-24

- Re-ran independently:
  - `flutter analyze` is clean;
  - `flutter test` passes 1004/1004;
  - `npm test` passes 466/466.
- The "flaky" `sprint5_borrowers` "owner changing createdAt" test is a test bug that predates 7b: seed and patch use `Timestamp.now()` and can fall in the same millisecond.
- **Deploy order:** safe in both orders for this build.
  - The ad902c6 rules have no key whitelist on contract create or tx create, so the new default fields pass.
  - Old docs read with the defaults.
  - The rules are **mandatory** before any build containing the Task 21 screen. Without them, the old rules would accept a ₹0 onboarding with no date checks.
- **Rules budget:** chunk 1 touches only 3 distinct docs, the same risk as the already-deployed 366-row standard create.
- **Totals:** each batch's increment equals that batch's payments, and the chunk-1 `increment` on the new doc is checked on the post-write value.
- **Spread:** FIFO in integer paise; the remainder becomes an advance row. It matches the user decision.
- **Reversal:** dating on the original date is allowed by `onboardingTx`. `reverseOpeningBalance` is chunked and re-runnable.
- **Live path:** no regressions.
- Findings, all carried into 7c:
  - **M1 (medium):** `batchLimit` can't shrink chunk 1, because installments are fixed ops (`onboarding_plan.dart:153`, `balanced_chunks.dart:83`). Make installments spill ops, then run a production smoke test after the deploy (366-row standard create + daily onboarding).
  - **M2 (medium):** a partial onboarding (chunk n rejected) is silent and can't be repaired. Store immutable `onboardedPaymentCount` / `onboardedTotalPaise`, show "Onboarding incomplete: X of Y synced", and add an owner "Add missing onboarding payment".
  - **L1:** a row due today and the advance are dated today, so they show in Received today. Confirm the behaviour or adjust, and add helper copy in Task 21.
  - **L2:** reversals have no guard for rolledOver / cancelled. Hide the action in Task 21 and/or add a `ValidationFailure`.
  - **L3:** fix the flaky test.
  - **L4 / L5:** info only.
- **Verdict: PASS.**


**Tester — Sprint 7b Results (attempt 1):**

New tests (test only):
- `test/domain/ledger/tester/s7b_onboarding_test.dart` (24)
- `test/features/contracts/tester/s7b_onboard_repository_test.dart` (25)
- `firebase/test/tester_s7b.test.js` (25)

The rules replay mirrors the exact Dart doc key sets and chunk sizes. A shape test fails if the two drift apart.

40 cases covered:
- **Weekly loan:** ₹1,00,000 with a ₹55,000 opening total spread over rows 1–5 plus a ₹5,000 partial on row 6. Nothing is dated today.
- **As of today:** overdue rows 6–10 at 35 / 28 / 21 / 14 / 7 days, and extensions totalling ₹45,000.
- **Dashboard:** KPIs, the chart and the calendar show the cash on its original dates; received today is ₹0.
- **Spread:** projecting the spread equals projecting a single payment of the same total.
- **Daily itemised loans:** 300 payments (2 batches) and 1,100 payments (4 batches), each batch balanced; the preview equals the saved projection.
- **Failures:** every failure case writes nothing. That covers fully repaid, over sanctioned, dates out of range, more than 3 years back, first due out of range, missing mode, `previousRef` over 40 characters, more than 1,100 rows, and a collector or null role.
- **Upfront ₹0:** accepted, with net = sanctioned.
- **Reversals:** a single reversal is dated on the original date. Reverse-opening-balance touches only opening rows, and running it twice is a no-op error.
- **Live payments on an onboarded loan:** recorded normally, and one can close the loan.
- **Backward compatibility:** old docs without the new fields read correctly.
- **Rules replay:** owner allowed; collector, other-company and signed-out denied; `openingBalance` on a live tx denied; immutability enforced.

Full run:
- `flutter analyze`: clean;
- `flutter test`: 1053/1053, 0 skipped;
- `npm test`: 491/491.

Bugs Found: none.

Observations:
- **O1 (= ML L1):** a row due today is spread "on today", so it shows in Received today.
- **O2:** the repository accepts a mixed opening-total + itemised command, so Task 21 must send only the selected mode.
- **O3:** a cosmetic day-name comment is wrong.
- **O4:** known design limits only.

Sprint Test Summary: 40 passed, 0 failed.

**Orchestrator fix:** Module Lead L3. The flaky `sprint5_borrowers` "owner changing createdAt" test now patches with `Timestamp.fromMillis(Date.now() + 60_000)`.

**Sprint 7b: PASSED** (automated-only sprint goal: Module Lead PASS, Tester 40/40; 1053 Flutter, 491 rules). Rules not yet deployed. M1, M2, L1, L2 and O2 are carried into Sprint 7c.

**User decision (2026-11-26), L1 / O1:** the opening-total spread covers only installments due **before** today. Today's installment stays open for live collection, and any advance is dated on the last due date before today (or `disbursedOn`). Do it in Sprint 7c.

---

## 5. Final Review & Full Regression
> Filled by: Module Lead (combined review) + Tester (full feature regression)

_Pending..._

---

## 6. Project Update
> Filled by: Business Analyst (final pass)

_Pending..._
