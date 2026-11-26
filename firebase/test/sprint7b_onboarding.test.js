// Sprint 7b (Task 19) onboarding an existing loan, replayed against the rules
// (emulator only). Payloads follow the Technical Design addendum
// "Onboard an existing loan": contract `origin: 'onboarded'`, `onboardedOn`,
// `previousRef`; tx `origin: 'onboarding'`, `openingBalance`; chunk-balanced
// batches (chunk 1 = contract + installments + disbursement + nextLoanNo +
// first k payments, chunks 2..m = ≤ 449 payments + contract increment).
// Dates are relative to IST today, so the suite does not age.
// Run: `npm test` from firebase/.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'S7B';
const OTHER = 'S7B-OTHER';
const NEW = '7b1c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const ONB = '7b000000-0000-4000-8000-0000000000c1'; // seeded onboarded contract
const STD = '7b000000-0000-4000-8000-0000000000c2'; // seeded standard contract

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => (uid == null
  ? env.unauthenticatedContext().firestore()
  : env.authenticatedContext(uid).firestore());
const p = (col, id) => `companies/${CID}/${col}/${id}`;

// ---------------------------------------------------------------- IST dates

const DAY = 86400000;
const istToday = () => new Date(Date.now() + 330 * 60000).toISOString().slice(0, 10);
const addDays = (civil, n) => new Date(Date.parse(`${civil}T00:00:00Z`) + n * DAY)
  .toISOString().slice(0, 10);
const T = istToday();
const D = (n) => addDays(T, n); // D(-3) = 3 days ago (IST)

// Daily loan: 366 × ₹100, disbursed 400 days ago, first due the next day.
const INST = 10000;
const N_INST = 366;
const SANCTIONED = INST * N_INST;
const DISBURSED = D(-400);
const FIRST_DUE = D(-399);
const dueOn = (seq) => addDays(FIRST_DUE, seq - 1);

// ---------------------------------------------------------------- payloads

// Contract.toJson + the onboarding fields.
const contract = (createdBy, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 7, purpose: null, status: 'active',
  sanctionedPaise: SANCTIONED, upfrontMode: 'flat', upfrontInput: 0, upfrontPaise: 0,
  netDisbursedPaise: SANCTIONED, frequency: 'daily', preferredWeekday: null, preferredMonthDay: null,
  installmentPaise: INST, baseInstallmentCount: N_INST, firstDueDate: FIRST_DUE,
  disbursedOn: DISBURSED, guarantor: null, notes: null, totalPaidPaise: 0,
  lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  origin: 'onboarded', onboardedOn: T, previousRef: 'OLD-0042',
  createdBy, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const standard = (createdBy, over = {}) => contract(createdBy, {
  origin: 'standard', onboardedOn: null, previousRef: null, disbursedOn: T, firstDueDate: D(1),
  ...over,
});
const installment = (contractId, seq, createdBy) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 7, contractActive: true,
  seq, kind: 'base', dueDate: dueOn(seq),
  amountDuePaise: INST, rescheduledOutPaise: 0, rescheduledToIds: [], rescheduledFromId: null,
  createdBy, createdAt: Timestamp.now(), schemaVersion: 1,
});
const tx = (contractId, recordedBy, over = {}) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 7, contractActive: true,
  type: 'payment', amountPaise: INST, paidOn: FIRST_DUE, mode: 'cash', reference: null,
  note: 'Opening balance', reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  origin: 'onboarding', openingBalance: true,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});
// Live (non-onboarding) tx as the Dart side writes it after Task 18.
const liveTx = (contractId, recordedBy, over = {}) => tx(contractId, recordedBy, {
  origin: 'live', openingBalance: false, note: null, paidOn: T, mode: 'upi', ...over,
});

