import 'package:flutter/material.dart';

import '../../../core/money/inr_format.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../../core/widgets/adaptive_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/kpi_tile.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../core/widgets/status_pill.dart';

/// Temporary design gallery (Sprint 1). Replaced by real routing in Sprint 3.
class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({required this.projectId, super.key});

  final String projectId;

  static const List<AdaptiveDestination> destinations = <AdaptiveDestination>[
    AdaptiveDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    AdaptiveDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Calendar',
    ),
    AdaptiveDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Borrowers',
    ),
    AdaptiveDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

enum _Range { weeks8, months6, months12 }

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  int _destination = 0;
  _Range _range = _Range.weeks8;
  Money? _typed;

  static const List<Money> _samples = <Money>[
    Money(0),
    Money(99900),
    Money(123450),
    Money(10000000),
    Money(123456700),
    Money(1000000000),
    Money(-100000),
  ];

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    return AdaptiveScaffold(
      destinations: ThemeGalleryScreen.destinations,
      selectedIndex: _destination,
      onDestinationSelected: (int i) => setState(() => _destination = i),
      appBar: AppBar(title: const Text('Theme gallery')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _toast('New loan'),
        tooltip: 'New loan',
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: <Widget>[
          const OfflineBanner(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nordic Ledger: Firebase connected: ${widget.projectId}',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text('Window: ${size.name}', style: AppTextStyles.labelMd),
          const SectionHeader(title: 'Portfolio'),
          _KpiGrid(columns: size.tileColumns),
          const SectionHeader(title: 'Status pills'),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatusPill(label: 'Collected', kind: StatusKind.collected),
              StatusPill(label: 'Due soon', kind: StatusKind.upcoming),
              StatusPill(
                label: 'Overdue',
                kind: StatusKind.overdue,
                icon: Icons.error_outline,
              ),
              StatusPill(label: 'Closed', kind: StatusKind.neutral),
              StatusPill(
                label: 'Synced',
                kind: StatusKind.info,
                icon: Icons.cloud_done_outlined,
              ),
            ],
          ),
          const SectionHeader(title: 'Buttons'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context,
                  (BuildContext c) => const _SheetDemo(),
                ),
                child: const Text('Record payment'),
              ),
              OutlinedButton.icon(
                onPressed: () => _toast('Calling…'),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
              TextButton(
                onPressed: () => _toast('View all'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SectionHeader(title: 'Inputs'),
          CurrencyField(
            label: 'Amount received',
            onChanged: (Money? m) => setState(() => _typed = m),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _typed == null ? 'Parsed: —' : 'Parsed: ${formatInr(_typed!)}',
            style: AppTextStyles.bodyMdTabular,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedToggle<_Range>(
            segments: const <ToggleSegment<_Range>>[
              ToggleSegment<_Range>(value: _Range.weeks8, label: '8W'),
              ToggleSegment<_Range>(value: _Range.months6, label: '6M'),
              ToggleSegment<_Range>(value: _Range.months12, label: '12M'),
            ],
            selected: _range,
            onChanged: (_Range r) => setState(() => _range = r),
          ),
          const SectionHeader(title: 'MPIN pad'),
          AppCard(
            padding: AppCardPadding.spacious,
            child: Center(
              child: PinPad(
                onCompleted: (_) => _toast('PIN entered'),
                onBiometric: () => _toast('Biometric unlock'),
              ),
            ),
          ),
          const SectionHeader(title: 'Money samples'),
          AppCard(
            child: Column(
              children: <Widget>[
                for (final m in _samples)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: MoneyText(m)),
                        MoneyText(
                          m,
                          short: true,
                          style: AppTextStyles.labelMdTabular,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Empty state'),
          AppCard(
            onTap: () => _toast('Card tapped'),
            child: const EmptyState(
              icon: Icons.people_outline,
              title: 'No borrowers yet',
              message: 'Add your first borrower to start a contract.',
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.columns});

  final int columns;

  static const List<KpiTile> _tiles = <KpiTile>[
    KpiTile(
      label: 'Net disbursed',
      value: Money.fromRupees(2294000),
      caption: '42 active contracts',
    ),
    KpiTile(
      label: 'Sanctioned receivable',
      value: Money.fromRupees(2850000),
      caption: 'Outstanding on active loans',
    ),
    KpiTile(
      label: 'Collected',
      value: Money.fromRupees(1240500),
      caption: 'This month',
      valueKind: StatusKind.collected,
    ),
    KpiTile(
      label: 'Overdue',
      value: Money.fromRupees(185000),
      caption: '7 installments',
      valueKind: StatusKind.overdue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < _tiles.length; start += columns) {
      final end = (start + columns).clamp(0, _tiles.length);
      final cells = <Widget>[];
      for (var i = start; i < start + columns; i++) {
        if (i > start) cells.add(const SizedBox(width: AppSpacing.md));
        cells.add(
          Expanded(child: i < end ? _tiles[i] : const SizedBox.shrink()),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.md));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _SheetDemo extends StatelessWidget {
  const _SheetDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Record payment', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.md),
        const CurrencyField(label: 'Amount', initialValue: Money(500000)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
