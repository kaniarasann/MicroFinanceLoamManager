// Sprint 4 client flows replayed against the rules (emulator only).
// Payloads mirror EXACTLY what the Flutter repositories write:
//   lib/features/onboarding/data/company_repository.dart  (registerCompany)
//   lib/features/onboarding/data/invite_repository.dart   (accept)
//   lib/features/onboarding/data/user_settings_repository.dart
//   lib/features/company/application/company_providers.dart (removal cleanup)
//   lib/features/company/data/members_repository.dart       (invites, roles, removal)
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
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'demo-nordic';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

// ------------------------------------------------- Dart payload mirrors

// Company.toJson (id excluded) + codec: createdAt -> Timestamp.
const dartCompany = (uid, name, { city = null, phoneE164 = null } = {}) => ({
  name, nameLower: name.toLowerCase(), city, phoneE164, ownerUids: [uid],
  nextLoanNo: 0, createdBy: uid, createdAt: Timestamp.now(), schemaVersion: 1,
});
// Member.toJson: every field, nulls included.
const dartMember = (uid, role, displayName, { phoneE164 = null, inviteCode = null, invitedBy = null } = {}) => ({
  uid, role, displayName, phoneE164, status: 'active', inviteCode, invitedBy,
  joinedAt: Timestamp.now(), schemaVersion: 1,
});
const dartMembership = (cid, companyName, role) => ({
  companyId: cid, companyName, role, joinedAt: Timestamp.now(), schemaVersion: 1,
});
// UserSettingsRepository.activeCompanyPatch, written with merge: true.
const activeCompanyPatch = (cid) => ({
  activeCompanyId: cid, updatedAt: serverTimestamp(), schemaVersion: 1,
});

/** CompanyRepository.registerCompany: ONE batch, 4 docs. */
function registerBatch(f, uid, cid, name, opts = {}) {
  const b = writeBatch(f);
  b.set(doc(f, `companies/${cid}`), dartCompany(uid, name, opts));
  b.set(doc(f, `companies/${cid}/members/${uid}`), dartMember(uid, 'owner', 'Asha Rao', { phoneE164: '+919845012890' }));
  b.set(doc(f, `users/${uid}/memberships/${cid}`), dartMembership(cid, name, 'owner'));
  b.set(doc(f, `user_settings/${uid}`), activeCompanyPatch(cid), { merge: true });
  return b.commit();
}

/** InviteRepository.accept: read invite, then member + membership + invite (+ ownerUids). */
function acceptTx(f, uid, code, { skipOwnerUnion = false } = {}) {
  return runTransaction(f, async (t) => {
    const snap = await t.get(doc(f, `invites/${code}`));
    if (!snap.exists()) throw new Error('not-found');
    const inv = snap.data();
    if (inv.status !== 'pending') throw new Error('unavailable');
    const cid = inv.companyId;
    t.set(doc(f, `companies/${cid}/members/${uid}`), dartMember(uid, inv.role, inv.inviteeName, {
      phoneE164: inv.inviteePhoneE164, inviteCode: code, invitedBy: inv.createdBy,
    }));
    t.set(doc(f, `users/${uid}/memberships/${cid}`), dartMembership(cid, inv.companyName, inv.role));
    t.update(doc(f, `invites/${code}`), { status: 'accepted', acceptedBy: uid, acceptedAt: serverTimestamp() });
    if (inv.role === 'owner' && !skipOwnerUnion) {
      t.update(doc(f, `companies/${cid}`), { ownerUids: arrayUnion(uid) });
    }
  });
}

const invite = (over = {}) => ({
  companyId: 'S4', companyName: 'Sri Lakshmi Finance', companyCity: 'Chennai',
  role: 'collector', inviteeName: 'Meena', inviteePhoneE164: '+919845012891',
  createdBy: 'ravi', createdByName: 'Ravi Kumar', createdAt: Timestamp.now(),
  expiresAt: inDays(7), status: 'pending', acceptedBy: null, acceptedAt: null,
  schemaVersion: 1, ...over,
});

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
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
    await setDoc(doc(f, 'companies/S4'), {
      ...dartCompany('ravi', 'Sri Lakshmi Finance', { city: 'Chennai' }), nextLoanNo: 3,
    });
    await setDoc(doc(f, 'companies/S4/members/ravi'), dartMember('ravi', 'owner', 'Ravi Kumar'));
    await setDoc(doc(f, 'users/ravi/memberships/S4'), dartMembership('S4', 'Sri Lakshmi Finance', 'owner'));
    await setDoc(doc(f, 'invites/K7Q2MD'), invite());
    await setDoc(doc(f, 'invites/OWNR22'), invite({ role: 'owner' }));
    await setDoc(doc(f, 'invites/EXPR22'), invite({ expiresAt: inDays(-1) }));
    await setDoc(doc(f, 'invites/USED22'), invite({ status: 'accepted', acceptedBy: 'x', acceptedAt: Timestamp.now() }));
  });
});

