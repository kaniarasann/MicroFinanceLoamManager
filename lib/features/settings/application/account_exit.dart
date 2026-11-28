/// What deleting an account does to one company membership.
enum ExitAction {
  /// Collector (or an owner listed nowhere in `ownerUids`): leave.
  leave,

  /// One of several owners: leave and drop out of `ownerUids`.
  leaveOwner,

  /// Sole owner and the only member: close the company. Its records are kept
  /// in Firestore (never hard-deleted) but nobody can open them any more.
  close,

  /// Sole owner with other members: hand over ownership (or remove the
  /// members) first. Deletion is blocked.
  blocked,

  /// The membership index doc points at a company the user can no longer
  /// read (removed earlier): only the index doc is deleted.
  stale,
}

/// Server facts about one membership, read just before deletion.
final class CompanyExitFacts {
  const CompanyExitFacts({
    required this.companyId,
    required this.companyName,
    this.readable = false,
    this.ownerUids = const <String>[],
    this.otherMembers = 0,
    this.pendingInviteCodes = const <String>[],
  });

  final String companyId;
  final String companyName;

  /// The company doc could be read (the user is still a member).
  final bool readable;
  final List<String> ownerUids;

  /// Members other than the user (counted only for a sole owner).
  final int otherMembers;

  /// Pending invites (listed only for a sole owner; revoked on close).
  final List<String> pendingInviteCodes;
}

/// Pure rule (mirrors the Firestore rules' last-owner guard).
ExitAction decideExit(String uid, CompanyExitFacts f) {
  if (!f.readable) return ExitAction.stale;
  if (!f.ownerUids.contains(uid)) return ExitAction.leave;
  if (f.ownerUids.length > 1) return ExitAction.leaveOwner;
  return f.otherMembers == 0 ? ExitAction.close : ExitAction.blocked;
}

/// One membership and what will happen to it.
final class CompanyExit {
  const CompanyExit(this.facts, this.action);

  final CompanyExitFacts facts;
  final ExitAction action;

  /// User-facing line for the confirmation screen.
  String get description => switch (action) {
    ExitAction.leave || ExitAction.leaveOwner =>
      'You will leave ${facts.companyName}. Its records stay with the '
          'company.',
    ExitAction.close =>
      "You're the only member of ${facts.companyName}, so it will be "
          "closed. Its records are kept but can't be opened again.",
    ExitAction.blocked =>
      "You're the only owner of ${facts.companyName} and it has "
          '${facts.otherMembers == 1 ? '1 other member' : '${facts.otherMembers} other members'}. '
          'Make one of them an owner, or remove them, in Members & '
          'invites first.',
    ExitAction.stale =>
      'You no longer have access to ${facts.companyName}; it will be '
          'removed from your list.',
  };
}

/// The whole account exit.
final class AccountExitPlan {
  AccountExitPlan(String uid, List<CompanyExitFacts> facts)
    : exits = List<CompanyExit>.unmodifiable(<CompanyExit>[
        for (final f in facts) CompanyExit(f, decideExit(uid, f)),
      ]);

  final List<CompanyExit> exits;

  /// Some company needs an ownership hand-over first.
  bool get isBlocked =>
      exits.any((CompanyExit e) => e.action == ExitAction.blocked);

  Iterable<CompanyExit> get blocked =>
      exits.where((CompanyExit e) => e.action == ExitAction.blocked);
}
