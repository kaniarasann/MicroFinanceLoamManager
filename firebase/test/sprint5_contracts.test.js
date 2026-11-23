// Sprint 5 (Task 11) contract write batches replayed against the rules
// (emulator only). Payloads mirror EXACTLY what
// lib/features/contracts/data/contract_repository.dart writes:
// Contract / Installment / LedgerTransaction .toJson via ModelCodecs (id
// excluded, nulls kept, client timestamps as Timestamps, recordedAt as
// serverTimestamp()), plus the company nextLoanNo increment.
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
  arrayUnion,
  doc,
  increment,
  serverTimestamp,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const CID = 'S5C';
const NEW = '5f0c2d1e-8a7b-4c3d-9e2f-1a0b9c8d7e6f';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const p = (col, id) => `companies/${CID}/${col}/${id}`;

// ContractRepository.createContract → Contract.toJson.
const dartContract = (createdBy, over = {}) => ({
  borrowerId: 'b1', borrowerName: 'Anita Sharma', borrowerPhoneE164: '+919845012890',
  loanNo: 4, purpose: 'Shop stock', status: 'active',
  sanctionedPaise: 10000000, upfrontMode: 'flat', upfrontInput: 700000, upfrontPaise: 700000,
  netDisbursedPaise: 9300000, frequency: 'weekly', preferredWeekday: 2, preferredMonthDay: null,
  installmentPaise: 1000000, baseInstallmentCount: 10, firstDueDate: '2023-10-31',
  disbursedOn: '2023-10-24', guarantor: 'Mohan Sharma', notes: null, totalPaidPaise: 0,
  lastPaymentOn: null, closedAt: null, rolledOverFromContractId: null,
  rolledOverToContractId: null, rolloverSettledPaise: null,
  createdBy, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
// Installment.toJson.
const dartInstallment = (contractId, seq, createdBy, over = {}) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: true,
  seq, kind: 'base', dueDate: `2023-${seq < 3 ? '10' : '11'}-${String(10 + seq).padStart(2, '0')}`,
  amountDuePaise: 1000000, rescheduledOutPaise: 0, rescheduledToIds: [], rescheduledFromId: null,
  createdBy, createdAt: Timestamp.now(), schemaVersion: 1,
  ...over,
});
// LedgerTransaction.toJson.
const dartTx = (contractId, recordedBy, over = {}) => ({
  contractId, borrowerId: 'b1', borrowerName: 'Anita Sharma', loanNo: 4, contractActive: true,
  type: 'disbursement', amountPaise: 9300000, paidOn: '2023-10-24', mode: null, reference: null,
  note: null, reversesTxId: null, relatedContractId: null, rescheduleInfo: null,
  recordedBy, recordedByName: recordedBy, recordedAt: serverTimestamp(),
  clientRecordedAt: Timestamp.now(), deviceId: 'dev-1', schemaVersion: 1,
  ...over,
});

const createBatch = (uid, over = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.set(doc(f, p('contracts', NEW)), dartContract(uid, over.contract));
  for (let seq = 1; seq <= 10; seq++) {
    b.set(doc(f, p('installments', `${NEW}-i${seq}`)), dartInstallment(NEW, seq, uid));
  }
  b.set(doc(f, p('transactions', `${NEW}-tx`)), dartTx(NEW, uid, over.tx));
  b.update(doc(f, `companies/${CID}`), { nextLoanNo: increment(1) });
  return b.commit();
};

