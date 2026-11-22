import 'package:flutter/material.dart';

import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/models/enums.dart';

/// "Owner" / "Collector".
String roleLabel(Role role) => switch (role) {
  Role.owner => 'Owner',
  Role.collector => 'Collector',
};

/// Role pill: Owner (navy info tint, shield icon) or Collector (neutral,
/// person icon). The label always carries the meaning.
class RolePill extends StatelessWidget {
  const RolePill({required this.role, super.key});

  final Role role;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: roleLabel(role),
      kind: role == Role.owner ? StatusKind.info : StatusKind.neutral,
      icon: role == Role.owner
          ? Icons.verified_user_outlined
          : Icons.person_outline,
    );
  }
}
