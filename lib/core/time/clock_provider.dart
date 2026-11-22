import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ist_clock.dart';

part 'clock_provider.g.dart';

/// App-wide [Clock]. Override with a [FixedClock] in tests:
/// `clockProvider.overrideWithValue(FixedClock.ist(2023, 10, 24))`.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => IstClock();