// Chunk 1: contract + installments + disbursement + nextLoanNo + k payments.
const chunk1 = (uid, { k = 3, nInst = N_INST, contractOver = {}, payOver = {}, disbOver = {} } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  const sum = k * INST;
  b.set(doc(f, p('contracts', NEW)), {
    ...contract(uid, { lastPaymentOn: k > 0 ? dueOn(k) : null, ...contractOver }),
    totalPaidPaise: increment(sum),
  });
  for (let seq = 1; seq <= nInst; seq++) {
    b.set(doc(f, p('installments', `${NEW}-i${seq}`)), installment(NEW, seq, uid));
  }
  b.set(doc(f, p('transactions', `${NEW}-d`)), tx(NEW, uid, {
    type: 'disbursement', amountPaise: SANCTIONED, paidOn: DISBURSED, mode: null,
    note: null, openingBalance: false, ...disbOver,
  }));
  b.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
  for (let i = 1; i <= k; i++) {
    b.set(doc(f, p('transactions', `${NEW}-p${i}`)), tx(NEW, uid, { paidOn: dueOn(i), ...payOver }));
  }
  return b.commit();
};

// Chunks 2..m: payments + contract increment (balanced).
const chunkN = (uid, { contractId = ONB, n = 449, start = 1, payOver = {} } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  for (let i = start; i < start + n; i++) {
    b.set(doc(f, p('transactions', `${contractId}-q${i}`)),
      tx(contractId, uid, { amountPaise: 100, paidOn: dueOn(((i - 1) % 300) + 1), ...payOver }));
  }
  b.update(doc(f, p('contracts', contractId)), {
    totalPaidPaise: increment(n * 100), updatedAt: Timestamp.now(),
  });
  return b.commit();
};
const onePayment = (uid, over = {}, contractId = ONB) => chunkN(uid, { contractId, n: 1, payOver: over });

// Single contract create (contract-only rule cases).
const createContract = (uid, data) => setDoc(doc(as(uid), p('contracts', NEW)), data);