const CID = '3f1c2a7e-9b4d-4c1e-8f2a-6d5b4c3a2b1c';

describe('Sprint 4: register company batch (as the app writes it)', () => {
  it('succeeds with all optional fields', async () => {
    await assertSucceeds(registerBatch(as('asha'), 'asha', CID, 'Asha Finance', {
      city: 'Madurai', phoneE164: '+919000011111',
    }));
    await assertSucceeds(getDoc(doc(as('asha'), `companies/${CID}`)));
  });
  it('succeeds with null city / phone', async () => {
    await assertSucceeds(registerBatch(as('asha'), 'asha', CID, 'Asha Finance'));
  });
  it('succeeds for a second company with existing user_settings (merge)', async () => {
    await assertSucceeds(registerBatch(as('ravi'), 'ravi', CID, 'Ravi Two'));
  });
  it('is denied for an existing company id', async () => {
    await assertFails(registerBatch(as('asha'), 'asha', 'S4', 'Hijack'));
  });
});

describe('Sprint 4: accept invite transaction (as the app writes it)', () => {
  it('collector invite: member + membership + invite accepted', async () => {
    await assertSucceeds(acceptTx(as('meena'), 'meena', 'K7Q2MD'));
    await assertSucceeds(getDoc(doc(as('meena'), 'companies/S4')));
    // The separate activeCompanyId write after the transaction.
    await assertSucceeds(setDoc(doc(as('meena'), 'user_settings/meena'), activeCompanyPatch('S4'), { merge: true }));
  });
  it('owner invite with the ownerUids arrayUnion succeeds', async () => {
    await assertSucceeds(acceptTx(as('meena'), 'meena', 'OWNR22'));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const c = await getDoc(doc(ctx.firestore(), 'companies/S4'));
      if (!c.data().ownerUids.includes('meena')) throw new Error('ownerUids not updated');
    });
  });
  it('owner invite WITHOUT the arrayUnion is denied', async () => {
    await assertFails(acceptTx(as('meena'), 'meena', 'OWNR22', { skipOwnerUnion: true }));
  });
  it('expired invite is denied', async () => {
    await assertFails(acceptTx(as('meena'), 'meena', 'EXPR22'));
  });
  it('lookup get by exact code is allowed for any signed-in user', async () => {
    await assertSucceeds(getDoc(doc(as('meena'), 'invites/K7Q2MD')));
  });
});

describe('Sprint 4: removed-member cleanup and switching', () => {
  it('a removed user can delete their own stale membership doc', async () => {
    await assertSucceeds(acceptTx(as('meena'), 'meena', 'K7Q2MD'));
    // Owner removes the member doc.
    await assertSucceeds(deleteDoc(doc(as('ravi'), 'companies/S4/members/meena')));
    // Member doc read is now denied (the app treats this as "removed").
    await assertFails(getDoc(doc(as('meena'), 'companies/S4')));
    await assertSucceeds(deleteDoc(doc(as('meena'), 'users/meena/memberships/S4')));
    await assertSucceeds(setDoc(doc(as('meena'), 'user_settings/meena'), activeCompanyPatch(null), { merge: true }));
  });
});

// ------------------------------------------------- Task 9: members & invites

// InviteRepository.createInvite: Invite.toJson via the codec (createdAt /
// expiresAt -> Timestamp, acceptedBy / acceptedAt null), set on invites/{code}.
const dartNewInvite = (createdBy, over = {}) => ({
  companyId: 'S4', companyName: 'Sri Lakshmi Finance', companyCity: 'Chennai',
  role: 'collector', inviteeName: 'Meena', inviteePhoneE164: '+919845012891',
  createdBy, createdByName: 'Ravi Kumar', createdAt: Timestamp.now(),
  expiresAt: inDays(7), status: 'pending', acceptedBy: null, acceptedAt: null,
  schemaVersion: 1, ...over,
});

/** InviteRepository.createInvite: server get (collision check), then set. */
async function createInvite(f, uid, code, over = {}) {
  const snap = await getDoc(doc(f, `invites/${code}`));
  if (snap.exists()) throw new Error('collision');
  await setDoc(doc(f, `invites/${code}`), dartNewInvite(uid, over));
}

/** InviteRepository.watchPendingInvites query. */
const pendingInvitesQuery = (f, cid) =>
  query(collection(f, 'invites'), where('companyId', '==', cid), where('status', '==', 'pending'));

