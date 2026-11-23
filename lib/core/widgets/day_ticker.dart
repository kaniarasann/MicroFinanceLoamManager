import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../time/today_provider.dart';

/// Keeps [todayProvider] current while [child] is mounted: refreshes it at
/// IST midnight (plus a small margin) and whenever the app resumes. Mounted
/// once around the app shell.
class DayTicker extends ConsumerStatefulWidget {
  const DayTicker({required this.child, super.key});

  final Widget child;

  /// Added to the midnight timer so the clock has surely rolled over.
  static const Duration margin = Duration(seconds: 2);

  @override
  ConsumerState<DayTicker> createState() => _DayTickerState();
}

class _DayTickerState extends ConsumerState<DayTicker> {
  AppLifecycleListener? _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _tick);
    _schedule();
  }

  void _tick() {
    ref.read(todayProvider.notifier).refresh();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final wait = ref.read(todayProvider.notifier).untilMidnight();
    _timer = Timer(wait + DayTicker.margin, _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
