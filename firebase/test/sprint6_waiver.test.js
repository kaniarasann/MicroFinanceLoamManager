// Sprint 6 (Task 12b) close-with-waiver and waiver-reversal batches
// replayed against the rules (emulator only). Payloads mirror EXACTLY what
// PaymentRepository.closeWithWaiver / reversePayment write.
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
const CID = 'S6W';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id) => `companies/${CID}/${col}/${id}`;

// Contract.toJson: ₹30,000 weekly 3 × ₹10,000, ₹20,000 paid.
const contract = (createdBy, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 4, purpose: null, status: 'active',
  sanctionedPaise: 3000000, upfrontMode: 'flat', upfrontInput: 0, upfrontPaise: 0,
  netDisbursedPaise: 3000000, frequency: 'weekly', preferredWeekday: 2, preferredMonthDay: null,
  installmentPaise: 1000000, baseInstallmentCount: 3, firstDueDate: '2023-10-31',
  disbursedOn: '2023-10-24', guarantor: null, notes: null, totalPaidPaise: 0,
  totalWaivedPaise: 0, lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const tx = (recordedBy, over = {}) => ({
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: false,
  type: 'payment', amountPaise: 800000, paidOn: '2023-11-07', mode: 'cash', reference: null,
  note: null, reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});
const OLD_INST = ['c1-i1', 'c1-i2', 'c1-i3'];
const OLD_TX = ['c1-d', 'c1-p1'];
const flip = (b, f, active) => {
  for (const id of [...OLD_INST.map((i) => p('installments', i)), ...OLD_TX.map((t) => p('transactions', t))]) {
    b.update(doc(f, id), { contractActive: active });
  }
};

// closeWithWaiver: outstanding ₹10,000 = cash ₹8,000 + waiver ₹2,000.
const closeBatch = (uid, { cash = 800000, waiver = 200000, waiverTx = {}, contractOver = {} } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  if (cash > 0) b.set(doc(f, p('transactions', 'pay-w')), tx(uid, { amountPaise: cash }));
  b.set(doc(f, p('transactions', 'waive-1')), tx(uid, {
    type: 'waiver', amountPaise: waiver, mode: null, note: 'Early closure discount', ...waiverTx,
  }));
  b.update(doc(f, p('contracts', 'c1')), {
    totalPaidPaise: increment(cash), totalWaivedPaise: increment(waiver), lastPaymentOn: '2023-11-07',
    status: 'closed', closedAt: Timestamp.now(), updatedAt: Timestamp.now(), ...contractOver,
  });
  flip(b, f, false);
  return b.commit();
};

// reversePayment of the waiver on the closed contract (reopens).
const waiverReversal = (uid) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('transactions', 'rev-w')), tx(uid, {
    type: 'reversal', amountPaise: 200000, mode: null, note: 'Discount cancelled',
    reversesTxId: 'waive-0', contractActive: true, paidOn: '2023-11-08',
  }));
  b.update(doc(f, p('contracts', 'c1')), {
    totalWaivedPaise: increment(-200000), updatedAt: Timestamp.now(), status: 'active', closedAt: null,
  });
  flip(b, f, true);
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

const seed = (contractOver = {}, active = true) => env.withSecurityRulesDisabled(async (ctx) => {
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
  await Promise.all(OLD_INST.map((id, i) => setDoc(doc(f, p('installments', id)), {
    contractId: 'c1', borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: active,
    seq: i + 1, kind: 'base', dueDate: `2023-11-0${i + 1}`, amountDuePaise: 1000000,
    rescheduledOutPaise: 0, rescheduledToIds: [], rescheduledFromId: null,
    createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
  })));
  await setDoc(doc(f, p('transactions', 'c1-d')), tx('ravi', {
    type: 'disbursement', amountPaise: 3000000, mode: null, contractActive: active, recordedAt: Timestamp.now(),
  }));
  await setDoc(doc(f, p('transactions', 'c1-p1')), tx('meena', {
    amountPaise: 2000000, contractActive: active, recordedAt: Timestamp.now(),
  }));
});

describe('Sprint 6b: close with waiver', () => {
  beforeEach(async () => { await env.clearFirestore(); await seed(); });
  it('owner close-with-waiver batch: allowed', async () => {
    await assertSucceeds(closeBatch('ravi'));
  });
  it('owner full waiver with no cash: allowed', async () => {
    await assertSucceeds(closeBatch('ravi', { cash: 0, waiver: 1000000 }));
  });
  it('collector waiver: denied', async () => {
    await assertFails(closeBatch('meena'));
  });
  it('waiver amount 0: denied', async () => {
    await assertFails(closeBatch('ravi', { waiver: 0 }));
  });
  it('waiver with no note: denied', async () => {
    await assertFails(closeBatch('ravi', { waiverTx: { note: null } }));
  });
  it('waiver with an empty note: denied', async () => {
    await assertFails(closeBatch('ravi', { waiverTx: { note: '' } }));
  });
  it('collector changing totalWaivedPaise directly: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), p('contracts', 'c1')), {
      totalWaivedPaise: increment(200000), updatedAt: Timestamp.now(),
    }));
  });
  it('collector payment batch carrying totalWaivedPaise: denied', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'pay-c')), tx('meena', { contractActive: true, amountPaise: 100000 }));
    b.update(doc(f, p('contracts', 'c1')), {
      totalPaidPaise: increment(100000), totalWaivedPaise: increment(100000),
      lastPaymentOn: '2023-11-07', updatedAt: Timestamp.now(),
    });
    await assertFails(b.commit());
  });
});

describe('Sprint 6b: waiver reversal and contract create', () => {
  beforeEach(async () => {
    await env.clearFirestore();
    await seed({ status: 'closed', totalPaidPaise: 2800000, totalWaivedPaise: 200000, closedAt: Timestamp.now() }, false);
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), p('transactions', 'waive-0')),
      tx('ravi', { type: 'waiver', amountPaise: 200000, mode: null, note: 'Discount', recordedAt: Timestamp.now() })));
  });
  it('owner waiver-reversal batch: allowed', async () => {
    await assertSucceeds(waiverReversal('ravi'));
  });
  it('collector waiver reversal: denied', async () => {
    await assertFails(waiverReversal('meena'));
  });
  it('owner contract create with totalWaivedPaise 0: allowed; non-zero: denied', async () => {
    const f = as('ravi');
    await assertSucceeds(setDoc(doc(f, p('contracts', 'c-new')), contract('ravi')));
    await assertFails(setDoc(doc(f, p('contracts', 'c-new2')), contract('ravi', { totalWaivedPaise: 100 })));
  });
});
