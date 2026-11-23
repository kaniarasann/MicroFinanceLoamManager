// Sprint 6 (Task 12) payment, reversal and rollover batches replayed
// against the rules (emulator only). Payloads mirror EXACTLY what
// lib/features/payments/data/payment_repository.dart and
// lib/features/rollover/data/rollover_repository.dart write (models via
// ModelCodecs: id excluded, nulls kept, client timestamps as Timestamps,
// recordedAt as serverTimestamp()).
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
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'S6P';
const NEW = '6a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id) => `companies/${CID}/${col}/${id}`;

// Contract.toJson: ₹30,000 weekly 3 × ₹10,000.
const contract = (createdBy, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 4, purpose: null, status: 'active',
  sanctionedPaise: 3000000, upfrontMode: 'flat', upfrontInput: 0, upfrontPaise: 0,
  netDisbursedPaise: 3000000, frequency: 'weekly', preferredWeekday: 2, preferredMonthDay: null,
  installmentPaise: 1000000, baseInstallmentCount: 3, firstDueDate: '2023-10-31',
  disbursedOn: '2023-10-24', guarantor: null, notes: null, totalPaidPaise: 0,
  lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const installment = (contractId, seq, over = {}) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: true,
  seq, kind: 'base', dueDate: `2023-11-${String(seq * 7).padStart(2, '0')}`,
  amountDuePaise: 1000000, rescheduledOutPaise: 0, rescheduledToIds: [], rescheduledFromId: null,
  createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const tx = (contractId, recordedBy, over = {}) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: true,
  type: 'payment', amountPaise: 1000000, paidOn: '2023-11-07', mode: 'upi', reference: null,
  note: null, reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});
const OLD_INST = ['c1-i1', 'c1-i2', 'c1-i3'];
const OLD_TX = ['c1-d', 'c1-p1'];

const flip = (b, f, active) => {
  for (const id of OLD_INST) b.update(doc(f, p('installments', id)), { contractActive: active });
  for (const id of OLD_TX) b.update(doc(f, p('transactions', id)), { contractActive: active });
};

// PaymentRepository.recordPayment (₹20,000 already paid).
const paymentBatch = (uid, { amount = 500000, closes = false, extra = {} } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('transactions', 'pay-new')), tx('c1', uid, {
    amountPaise: amount, contractActive: !closes, reference: 'UTR 4471', ...extra.tx,
  }));
  b.update(doc(f, p('contracts', 'c1')), {
    totalPaidPaise: increment(amount), lastPaymentOn: '2023-11-07', updatedAt: Timestamp.now(),
    ...(closes ? { status: 'closed', closedAt: Timestamp.now() } : {}),
    ...extra.contract,
  });
  if (closes) flip(b, f, false);
  return b.commit();
};

// PaymentRepository.reversePayment on the closed contract (reopens).
const reversalBatch = (uid, over = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('transactions', 'rev-1')), tx('c1', uid, {
    type: 'reversal', amountPaise: 2000000, paidOn: '2023-11-08', note: 'Duplicate entry',
    reversesTxId: 'c1-p1', ...over.tx,
  }));
  b.update(doc(f, p('contracts', 'c1')), {
    totalPaidPaise: increment(-2000000), updatedAt: Timestamp.now(), status: 'active', closedAt: null,
  });
  flip(b, f, true);
  return b.commit();
};

// RolloverRepository.rollover: ₹10,000 outstanding into ₹50,000 flat ₹5,000.
const rolloverBatch = (uid, { net = 3500000 } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.update(doc(f, p('contracts', 'c1')), {
    status: 'rolledOver', rolledOverToContractId: NEW, closedAt: Timestamp.now(),
    totalPaidPaise: increment(1000000), rolloverSettledPaise: 1000000, updatedAt: Timestamp.now(),
  });
  b.set(doc(f, p('transactions', 'settle-1')), tx('c1', uid, {
    type: 'rolloverSettlement', amountPaise: 1000000, mode: null, contractActive: false,
    paidOn: '2023-12-05', relatedContractId: NEW,
  }));
  const sanctioned = 5000000;
  const upfront = 5000000 - 1000000 - net;
  b.set(doc(f, p('contracts', NEW)), contract(uid, {
    loanNo: 5, sanctionedPaise: sanctioned, upfrontInput: upfront, upfrontPaise: upfront,
    netDisbursedPaise: net, baseInstallmentCount: 5, firstDueDate: '2023-12-12',
    disbursedOn: '2023-12-05', rolledOverFromContractId: 'c1',
  }));
  for (let seq = 1; seq <= 5; seq++) {
    b.set(doc(f, p('installments', `${NEW}-i${seq}`)), installment(NEW, seq, { loanNo: 5, createdBy: uid }));
  }
  if (net > 0) {
    b.set(doc(f, p('transactions', `${NEW}-d`)), tx(NEW, uid, {
      type: 'disbursement', amountPaise: net, mode: null, loanNo: 5, paidOn: '2023-12-05',
      relatedContractId: 'c1',
    }));
  }
  b.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
  flip(b, f, false);
  return b.commit();
};

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

