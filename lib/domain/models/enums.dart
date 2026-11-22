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
enum TxType { disbursement, payment, rolloverSettlement, reversal, reschedule }

@JsonEnum()
enum PaymentMode { upi, cash, bank }

@JsonEnum()
enum InviteStatus { pending, accepted, revoked }
