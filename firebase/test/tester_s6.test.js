// Tester S6: adversarial rules checks for payments, reversal, rollover
// (emulator only). Run: `npm test` from firebase/.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, increment, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'TS6';
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id) => `companies/${CID}/${col}/${id}`;

const contract = (over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 4, purpose: null, status: 'active',
  sanctionedPaise: 3000000, upfrontMode: 'flat', upfrontInput: 0, upfrontPaise: 0,
  netDisbursedPaise: 3000000, frequency: 'weekly', preferredWeekday: 2, preferredMonthDay: null,
  installmentPaise: 1000000, baseInstallmentCount: 3, firstDueDate: '2023-10-31',
  disbursedOn: '2023-10-24', guarantor: null, notes: null, totalPaidPaise: 2000000,
  lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy: 'ravi', createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const tx = (recordedBy, over = {}) => ({
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: true,
  type: 'payment', amountPaise: 500000, paidOn: '2023-11-07', mode: 'upi', reference: null,
  note: null, reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});

const pay = (uid, { amount = 500000, txOver = {}, cOver = {} } = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('transactions', 'pay-new')), tx(uid, { amountPaise: amount, ...txOver }));
  b.update(doc(f, p('contracts', 'c1')), {
    totalPaidPaise: increment(amount), lastPaymentOn: '2023-11-07', updatedAt: Timestamp.now(), ...cOver,
  });
  return b.commit();
};
const reverse = (uid, txOver = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('transactions', 'rev-1')), tx(uid, {
    type: 'reversal', amountPaise: 2000000, paidOn: '2023-11-08', note: 'Duplicate',
    reversesTxId: 'c1-p1', ...txOver,
  }));
  b.update(doc(f, p('contracts', 'c1')), { totalPaidPaise: increment(-2000000), updatedAt: Timestamp.now() });
  return b.commit();
};

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nordic',
    firestore: { rules: readFileSync(resolve(here, '../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
afterAll(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, `companies/${CID}`), {
      name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
      ownerUids: ['ravi'], nextLoanNo: 5, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
    });
    for (const [uid, role] of [['ravi', 'owner'], ['meena', 'collector']]) {
      await setDoc(doc(f, `companies/${CID}/members/${uid}`), {
        uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
        invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
      });
    }
    await setDoc(doc(f, p('contracts', 'c1')), contract());
    await setDoc(doc(f, p('transactions', 'c1-p1')), tx('meena', { amountPaise: 2000000, recordedAt: Timestamp.now() }));
  });
});

describe('Tester S6: rules', () => {
  it('control: collector payment allowed', async () => {
    await assertSucceeds(pay('meena'));
  });
  it('control: owner reversal allowed', async () => {
    await assertSucceeds(reverse('ravi'));
  });
  it('collector reversal: denied', async () => {
    await assertFails(reverse('meena'));
  });
  it('collector decreasing totalPaidPaise directly: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), p('contracts', 'c1')), {
      totalPaidPaise: increment(-500000), updatedAt: Timestamp.now(),
    }));
  });
  it('collector payment batch with a negative increment: denied', async () => {
    await assertFails(pay('meena', { amount: -500000 }));
  });
  it('payment with amount 0: denied', async () => {
    await assertFails(pay('meena', { amount: 0 }));
    await assertFails(pay('ravi', { amount: 0 }));
  });
  it('owner reversal without reversesTxId: denied', async () => {
    await assertFails(reverse('ravi', { reversesTxId: null }));
  });
  it('collector setting status rolledOver: denied', async () => {
    await assertFails(updateDoc(doc(as('meena'), p('contracts', 'c1')), {
      status: 'rolledOver', updatedAt: Timestamp.now(),
    }));
    await assertFails(pay('meena', { cOver: { status: 'rolledOver' } }));
  });
  it('editing a payment transaction amount: denied (owner and collector)', async () => {
    for (const uid of ['meena', 'ravi']) {
      await assertFails(updateDoc(doc(as(uid), p('transactions', 'c1-p1')), { amountPaise: 1 }));
    }
  });
});