/** MembersRepository.changeRole: ONE batch (member + ownerUids + membership). */
function changeRoleBatch(f, cid, uid, newRole) {
  const b = writeBatch(f);
  b.update(doc(f, `companies/${cid}/members/${uid}`), { role: newRole });
  b.update(doc(f, `companies/${cid}`), {
    ownerUids: newRole === 'owner' ? arrayUnion(uid) : arrayRemove(uid),
  });
  b.update(doc(f, `users/${uid}/memberships/${cid}`), { role: newRole });
  return b.commit();
}

/** MembersRepository.removeMember: ONE batch (member + ownerUids if owner + membership). */
function removeMemberBatch(f, cid, uid, { wasOwner }) {
  const b = writeBatch(f);
  b.delete(doc(f, `companies/${cid}/members/${uid}`));
  if (wasOwner) b.update(doc(f, `companies/${cid}`), { ownerUids: arrayRemove(uid) });
  b.delete(doc(f, `users/${uid}/memberships/${cid}`));
  return b.commit();
}

async function seedCollector(uid = 'meena') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, `companies/S4/members/${uid}`), dartMember(uid, 'collector', 'Meena', {
      phoneE164: '+919845012891', inviteCode: 'K7Q2MD', invitedBy: 'ravi',
    }));
    await setDoc(doc(f, `users/${uid}/memberships/S4`), dartMembership('S4', 'Sri Lakshmi Finance', 'collector'));
  });
}
async function seedOtherCompany() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'companies/OTHER'), dartCompany('bob', 'Bob Finance'));
    await setDoc(doc(f, 'companies/OTHER/members/bob'), dartMember('bob', 'owner', 'Bob'));
    await setDoc(doc(f, 'invites/BQBB22'), invite({ companyId: 'OTHER', companyName: 'Bob Finance', createdBy: 'bob' }));
  });
}
async function ownerUidsOf(cid = 'S4') {
  let uids;
  await env.withSecurityRulesDisabled(async (ctx) => {
    uids = (await getDoc(doc(ctx.firestore(), `companies/${cid}`))).data().ownerUids;
  });
  return uids;
}
async function docExists(path) {
  let e;
  await env.withSecurityRulesDisabled(async (ctx) => {
    e = (await getDoc(doc(ctx.firestore(), path))).exists();
  });
  return e;
}

describe('Task 9: create invite (as the app writes it)', () => {
  it('owner creates a collector invite', async () => {
    await assertSucceeds(createInvite(as('ravi'), 'ravi', 'Q3W4ER'));
  });
  it('owner creates an owner invite', async () => {
    await assertSucceeds(createInvite(as('ravi'), 'ravi', 'Q3W4EZ', { role: 'owner' }));
  });
  it('collector cannot create an invite', async () => {
    await seedCollector();
    await assertFails(createInvite(as('meena'), 'meena', 'Q3W4ER'));
  });
  it('owner of another company cannot create an invite for S4', async () => {
    await seedOtherCompany();
    await assertFails(createInvite(as('bob'), 'bob', 'Q3W4ER'));
  });
  it('a code outside the alphabet is denied', async () => {
    await assertFails(createInvite(as('ravi'), 'ravi', 'Q3W4E0'));
  });
});

describe('Task 9: owner lists pending invites (rules change)', () => {
  it('owner can run the company-scoped pending query', async () => {
    const snap = await assertSucceeds(getDocs(pendingInvitesQuery(as('ravi'), 'S4')));
    const codes = snap.docs.map((d) => d.id).sort();
    if (codes.join(',') !== 'EXPR22,K7Q2MD,OWNR22') throw new Error(`unexpected ${codes}`);
  });
  it('owner can run a companyId-only query', async () => {
    await assertSucceeds(getDocs(query(collection(as('ravi'), 'invites'), where('companyId', '==', 'S4'))));
  });
  it('owner cannot list invites without the companyId constraint', async () => {
    await assertFails(getDocs(collection(as('ravi'), 'invites')));
    await assertFails(getDocs(query(collection(as('ravi'), 'invites'), where('status', '==', 'pending'))));
  });
  it('collector cannot list their company invites', async () => {
    await seedCollector();
    await assertFails(getDocs(pendingInvitesQuery(as('meena'), 'S4')));
  });
  it('owner of another company cannot list S4 invites (only their own)', async () => {
    await seedOtherCompany();
    await assertFails(getDocs(pendingInvitesQuery(as('bob'), 'S4')));
    await assertSucceeds(getDocs(pendingInvitesQuery(as('bob'), 'OTHER')));
  });
  it('signed-in non-member and signed-out users cannot list', async () => {
    await assertFails(getDocs(pendingInvitesQuery(as('eve'), 'S4')));
    await assertFails(getDocs(pendingInvitesQuery(env.unauthenticatedContext().firestore(), 'S4')));
  });
});