const rescheduleBatch = (uid, over = {}) => {
  const f = as(uid);
  const b = writeBatch(f);
  b.update(doc(f, p('installments', 'c1-i5')), {
    rescheduledOutPaise: increment(1000000),
    rescheduledToIds: arrayUnion('c1-r1'),
    ...over.source,
  });
  b.set(doc(f, p('installments', 'c1-r1')), dartInstallment('c1', 11, uid, {
    kind: 'rescheduled', rescheduledFromId: 'c1-i5', dueDate: '2023-12-08',
  }));
  b.set(doc(f, p('transactions', 'c1-tx-r1')), dartTx('c1', uid, {
    type: 'reschedule', amountPaise: 0, paidOn: '2023-12-03', note: 'Harvest delayed',
    rescheduleInfo: {
      fromInstallmentId: 'c1-i5', toInstallmentId: 'c1-r1', amountPaise: 1000000,
      newDueDate: '2023-12-08',
    },
    ...over.tx,
  }));
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
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, `companies/${CID}`), {
      name: 'Sri Lakshmi Finance', nameLower: 'sri lakshmi finance', city: null, phoneE164: null,
      ownerUids: ['ravi'], nextLoanNo: 3, createdBy: 'ravi', createdAt: Timestamp.now(), schemaVersion: 1,
    });
    for (const [uid, role] of [['ravi', 'owner'], ['meena', 'collector']]) {
      await setDoc(doc(f, `companies/${CID}/members/${uid}`), {
        uid, role, displayName: uid, phoneE164: null, status: 'active', inviteCode: null,
        invitedBy: null, joinedAt: Timestamp.now(), schemaVersion: 1,
      });
    }
    await setDoc(doc(f, p('contracts', 'c1')), dartContract('ravi', { totalPaidPaise: 3600000 }));
    for (let seq = 1; seq <= 10; seq++) {
      await setDoc(doc(f, p('installments', `c1-i${seq}`)), dartInstallment('c1', seq, 'ravi'));
    }
  });
});

describe('Sprint 5: createContract batch', () => {
  it('owner: allowed (contract + 10 installments + disbursement + nextLoanNo)', async () => {
    await assertSucceeds(createBatch('ravi'));
  });
  it('owner, percent mode 7.5%: allowed', async () => {
    await assertSucceeds(createBatch('ravi', {
      contract: { upfrontMode: 'percent', upfrontInput: 750, upfrontPaise: 750000, netDisbursedPaise: 9250000 },
      tx: { amountPaise: 9250000 },
    }));
  });
  it('collector: denied', async () => {
    await assertFails(createBatch('meena'));
  });
  it('non-member: denied', async () => {
    await assertFails(createBatch('stranger'));
  });
  it('owner, upfront ≥ sanctioned: denied', async () => {
    await assertFails(createBatch('ravi', {
      contract: { upfrontPaise: 10000000, netDisbursedPaise: 0 }, tx: { amountPaise: 0 },
    }));
  });
  it('owner, 367 installments: denied', async () => {
    await assertFails(createBatch('ravi', { contract: { baseInstallmentCount: 367 } }));
  });
  it('owner, totalPaidPaise ≠ 0 on create: denied', async () => {
    await assertFails(createBatch('ravi', { contract: { totalPaidPaise: 100 } }));
  });
  it('owner, client recordedAt instead of serverTimestamp: denied', async () => {
    await assertFails(createBatch('ravi', { tx: { recordedAt: Timestamp.now() } }));
  });
  it('owner, recordedBy someone else: denied', async () => {
    await assertFails(createBatch('ravi', { tx: { recordedBy: 'meena' } }));
  });
});

describe('Sprint 5: reschedule batch', () => {
  it('owner: allowed', async () => {
    await assertSucceeds(rescheduleBatch('ravi'));
  });
  it('collector: allowed', async () => {
    await assertSucceeds(rescheduleBatch('meena'));
  });
  it('non-member: denied', async () => {
    await assertFails(rescheduleBatch('stranger'));
  });
  it('audit transaction with amount ≠ 0: denied', async () => {
    await assertFails(rescheduleBatch('meena', { tx: { amountPaise: 100 } }));
  });
  it('changing the source amountDuePaise: denied', async () => {
    await assertFails(rescheduleBatch('ravi', { source: { amountDuePaise: 0 } }));
  });
  it('moving more than the source amount: denied', async () => {
    await assertFails(rescheduleBatch('ravi', { source: { rescheduledOutPaise: increment(1000001) } }));
  });
});
