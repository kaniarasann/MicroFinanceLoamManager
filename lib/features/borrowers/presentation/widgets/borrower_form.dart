import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/borrower_validators.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/phone_field.dart';
import '../../../../domain/models/models.dart';
import '../../application/borrower_providers.dart';
import '../../data/borrower_repository.dart';

/// User-facing copy for borrower writes.
abstract final class BorrowerCopy {
  static const String added = 'Borrower added';
  static const String updated = 'Borrower updated';
  static const String archived = 'Borrower archived';
  static const String queued = 'Saved · will sync';

  static String saved(WriteOutcome outcome, String syncedText) =>
      outcome == WriteOutcome.queued ? queued : syncedText;
}

/// Opens the add / edit borrower form (bottom sheet on phones, dialog on
/// wider windows). Owner only: callers hide the entry point from
/// collectors, and the rules reject their writes anyway.
///
/// Resolves to the borrower id when saved, null when dismissed.
Future<String?> showBorrowerForm(BuildContext context, {Borrower? existing}) =>
    showAdaptiveSheet<String>(
      context,
      (BuildContext _) => BorrowerForm(existing: existing),
    );

/// Name (2–80, required), +91 mobile (required, unique within the
/// company), locality and notes.
class BorrowerForm extends ConsumerStatefulWidget {
  const BorrowerForm({this.existing, super.key});

  final Borrower? existing;

  @override
  ConsumerState<BorrowerForm> createState() => _BorrowerFormState();
}

class _BorrowerFormState extends ConsumerState<BorrowerForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _locality;
  late final TextEditingController _notes;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _name = TextEditingController(text: b?.name ?? '');
    _phone = TextEditingController(
      text: IndianPhone.nationalDisplay(b?.phoneE164),
    );
    _locality = TextEditingController(text: b?.locality ?? '');
    _notes = TextEditingController(text: b?.notes ?? '');
    _phone.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phone.removeListener(_onPhoneChanged);
    _name.dispose();
    _phone.dispose();
    _locality.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onPhoneChanged() => setState(() {});

  /// The other borrower already using the typed number, if any.
  Borrower? _duplicate(List<Borrower> all) {
    final phones = <String, String>{for (final b in all) b.id: b.phoneE164};
    final id = BorrowerValidators.duplicateOf(
      _phone.text,
      phones,
      selfId: widget.existing?.id,
    );
    if (id == null) return null;
    return all.firstWhere((Borrower b) => b.id == id);
  }

  Future<void> _save(List<Borrower> all) async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_duplicate(all) != null) return;
    setState(() => _busy = true);
    final actions = ref.read(borrowerActionsProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final existing = widget.existing;
      final String id;
      final String text;
      if (existing == null) {
        final created = await actions.create(
          name: _name.text,
          phone: _phone.text,
          locality: _locality.text,
          notes: _notes.text,
        );
        id = created.id;
        text = BorrowerCopy.saved(created.outcome, BorrowerCopy.added);
      } else {
        final outcome = await actions.update(
          id: existing.id,
          name: _name.text,
          phone: _phone.text,
          locality: _locality.text,
          notes: _notes.text,
        );
        id = existing.id;
        text = BorrowerCopy.saved(outcome, BorrowerCopy.updated);
      }
      messenger?.showSnackBar(SnackBar(content: Text(text)));
      if (mounted) navigator.pop(id);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } on Object {
      if (mounted) {
        setState(() => _error = const UnknownFailure(null).userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(borrowersProvider).value ?? const <Borrower>[];
    final duplicate = _duplicate(all);
    final editing = widget.existing != null;
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey<String>('borrower_form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            editing ? 'Edit borrower' : 'Add borrower',
            style: AppTextStyles.headlineSm,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: const ValueKey<String>('borrower_name'),
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: BorrowerValidators.nameMax,
            decoration: const InputDecoration(
              labelText: 'Full name',
              hintText: 'e.g. Suresh Verma',
              counterText: '',
            ),
            validator: BorrowerValidators.name,
          ),
          const SizedBox(height: AppSpacing.md),
          PhoneField(
            fieldKey: const ValueKey<String>('borrower_phone'),
            controller: _phone,
            label: 'Mobile number',
            required: true,
          ),
          if (duplicate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              key: const ValueKey<String>('borrower_phone_duplicate'),
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: AppSizes.iconSm,
                  color: AppColors.overdue,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    BorrowerValidators.duplicatePhone(duplicate.name),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.overdue,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey<String>('borrower_locality'),
            controller: _locality,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: BorrowerValidators.localityMax,
            decoration: const InputDecoration(
              labelText: 'Locality (optional)',
              hintText: 'e.g. Anna Nagar',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey<String>('borrower_notes'),
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            maxLength: BorrowerValidators.notesMax,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              counterText: '',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              key: const ValueKey<String>('borrower_form_error'),
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey<String>('borrower_save'),
            onPressed: _busy || duplicate != null
                ? null
                : () => unawaited(_save(all)),
            child: _busy
                ? const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(editing ? 'Save changes' : 'Save borrower'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