const seed = (contractOver = {}, txActive = true) => env.withSecurityRulesDisabled(async (ctx) => {
  const f = ctx.firestore();
  await setDoc(doc(f, `companies/${CID}`), {
    name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
    ownerUids: ['ravi'], nextLoanNo: 4, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
  });
  for (const [uid, role] of [['ravi', 'owner'], ['meena', 'collector']]) {
    await setDoc(doc(f, `companies/${CID}/members/${uid}`), {
      uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
      invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
    });
  }
  await setDoc(doc(f, p('contracts', 'c1')), contract('ravi', { totalPaidPaise: 2000000, ...contractOver }));
  await Promise.all(OLD_INST.map((id, i) =>
    setDoc(doc(f, p('installments', id)), installment('c1', i + 1, { contractActive: txActive }))));
  await setDoc(doc(f, p('transactions', 'c1-d')), tx('c1', 'ravi', {
    type: 'disbursement', amountPaise: 3000000, mode: null, paidOn: '2023-10-24',
    contractActive: txActive, recordedAt: Timestamp.now(),
  }));
  await setDoc(doc(f, p('transactions', 'c1-p1')), tx('c1', 'meena', {
    amountPaise: 2000000, contractActive: txActive, recordedAt: Timestamp.now(),
  }));
});

describe('Sprint 6: record payment', () => {
  beforeEach(async () => { await env.clearFirestore(); await seed(); });
  it('collector, partial payment batch: allowed', async () => {
    await assertSucceeds(paymentBatch('meena'));
  });
  it('collector, closing payment + contractActive flips: allowed', async () => {
    await assertSucceeds(paymentBatch('meena', { amount: 1000000, closes: true }));
  });
  it('owner, closing payment: allowed', async () => {
    await assertSucceeds(paymentBatch('ravi', { amount: 1000000, closes: true }));
  });
  it('collector, amount 0: denied', async () => {
    await assertFails(paymentBatch('meena', { amount: 0 }));
  });
  it('collector, client recordedAt: denied', async () => {
    await assertFails(paymentBatch('meena', { extra: { tx: { recordedAt: Timestamp.now() } } }));
  });
});

describe('Sprint 6: reverse payment (closed contract reopens)', () => {
  beforeEach(async () => {
    await env.clearFirestore();
    await seed({ status: 'closed', totalPaidPaise: 3000000, closedAt: Timestamp.now() }, false);
  });
  it('owner reversal batch: allowed', async () => {
    await assertSucceeds(reversalBatch('ravi'));
  });
  it('collector reversal: denied', async () => {
    await assertFails(reversalBatch('meena'));
  });
  it('owner reversal without reversesTxId: denied', async () => {
    await assertFails(reversalBatch('ravi', { tx: { reversesTxId: null } }));
  });
});

describe('Sprint 6: rollover', () => {
  beforeEach(async () => { await env.clearFirestore(); await seed(); });
  it('owner rollover batch: allowed', async () => {
    await assertSucceeds(rolloverBatch('ravi'));
  });
  it('owner rollover with ₹0 net cash (no disbursement): allowed', async () => {
    await assertSucceeds(rolloverBatch('ravi', { net: 0 }));
  });
  it('collector rollover: denied', async () => {
    await assertFails(rolloverBatch('meena'));
  });
});

describe('Sprint 6: late payment on a rolled-over contract', () => {
  beforeEach(async () => {
    await env.clearFirestore();
    await seed({ status: 'rolledOver', totalPaidPaise: 3000000, rolledOverToContractId: NEW }, false);
  });
  it('collector payment (excess path): allowed', async () => {
    await assertSucceeds(paymentBatch('meena', { amount: 1000000, extra: { tx: { contractActive: false } } }));
  });
  it('collector trying to reopen it: denied', async () => {
    await assertFails(paymentBatch('meena', { extra: { contract: { status: 'active' } } }));
  });
});
