// Tester — Sprint 5 adversarial rules checks (emulator only).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp, arrayUnion, collection, deleteDoc, doc, getDoc, getDocs, increment,
  query, serverTimestamp, setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const A = 'T5A';
const B = 'T5B';
const NEW = 'c-new';
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id, cid = A) => `companies/${cid}/${col}/${id}`;
const now = () => Timestamp.now();

const contract = (by, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita', borrowerPhoneE164: '+919845012890', loanNo: 4,
  purpose: null, status: 'active', sanctionedPaise: 3000000, upfrontMode: 'flat',
  upfrontInput: 0, upfrontPaise: 0, netDisbursedPaise: 3000000, frequency: 'weekly',
  preferredWeekday: 2, preferredMonthDay: null, installmentPaise: 1000000,
  baseInstallmentCount: 3, firstDueDate: '2023-10-31', disbursedOn: '2023-10-24',
  guarantor: null, notes: null, totalPaidPaise: 0, lastPaymentOn: null, closedAt: null,
  rolledOverFromContractId: null, rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy: by, createdAt: now(), updatedAt: now(), schemaVersion: 1, ...over,
});
const inst = (cid, seq, by, over = {}) => ({
  contractId: cid, borrowerId: 'b1', borrowerName: 'Anita', loanNo: 4, contractActive: true,
  seq, kind: 'base', dueDate: `2023-11-0${seq}`, amountDuePaise: 1000000,
  rescheduledOutPaise: 0, rescheduledToIds: [], rescheduledFromId: null,
  createdBy: by, createdAt: now(), schemaVersion: 1, ...over,
});
const tx = (cid, by, over = {}) => ({
  contractId: cid, borrowerId: 'b1', borrowerName: 'Anita', loanNo: 4, contractActive: true,
  type: 'disbursement', amountPaise: 3000000, paidOn: '2023-10-24', mode: null, reference: null,
  note: null, reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy: by, recordedByName: by, recordedAt: serverTimestamp(), clientRecordedAt: now(),
  deviceId: 'dev-t', schemaVersion: 1, ...over,
});

const create = (uid, over = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('contracts', NEW)), contract(uid, over));
  for (let s = 1; s <= 3; s++) b.set(doc(f, p('installments', `${NEW}-i${s}`)), inst(NEW, s, uid));
  b.set(doc(f, p('transactions', `${NEW}-tx`)), tx(NEW, uid));
  b.update(doc(f, `companies/${A}`), { nextLoanNo: increment(1) });
  return b.commit();
};

const reschedule = (uid, amountPaise) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.update(doc(f, p('installments', 'c1-i1')), {
    rescheduledOutPaise: increment(500000), rescheduledToIds: arrayUnion('c1-r1'),
  });
  b.set(doc(f, p('installments', 'c1-r1')), inst('c1', 4, uid, {
    kind: 'rescheduled', rescheduledFromId: 'c1-i1', dueDate: '2023-12-08', amountDuePaise: 500000,
  }));
  b.set(doc(f, p('transactions', 'c1-tx-r1')), tx('c1', uid, {
    type: 'reschedule', amountPaise, paidOn: '2023-12-03',
    rescheduleInfo: { fromInstallmentId: 'c1-i1', toInstallmentId: 'c1-r1', amountPaise: 500000, newDueDate: '2023-12-08' },
  }));
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
    for (const [cid, owner] of [[A, 'ravi'], [B, 'bala']]) {
      await setDoc(doc(f, `companies/${cid}`), {
        name: cid, nameLower: cid.toLowerCase(), city: null, phoneE164: null, ownerUids: [owner],
        nextLoanNo: 3, createdBy: owner, createdAt: now(), schemaVersion: 1,
      });
    }
    for (const [cid, uid, role] of [[A, 'ravi', 'owner'], [A, 'meena', 'collector'], [B, 'bala', 'owner'], [B, 'kiran', 'collector']]) {
      await setDoc(doc(f, `companies/${cid}/members/${uid}`), {
        uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
        invitedBy: null, joinedAt: now(), schemaVersion: 1,
      });
    }
    await setDoc(doc(f, p('borrowers', 'b1')), {
      name: 'Anita', nameLower: 'anita', phoneE164: '+919845012890', locality: null, notes: null,
      archived: false, createdBy: 'ravi', createdAt: now(), updatedAt: now(), schemaVersion: 1,
    });
    await setDoc(doc(f, p('contracts', 'c1')), contract('ravi'));
    for (let s = 1; s <= 3; s++) await setDoc(doc(f, p('installments', `c1-i${s}`)), inst('c1', s, 'ravi'));
  });
});

describe('Tester S5: contracts', () => {
  it('control: owner create batch allowed', async () => { await assertSucceeds(create('ravi')); });
  it('collector creating a contract: denied', async () => { await assertFails(create('meena')); });
  it('totalPaidPaise ≠ 0 at create: denied', async () => {
    await assertFails(create('ravi', { totalPaidPaise: 1 }));
  });
  it('installment amountDuePaise update (owner): denied', async () => {
    await assertFails(updateDoc(doc(as('ravi'), p('installments', 'c1-i2')), { amountDuePaise: 1 }));
  });
  it('control: reschedule with audit amount 0 allowed', async () => { await assertSucceeds(reschedule('ravi', 0)); });
  it('reschedule audit tx with amount 5: denied', async () => { await assertFails(reschedule('ravi', 5)); });
});

describe('Tester S5: borrowers and isolation', () => {
  it('borrower delete by owner: denied', async () => {
    await assertFails(deleteDoc(doc(as('ravi'), p('borrowers', 'b1'))));
  });
  it('borrower delete by collector: denied', async () => {
    await assertFails(deleteDoc(doc(as('meena'), p('borrowers', 'b1'))));
  });
  it('control: own member reads installments', async () => {
    await assertSucceeds(getDoc(doc(as('meena'), p('installments', 'c1-i1'))));
  });
  it('member of another company reading installments (get): denied', async () => {
    await assertFails(getDoc(doc(as('kiran'), p('installments', 'c1-i1'))));
    await assertFails(getDoc(doc(as('bala'), p('installments', 'c1-i1'))));
  });
  it('member of another company listing installments: denied', async () => {
    const f = as('bala');
    await assertFails(getDocs(query(collection(f, `companies/${A}/installments`), where('contractId', '==', 'c1'))));
  });
});