// ---------------------------------------------------------------- env + seed

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic',
    firestore: {
      rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
afterAll(async () => { await env?.cleanup(); });

const seed = () => env.withSecurityRulesDisabled(async (ctx) => {
  const f = ctx.firestore();
  const company = (owner) => ({
    name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
    ownerUids: [owner], nextLoanNo: 7, createdBy: owner, createdAt: Timestamp.now(), schemaVersion: 1,
  });
  const member = (uid, role) => ({
    uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
    invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
  });
  await setDoc(doc(f, `companies/${CID}`), company('ravi'));
  await setDoc(doc(f, `companies/${CID}/members/ravi`), member('ravi', 'owner'));
  await setDoc(doc(f, `companies/${CID}/members/meena`), member('meena', 'collector'));
  // zed owns another company and is not a member of CID.
  await setDoc(doc(f, `companies/${OTHER}`), company('zed'));
  await setDoc(doc(f, `companies/${OTHER}/members/zed`), member('zed', 'owner'));
  // Onboarded contract (chunk 1 already landed) with one onboarding payment.
  await setDoc(doc(f, p('contracts', ONB)), contract('ravi', { totalPaidPaise: INST }));
  await setDoc(doc(f, p('transactions', `${ONB}-p1`)), tx(ONB, 'ravi', { recordedAt: Timestamp.now() }));
  // Standard contract.
  await setDoc(doc(f, p('contracts', STD)), standard('ravi'));
});

beforeEach(async () => { await env.clearFirestore(); await seed(); });

// ---------------------------------------------------------------- tests

describe('Sprint 7b: onboarding chunk 1 by role', () => {
  it('owner, chunk 1 (contract + 366 inst + disbursement + 3 payments): allowed', async () => {
    await assertSucceeds(chunk1('ravi'));
  });
  it('owner, full 450-op chunk 1 (366 inst + 81 payments): allowed', async () => {
    await assertSucceeds(chunk1('ravi', { k: 81 }));
  });
  it('owner, opening ₹0 (no payments, totalPaid 0): allowed', async () => {
    await assertSucceeds(chunk1('ravi', { k: 0, nInst: 10 }));
  });
  it('owner, upfront ₹0 / no previousRef: allowed', async () => {
    await assertSucceeds(chunk1('ravi', { k: 1, nInst: 5, contractOver: { previousRef: null } }));
  });
  it('collector, chunk 1: denied', async () => {
    await assertFails(chunk1('meena', { nInst: 5 }));
  });
  it('another company owner, chunk 1: denied', async () => {
    await assertFails(chunk1('zed', { nInst: 5 }));
  });
  it('signed out, chunk 1: denied', async () => {
    await assertFails(chunk1(null, { nInst: 5 }));
  });
});

describe('Sprint 7b: later chunks', () => {
  it('owner, chunk 2 (449 payments + contract increment) on the chunk-1 contract: allowed', async () => {
    await assertSucceeds(chunkN('ravi'));
  });
  it('owner, chunk 1 then chunk 2 in order: allowed', async () => {
    await assertSucceeds(chunk1('ravi', { k: 81 }));
    await assertSucceeds(chunkN('ravi', { contractId: NEW }));
  });
  it('owner, later chunk without chunk 1 (contract missing): denied', async () => {
    await assertFails(chunkN('ravi', { contractId: 'missing-contract', n: 5 }));
  });
  it('collector, later chunk: denied', async () => {
    await assertFails(chunkN('meena', { n: 5 }));
  });
  it('another company owner / signed out, later chunk: denied', async () => {
    await assertFails(chunkN('zed', { n: 5 }));
    await assertFails(chunkN(null, { n: 5 }));
  });
});

describe('Sprint 7b: onboarded contract create validation', () => {
  const ok = (over = {}) => contract('ravi', { totalPaidPaise: 5 * INST, ...over });
  it('owner, valid onboarded contract: allowed', async () => {
    await assertSucceeds(createContract('ravi', ok()));
  });
  it('totalPaid == sanctioned (fully repaid): denied', async () => {
    await assertFails(createContract('ravi', ok({ totalPaidPaise: SANCTIONED })));
  });
  it('totalPaid > sanctioned: denied', async () => {
    await assertFails(createContract('ravi', ok({ totalPaidPaise: SANCTIONED + 1 })));
  });
  it('totalPaid negative: denied', async () => {
    await assertFails(createContract('ravi', ok({ totalPaidPaise: -1 })));
  });
  it('net disbursed != sanctioned − upfront: denied', async () => {
    await assertFails(createContract('ravi', ok({ netDisbursedPaise: SANCTIONED - 1 })));
  });
  it('rolledOverFromContractId set: denied', async () => {
    await assertFails(createContract('ravi', ok({
      rolledOverFromContractId: STD, netDisbursedPaise: SANCTIONED - 100,
    })));
  });
  it('disbursedOn = IST tomorrow (skew tolerance): allowed', async () => {
    await assertSucceeds(createContract('ravi', ok({
      disbursedOn: D(1), firstDueDate: D(2), onboardedOn: D(1),
    })));
  });
  it('disbursedOn = IST tomorrow + 1 (future): denied', async () => {
    await assertFails(createContract('ravi', ok({
      disbursedOn: D(2), firstDueDate: D(3), onboardedOn: D(2),
    })));
  });
  it('disbursedOn 1270 days back (inside 3 y + slack): allowed', async () => {
    await assertSucceeds(createContract('ravi', ok({ disbursedOn: D(-1270), firstDueDate: D(-1269) })));
  });
  it('disbursedOn 1280 days back (beyond 3 y + slack): denied', async () => {
    await assertFails(createContract('ravi', ok({ disbursedOn: D(-1280), firstDueDate: D(-1279) })));
  });
  it('disbursedOn after onboardedOn: denied', async () => {
    await assertFails(createContract('ravi', ok({
      disbursedOn: T, firstDueDate: D(1), onboardedOn: D(-1),
    })));
  });
  it('onboardedOn in the future (> IST tomorrow): denied', async () => {
    await assertFails(createContract('ravi', ok({ onboardedOn: D(2) })));
  });
  it('onboardedOn missing / not a civil date: denied', async () => {
    await assertFails(createContract('ravi', ok({ onboardedOn: null })));
    await assertFails(createContract('ravi', ok({ onboardedOn: '24-11-2026' })));
  });
  it('firstDue before disbursedOn: denied', async () => {
    await assertFails(createContract('ravi', ok({ firstDueDate: addDays(DISBURSED, -1) })));
  });
  it('firstDue = disbursedOn + 366: allowed; + 367: denied', async () => {
    await assertSucceeds(createContract('ravi', ok({ firstDueDate: addDays(DISBURSED, 366) })));
    await env.clearFirestore(); await seed();
    await assertFails(createContract('ravi', ok({ firstDueDate: addDays(DISBURSED, 367) })));
  });
  it('previousRef over 40 chars or not a string: denied', async () => {
    await assertFails(createContract('ravi', ok({ previousRef: 'x'.repeat(41) })));
    await assertFails(createContract('ravi', ok({ previousRef: 42 })));
  });
  it('unknown origin value: denied', async () => {
    await assertFails(createContract('ravi', ok({ origin: 'imported' })));
  });
  it('collector creating a valid onboarded contract: denied', async () => {
    await assertFails(createContract('meena', contract('meena', { totalPaidPaise: INST })));
  });
});

describe('Sprint 7b: standard contracts keep totalPaid == 0', () => {
  it('owner, standard contract (explicit origin standard, totalPaid 0): allowed', async () => {
    await assertSucceeds(createContract('ravi', standard('ravi')));
  });
  it('owner, legacy contract with no origin fields: allowed', async () => {
    const legacy = standard('ravi');
    delete legacy.origin; delete legacy.onboardedOn; delete legacy.previousRef;
    await assertSucceeds(createContract('ravi', legacy));
  });
  it('owner, standard contract with totalPaid > 0: denied', async () => {
    await assertFails(createContract('ravi', standard('ravi', { totalPaidPaise: INST })));
  });
  it('owner, contract without origin and totalPaid > 0: denied', async () => {
    const legacy = standard('ravi', { totalPaidPaise: INST });
    delete legacy.origin;
    await assertFails(createContract('ravi', legacy));
  });
  it('owner, standard contract with onboardedOn set: denied', async () => {
    await assertFails(createContract('ravi', standard('ravi', { onboardedOn: T })));
  });
});

describe('Sprint 7b: onboarding payments', () => {
  it('owner, itemised payment dated disbursedOn / onboardedOn: allowed', async () => {
    await assertSucceeds(onePayment('ravi', { paidOn: DISBURSED, openingBalance: false, note: null }));
    await assertSucceeds(chunkN('ravi', { n: 1, start: 2, payOver: { paidOn: T } }));
  });
  it('paidOn before disbursedOn: denied', async () => {
    await assertFails(onePayment('ravi', { paidOn: addDays(DISBURSED, -1) }));
  });
  it('paidOn after onboardedOn: denied', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), p('contracts', ONB)),
      { onboardedOn: D(-5) }));
    await assertFails(onePayment('ravi', { paidOn: D(-2) }));
  });
  it('paidOn in the future (IST tomorrow + 1): denied', async () => {
    await assertFails(onePayment('ravi', { paidOn: D(2) }));
  });
  it('missing mode (null or absent): denied', async () => {
    await assertFails(onePayment('ravi', { mode: null }));
    const f = as('ravi');
    const b = writeBatch(f);
    const data = tx(ONB, 'ravi');
    delete data.mode;
    b.set(doc(f, p('transactions', 'no-mode')), data);
    b.update(doc(f, p('contracts', ONB)), { totalPaidPaise: increment(INST) });
    await assertFails(b.commit());
  });
  it('unknown mode: denied', async () => {
    await assertFails(onePayment('ravi', { mode: 'cheque' }));
  });
  it('openingBalance not a bool: denied', async () => {
    await assertFails(onePayment('ravi', { openingBalance: 'yes' }));
  });
  it('onboarding payment on a standard contract: denied', async () => {
    await assertFails(onePayment('ravi', { paidOn: T }, STD));
  });
  it('onboarding waiver / reschedule type: denied', async () => {
    await assertFails(onePayment('ravi', { type: 'waiver', mode: null }));
    await assertFails(onePayment('ravi', { type: 'reschedule', amountPaise: 0 }));
  });
  it('collector, onboarding payment on an onboarded contract: denied', async () => {
    await assertFails(onePayment('meena'));
  });
  it('onboarding disbursement on an onboarded contract without mode: allowed for owner', async () => {
    await assertSucceeds(onePayment('ravi', {
      type: 'disbursement', amountPaise: SANCTIONED, mode: null, paidOn: DISBURSED, openingBalance: false,
    }));
  });
});

