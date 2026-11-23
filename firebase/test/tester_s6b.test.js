// Tester S6 Task 12b: adversarial rules checks for the early-closure waiver
// (emulator only). Run: `npm test` from firebase/.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, doc, increment, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'TS6B';
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id) => `companies/${CID}/${col}/${id}`;

// ₹1,00,000 weekly, ₹60,000 paid, ₹500 already waived (for the negative test).
const contract = (over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 7, purpose: null, status: 'active',
  sanctionedPaise: 10000000, upfrontMode: 'flat', upfrontInput: 700000, upfrontPaise: 700000,
  netDisbursedPaise: 9300000, frequency: 'weekly', preferredWeekday: 2, preferredMonthDay: null,
  installmentPaise: 1000000, baseInstallmentCount: 10, firstDueDate: '2023-10-31',
  disbursedOn: '2023-10-24', guarantor: null, notes: null, totalPaidPaise: 6000000,
  totalWaivedPaise: 50000, lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy: 'ravi', createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
const waiverTx = (recordedBy, over = {}) => ({
  contractId: 'c1', borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 7, contractActive: false,
  type: 'waiver', amountPaise: 150000, paidOn: '2023-11-07', mode: null, reference: null,
  note: 'Early closure discount', reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});
const createWaiver = (uid, over = {}) =>
  setDoc(doc(as(uid), p('transactions', 'w-new')), waiverTx(uid, over));

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
      ownerUids: ['ravi'], nextLoanNo: 8, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
    });
    for (const [uid, role] of [['ravi', 'owner'], ['meena', 'collector']]) {
      await setDoc(doc(f, `companies/${CID}/members/${uid}`), {
        uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
        invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
      });
    }
    await setDoc(doc(f, p('contracts', 'c1')), contract());
  });
});

describe('Tester S6b: waiver transactions', () => {
  it('control: owner waiver with a reason: allowed', async () => {
    await assertSucceeds(createWaiver('ravi'));
  });
  it('collector waiver create (standalone doc, active or not): denied', async () => {
    await assertFails(createWaiver('meena'));
    await assertFails(createWaiver('meena', { contractActive: true }));
  });
  it('collector waiver hidden inside a payment batch: denied', async () => {
    const f = as('meena');
    const b = writeBatch(f);
    b.set(doc(f, p('transactions', 'w-new')), waiverTx('meena'));
    b.update(doc(f, p('contracts', 'c1')), { totalPaidPaise: increment(0), updatedAt: Timestamp.now() });
    await assertFails(b.commit());
  });
  it('owner waiver with the note key missing entirely: denied', async () => {
    const t = waiverTx('ravi');
    delete t.note;
    await assertFails(setDoc(doc(as('ravi'), p('transactions', 'w-new')), t));
  });
  it('owner waiver with a non-string note: denied', async () => {
    await assertFails(createWaiver('ravi', { note: 42 }));
  });
  it('owner waiver with a whitespace-only note: denied', async () => {
    await assertFails(createWaiver('ravi', { note: '   ' }));
  });
  it('owner waiver with amount 0: denied', async () => {
    await assertFails(createWaiver('ravi', { amountPaise: 0 }));
  });
  it('owner waiver with a negative or fractional amount: denied', async () => {
    await assertFails(createWaiver('ravi', { amountPaise: -150000 }));
    await assertFails(createWaiver('ravi', { amountPaise: 1500.5 }));
  });
  it('owner editing a waiver amount after the fact: denied', async () => {
    await assertSucceeds(createWaiver('ravi'));
    await assertFails(updateDoc(doc(as('ravi'), p('transactions', 'w-new')), { amountPaise: 1 }));
  });
});

describe('Tester S6b: contract totalWaivedPaise', () => {
  it('contract create with totalWaivedPaise ≠ 0 (positive, negative, string): denied', async () => {
    const f = as('ravi');
    const fresh = (over) => contract({ totalPaidPaise: 0, ...over });
    await assertSucceeds(setDoc(doc(f, p('contracts', 'c-ok')), fresh({ totalWaivedPaise: 0 })));
    await assertFails(setDoc(doc(f, p('contracts', 'c-pos')), fresh({ totalWaivedPaise: 100 })));
    await assertFails(setDoc(doc(f, p('contracts', 'c-neg')), fresh({ totalWaivedPaise: -100 })));
    await assertFails(setDoc(doc(f, p('contracts', 'c-str')), fresh({ totalWaivedPaise: '0' })));
  });
  it('owner update making totalWaivedPaise negative: denied (direct and by increment)', async () => {
    const f = as('ravi');
    await assertFails(updateDoc(doc(f, p('contracts', 'c1')), { totalWaivedPaise: -1, updatedAt: Timestamp.now() }));
    await assertFails(updateDoc(doc(f, p('contracts', 'c1')), {
      totalWaivedPaise: increment(-50001), updatedAt: Timestamp.now(),
    }));
    // Control: back to exactly 0 is fine (a full waiver reversal).
    await assertSucceeds(updateDoc(doc(f, p('contracts', 'c1')), {
      totalWaivedPaise: increment(-50000), updatedAt: Timestamp.now(),
    }));
  });
  it('collector updating totalWaivedPaise (up, down or reset): denied', async () => {
    const f = as('meena');
    for (const v of [increment(150000), increment(-50000), 0]) {
      await assertFails(updateDoc(doc(f, p('contracts', 'c1')), { totalWaivedPaise: v, updatedAt: Timestamp.now() }));
    }
  });
});
