import 'package:json_annotation/json_annotation.dart';

// Every enum serialises as its Dart name, which is exactly the string stored
// in Firestore (e.g. 'rolledOver', 'rolloverSettlement'). Repositories may
// use `value.name` in queries.

/// A member's role inside one company.
@JsonEnum()
enum Role { owner, collector }

/// Repayment schedule frequency.
@JsonEnum()
enum Frequency { daily, weekly, monthly }

/// How `Contract.upfrontInput` is interpreted: paise (flat) or basis points
/// (percent, 700 = 7.00%).
@JsonEnum()
enum UpfrontMode { flat, percent }

@JsonEnum()
enum ContractStatus { active, closed, rolledOver, cancelled }

@JsonEnum()
enum InstallmentKind { base, rescheduled }

@JsonEnum()
enum TxType {
  disbursement,
  payment,
  rolloverSettlement,
  reversal,
  reschedule,

  /// Owner-only early-closure discount: settles installments like a
  /// payment but moves no cash.
  waiver,
}

@JsonEnum()
enum PaymentMode { upi, cash, bank }

/// How a contract entered the ledger: `standard` = created in the app
/// (`new` is a reserved word), `onboarded` = an existing, in-progress loan
/// entered with its original dates. A missing field reads as `standard`.
@JsonEnum()
enum ContractOrigin { standard, onboarded }

/// Whether a transaction was recorded live or written by loan onboarding
/// (its disbursement and past payments, and reversals of those). A
/// missing field reads as `live`.
@JsonEnum()
enum TxOrigin { live, onboarding }

@JsonEnum()
enum InviteStatus { pending, accepted, revoked }