describe('Sprint 7b: live payments are unchanged', () => {
  const live = (uid, over = {}, contractId = ONB) => {
    const f = as(uid);
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'live-1')), liveTx(contractId, uid, over));
    b.update(doc(f, p('contracts', contractId)), {
      totalPaidPaise: increment(INST), lastPaymentOn: T, updatedAt: Timestamp.now(),
    });
    return b.commit();
  };
  it('collector, live payment on an onboarded contract: allowed', async () => {
    await assertSucceeds(live('meena'));
  });
  it('collector, live payment with no origin fields: allowed', async () => {
    const f = as('meena');
    const data = liveTx(ONB, 'meena');
    delete data.origin; delete data.openingBalance;
    await assertSucceeds(setDoc(doc(f, p('transactions', 'live-2')), data));
  });
  it('collector, live payment with no date window (5 years back): allowed (deliberate)', async () => {
    await assertSucceeds(live('meena', { paidOn: D(-1825) }, STD));
  });
  it('collector, live payment flagged openingBalance: denied', async () => {
    await assertFails(live('meena', { openingBalance: true }));
  });
  it('collector, unknown tx origin: denied', async () => {
    await assertFails(live('meena', { origin: 'import' }));
  });
});

describe('Sprint 7b: reversal of an onboarding payment', () => {
  const reverse = (uid, over = {}) => {
    const f = as(uid);
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'rev-onb')), tx(ONB, uid, {
      type: 'reversal', amountPaise: INST, paidOn: FIRST_DUE, note: 'Wrong amount',
      reversesTxId: `${ONB}-p1`, ...over,
    }));
    b.update(doc(f, p('contracts', ONB)), {
      totalPaidPaise: increment(-INST), updatedAt: Timestamp.now(), status: 'active', closedAt: null,
    });
    return b.commit();
  };
  it('owner, reversal dated at the original paidOn with origin onboarding: allowed', async () => {
    await assertSucceeds(reverse('ravi'));
  });
  it('collector, onboarding reversal: denied', async () => {
    await assertFails(reverse('meena'));
  });
  it('owner, onboarding reversal without mode: denied', async () => {
    await assertFails(reverse('ravi', { mode: null }));
  });
  it('owner, live reversal of a live payment on an onboarded contract dated today: allowed', async () => {
    await assertSucceeds(reverse('ravi', { origin: 'live', openingBalance: false, paidOn: T }));
  });
});

