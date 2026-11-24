import '../../../domain/ledger/ledger.dart';

/// "Due today" chips: All / Pending / Collected.
enum DueTodayFilter { all, pending, collected }

/// Items of [items] that pass [filter] (order kept).
List<TodayDueItem> filterDueToday(
  List<TodayDueItem> items,
  DueTodayFilter filter,
) => switch (filter) {
  DueTodayFilter.all => items,
  DueTodayFilter.pending => <TodayDueItem>[
    for (final i in items)
      if (!i.isPaid) i,
  ],
  DueTodayFilter.collected => <TodayDueItem>[
    for (final i in items)
      if (i.isPaid) i,
  ],
};

/// Basis points as a whole percent, truncated: 9234 → "92%".
String wholePercent(int bps) => '${bps ~/ 100}%';

/// Chart window names: "8 weeks" / "6 months" / "12 months".
String chartPeriodName(ChartPeriod p) => switch (p) {
  ChartPeriod.weeks8 => '8 weeks',
  ChartPeriod.months6 => '6 months',
  ChartPeriod.months12 => '12 months',
};

/// Toggle labels: 8W / 6M / 12M.
String chartPeriodShort(ChartPeriod p) => switch (p) {
  ChartPeriod.weeks8 => '8W',
  ChartPeriod.months6 => '6M',
  ChartPeriod.months12 => '12M',
};
