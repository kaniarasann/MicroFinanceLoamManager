import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../application/dashboard_filters.dart';
import '../../application/portfolio_providers.dart';

/// "Collections · last 8 weeks": one y-axis (short ₹), a wide neutral
/// "due" bar per period with the sage "collected" bar inside it (lighter
/// for the current period), a tooltip on tap, the Collected / Due legend
/// and the collection-rate summary, which is also the chart's semantics
/// label. [allowYear] adds the 12M option (tablets).
class CollectionsChart extends ConsumerStatefulWidget {
  const CollectionsChart({this.allowYear = false, super.key});

  final bool allowYear;

  @override
  ConsumerState<CollectionsChart> createState() => _CollectionsChartState();
}

class _CollectionsChartState extends ConsumerState<CollectionsChart> {
  ChartPeriod _period = ChartPeriod.weeks8;

  @override
  Widget build(BuildContext context) {
    final period = !widget.allowYear && _period == ChartPeriod.months12
        ? ChartPeriod.months6
        : _period;
    final buckets =
        ref.watch(collectionsSeriesProvider(period)) ??
        const <CollectionBucket>[];
    final totals = SeriesTotals.of(buckets);
    final name = chartPeriodName(period);
    final summary =
        '$name collection rate ${wholePercent(totals.rateBps)} · '
        '${formatInr(totals.collected)} of ${formatInr(totals.due)}';

    return AppCard(
      key: const ValueKey<String>('collections_chart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  'Collections · last $name',
                  style: AppTextStyles.headlineSm,
                ),
              ),
              SegmentedToggle<ChartPeriod>(
                key: const ValueKey<String>('chart_period'),
                segments: <ToggleSegment<ChartPeriod>>[
                  for (final p in <ChartPeriod>[
                    ChartPeriod.weeks8,
                    ChartPeriod.months6,
                    if (widget.allowYear) ChartPeriod.months12,
                  ])
                    ToggleSegment<ChartPeriod>(
                      value: p,
                      label: chartPeriodShort(p),
                    ),
                ],
                selected: period,
                onChanged: (ChartPeriod p) => setState(() => _period = p),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: _semantics(name, buckets, summary),
            container: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: AppSizes.chartHeight,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) =>
                      _chart(buckets, period, c.maxWidth),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _LegendKey(color: AppColors.collected, label: 'Collected'),
              _LegendKey(color: AppColors.chartDue, label: 'Due'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: Text(
              summary,
              key: const ValueKey<String>('chart_summary'),
              style: AppTextStyles.bodySmTabular,
            ),
          ),
        ],
      ),
    );
  }

  static String _semantics(
    String name,
    List<CollectionBucket> buckets,
    String summary,
  ) {
    final parts = <String>[
      'Collections chart, last $name.',
      for (final b in buckets)
        '${b.label}: due ${formatInr(b.due)}, '
            'collected ${formatInr(b.collected)}.',
      '$summary.',
    ];
    return parts.join(' ');
  }

  Widget _chart(
    List<CollectionBucket> buckets,
    ChartPeriod period,
    double width,
  ) {
    final peak = SeriesTotals.peak(buckets).paise / 100;
    final step = niceAxisStep(peak);
    final maxY = step * 4;
    final weekly = period == ChartPeriod.weeks8;
    // Thin out x labels when each period gets too little width.
    final perBar = buckets.isEmpty
        ? width
        : (width - AppSizes.chartAxisReserved) / buckets.length;
    final labelEvery = perBar < AppSizes.chartMinLabelSlot ? 2 : 1;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (double _) => const FlLine(
            color: AppColors.track,
            strokeWidth: AppSizes.chartGridLine,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: AppSizes.chartAxisReserved,
              interval: step,
              getTitlesWidget: (double v, TitleMeta meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatInrShort(Money((v * 100).round())),
                  style: AppTextStyles.bodySmTabular,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: AppSizes.chartBottomReserved,
              getTitlesWidget: (double v, TitleMeta meta) {
                final i = v.toInt();
                final show =
                    i >= 0 &&
                    i < buckets.length &&
                    (i % labelEvery == 0 || i == buckets.length - 1);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    show ? buckets[i].label : '',
                    style: AppTextStyles.bodySmTabular,
                    maxLines: 1,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchExtraThreshold: const EdgeInsets.symmetric(
            horizontal: AppSizes.chartTouchSlop,
          ),
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (BarChartGroupData _) => AppColors.tooltip,
            tooltipBorderRadius: AppRadii.baseAll,
            tooltipPadding: AppInsets.tooltip,
            maxContentWidth: AppSizes.chartTooltipMaxWidth,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem:
                (BarChartGroupData group, int i, BarChartRodData _, int _) {
                  final b = buckets[i];
                  final rate = b.due.isPositive
                      ? ' (${wholePercent(b.rateBps)})'
                      : '';
                  return BarTooltipItem(
                    '${b.label}${weekly ? ' week' : ''}\n'
                    'Due ${formatInr(b.due)}\n'
                    'Collected ${formatInr(b.collected)}$rate',
                    AppTextStyles.bodySmTabular.copyWith(
                      color: AppColors.onPrimary,
                    ),
                    textAlign: TextAlign.start,
                  );
                },
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              groupVertically: true,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: buckets[i].due.paise / 100,
                  width: AppSizes.chartDueBar,
                  color: AppColors.chartDue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.sm),
                  ),
                ),
                BarChartRodData(
                  toY: buckets[i].collected.isNegative
                      ? 0
                      : buckets[i].collected.paise / 100,
                  width: AppSizes.chartCollectedBar,
                  color: buckets[i].isCurrent
                      ? AppColors.collectedSoft
                      : AppColors.collected,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.sm),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A "nice" y-axis step (1, 2, 2.5 or 5 × 10ⁿ rupees) so that four steps
/// cover [peakRupees]. At least ₹1,000 so an empty chart still has an axis.
double niceAxisStep(double peakRupees) {
  final raw = peakRupees / 4;
  var magnitude = 1000.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final f in <double>[1, 2, 2.5, 5, 10]) {
    if (magnitude * f >= raw) return magnitude * f;
  }
  return magnitude * 10;
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: AppSizes.legendSwatch,
        height: AppSizes.legendSwatch,
        decoration: BoxDecoration(color: color, borderRadius: AppRadii.smAll),
      ),
      const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
      Text(
        label,
        style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}
