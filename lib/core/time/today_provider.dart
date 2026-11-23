import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'clock_provider.dart';
import 'ist_clock.dart';

part 'today_provider.g.dart';

/// Today's IST civil date: the day ticker every projection depends on.
///
/// It changes only through [refresh], which [DayTicker] calls at IST
/// midnight and when the app resumes. Tests override [clockProvider].
@Riverpod(keepAlive: true)
class Today extends _$Today {
  @override
  CivilDate build() => CivilDate.todayIst(ref.watch(clockProvider));

  /// Re-reads the clock; notifies only when the date actually changed.
  void refresh() {
    final now = CivilDate.todayIst(ref.read(clockProvider));
    if (now != state) state = now;
  }

  /// Time left until the next IST midnight (at least 1 second).
  Duration untilMidnight() {
    final now = ref.read(clockProvider).nowIst();
    final elapsed = Duration(
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      milliseconds: now.millisecond,
    );
    final left = const Duration(days: 1) - elapsed;
    return left < const Duration(seconds: 1)
        ? const Duration(seconds: 1)
        : left;
  }
}