describe('Task 9: revoke / resend', () => {
  it('owner revokes a pending invite', async () => {
    await assertSucceeds(updateDoc(doc(as('ravi'), 'invites/K7Q2MD'), { status: 'revoked' }));
  });
  it('resend of an expired code: fresh invite + revoke of the old one', async () => {
    await assertSucceeds(createInvite(as('ravi'), 'ravi', 'NEWC22'));
    await assertSucceeds(updateDoc(doc(as('ravi'), 'invites/EXPR22'), { status: 'revoked' }));
  });
  it('collector cannot revoke', async () => {
    await seedCollector();
    await assertFails(updateDoc(doc(as('meena'), 'invites/K7Q2MD'), { status: 'revoked' }));
  });
  it('an accepted invite cannot be revoked', async () => {
    await assertFails(updateDoc(doc(as('ravi'), 'invites/USED22'), { status: 'revoked' }));
  });
});

describe('Task 9: change role batch', () => {
  it('owner promotes a collector (member + ownerUids + membership)', async () => {
    await seedCollector();
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'owner'));
    if (!(await ownerUidsOf()).includes('meena')) throw new Error('not promoted');
  });
  it('owner demotes another owner', async () => {
    await seedCollector();
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'owner'));
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'collector'));
    if ((await ownerUidsOf()).includes('meena')) throw new Error('not demoted');
  });
  it('a co-owner can demote themselves while another owner remains', async () => {
    await seedCollector();
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'owner'));
    await assertSucceeds(changeRoleBatch(as('meena'), 'S4', 'meena', 'collector'));
  });
  it('the last owner cannot be demoted', async () => {
    await assertFails(changeRoleBatch(as('ravi'), 'S4', 'ravi', 'collector'));
  });
  it('a promotion without the ownerUids update is denied', async () => {
    await seedCollector();
    const f = as('ravi');
    const b = writeBatch(f);
    b.update(doc(f, 'companies/S4/members/meena'), { role: 'owner' });
    b.update(doc(f, 'users/meena/memberships/S4'), { role: 'owner' });
    await assertFails(b.commit());
  });
  it('collector cannot change roles (self-promotion or others)', async () => {
    await seedCollector();
    await seedCollector('arun');
    await assertFails(changeRoleBatch(as('meena'), 'S4', 'meena', 'owner'));
    await assertFails(changeRoleBatch(as('meena'), 'S4', 'arun', 'owner'));
    await assertFails(changeRoleBatch(as('meena'), 'S4', 'ravi', 'collector'));
  });
});

describe('Task 9: remove member batch', () => {
  it('owner removes a collector (member + membership)', async () => {
    await seedCollector();
    await assertSucceeds(removeMemberBatch(as('ravi'), 'S4', 'meena', { wasOwner: false }));
    if (await docExists('companies/S4/members/meena')) throw new Error('member kept');
    if (await docExists('users/meena/memberships/S4')) throw new Error('membership kept');
  });
  it('owner removes a co-owner (with the ownerUids arrayRemove)', async () => {
    await seedCollector();
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'owner'));
    await assertSucceeds(removeMemberBatch(as('ravi'), 'S4', 'meena', { wasOwner: true }));
    if ((await ownerUidsOf()).includes('meena')) throw new Error('ownerUids kept');
  });
  it('removing a co-owner without the arrayRemove is denied', async () => {
    await seedCollector();
    await assertSucceeds(changeRoleBatch(as('ravi'), 'S4', 'meena', 'owner'));
    await assertFails(removeMemberBatch(as('ravi'), 'S4', 'meena', { wasOwner: false }));
  });
  it('the last owner cannot be removed', async () => {
    await assertFails(removeMemberBatch(as('ravi'), 'S4', 'ravi', { wasOwner: true }));
  });
  it('collector cannot remove members', async () => {
    await seedCollector();
    await seedCollector('arun');
    await assertFails(removeMemberBatch(as('meena'), 'S4', 'arun', { wasOwner: false }));
    await assertFails(removeMemberBatch(as('meena'), 'S4', 'ravi', { wasOwner: true }));
  });
  it('the members list is readable by owner and collector, not outsiders', async () => {
    await seedCollector();
    await assertSucceeds(getDocs(collection(as('ravi'), 'companies/S4/members')));
    await assertSucceeds(getDocs(collection(as('meena'), 'companies/S4/members')));
    await assertFails(getDocs(collection(as('eve'), 'companies/S4/members')));
  });
});