describe('Sprint 7b: immutability', () => {
  const upd = (uid, data, contractId = ONB) => updateDoc(doc(as(uid), p('contracts', contractId)), data);
  it('owner, contract notes update: allowed (control)', async () => {
    await assertSucceeds(upd('ravi', { notes: 'Moved from ledger book 3', updatedAt: Timestamp.now() }));
  });
  it('owner, changing origin: denied', async () => {
    await assertFails(upd('ravi', { origin: 'standard' }));
    await assertFails(upd('ravi', { origin: 'onboarded' }, STD));
  });
  it('owner, changing or removing onboardedOn: denied', async () => {
    await assertFails(upd('ravi', { onboardedOn: D(-1) }));
    await assertFails(upd('ravi', { onboardedOn: null }));
  });
  it('owner, changing disbursedOn: denied (onboarded and standard)', async () => {
    await assertFails(upd('ravi', { disbursedOn: D(-401) }));
    await assertFails(upd('ravi', { disbursedOn: D(-1) }, STD));
  });
  it('collector, changing origin / disbursedOn: denied', async () => {
    await assertFails(upd('meena', { origin: 'standard' }));
    await assertFails(upd('meena', { disbursedOn: D(-401) }));
  });
  it('owner, tx origin / openingBalance update: denied; contractActive flip: allowed', async () => {
    const t = doc(as('ravi'), p('transactions', `${ONB}-p1`));
    await assertFails(updateDoc(t, { origin: 'live' }));
    await assertFails(updateDoc(t, { openingBalance: false }));
    await assertSucceeds(updateDoc(t, { contractActive: false }));
  });
});
