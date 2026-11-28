import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The two in-app legal documents. They ship with the app, so they open
/// offline and before sign-in.
enum LegalDocument { privacy, terms }

/// One section of a legal document.
typedef LegalSection = ({String heading, String body});

/// Privacy policy text.
const List<LegalSection> privacySections = <LegalSection>[
  (
    heading: 'What Nordic Ledger is',
    body:
        'Nordic Ledger is a bookkeeping app for lenders. It records the loans '
        'your company gives, the schedule and the payments you collect. It '
        'does not lend money, check credit or move money.',
  ),
  (
    heading: 'What we store',
    body:
        'Your Google account name, email and photo link; the display name and '
        'mobile number you enter; the companies you belong to and your role; '
        'and the ledger your company enters: borrowers (name, phone, '
        'locality, notes), loans, schedules and payments. Every entry records '
        'who made it and when.',
  ),
  (
    heading: 'Where it is stored',
    body:
        'Data is stored in Google Cloud Firestore and kept in an offline '
        'copy on your phone so the app works without internet. Only members '
        "of a company can read that company's data; this is enforced by the "
        'server, not only by the app.',
  ),
  (
    heading: 'What stays on your phone',
    body:
        'Your MPIN is stored only as a salted hash in the phone\'s secure '
        'storage and never leaves the device. Fingerprint unlock uses the '
        'phone\'s own biometric system; we never see your fingerprint. '
        'Collection reminders are notifications scheduled on this phone for '
        'you. Borrowers are never messaged automatically: calls, SMS and '
        'WhatsApp messages open only when you tap them.',
  ),
  (
    heading: 'Sharing',
    body:
        'We do not sell your data or show ads. Your data is shared only with '
        'the members of your company and with Google as our hosting '
        'provider.',
  ),
  (
    heading: 'Deleting your account',
    body:
        'Settings → Delete account removes your sign-in, profile, settings '
        'and memberships. Loan and payment records you entered stay with '
        'your company, because they are its financial records; they keep '
        'your name as the person who recorded them. If you are the only '
        'member of a company, the company is closed and can no longer be '
        'opened.',
  ),
];

/// Terms of service text.
const List<LegalSection> termsSections = <LegalSection>[
  (
    heading: 'Using the app',
    body:
        'Nordic Ledger helps you keep your own lending records. You are '
        'responsible for the accuracy of what you enter and for following '
        'the laws that apply to your lending business.',
  ),
  (
    heading: 'Companies and roles',
    body:
        'Owners manage borrowers, loans, rollovers, members and invites. '
        'Collectors can view their company\'s ledger, record payments and '
        'reschedule installments. Invite only people you trust.',
  ),
  (
    heading: 'Records are permanent',
    body:
        'Payments are never edited or deleted; a mistake is corrected with a '
        'reversal, so the history always adds up.',
  ),
  (
    heading: 'Offline use',
    body:
        'Changes made offline are saved on your phone and sync when you are '
        'back online. Joining a company and deleting your account need a '
        'connection.',
  ),
  (
    heading: 'No warranty',
    body:
        'The app is provided as is. Reminders are local notifications that '
        'your phone may delay or block; always check the app for what is '
        'due.',
  ),
];

/// Privacy policy / terms page.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final (String title, List<LegalSection> sections) = switch (document) {
      LegalDocument.privacy => ('Privacy policy', privacySections),
      LegalDocument.terms => ('Terms of service', termsSections),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          key: ValueKey<String>('legal_${document.name}'),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final s in sections) ...<Widget>[
                    Semantics(
                      header: true,
                      child: Text(s.heading, style: AppTextStyles.headlineSm),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(s.body, style: AppTextStyles.bodyLg),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
