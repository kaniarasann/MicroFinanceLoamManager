import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'civil_date.dart';

export 'civil_date.dart';

/// Real clock backed by the timezone database's Asia/Kolkata location.
final class IstClock implements Clock {
  IstClock();

  static const String locationName = 'Asia/Kolkata';

  tz.Location? _location;

  tz.Location get _ist {
    final cached = _location;
    if (cached != null) return cached;
    tz.Location location;
    try {
      location = tz.getLocation(locationName);
    } on tz.LocationNotFoundException {
      // bootstrap() normally initialises the database; tests may not.
      tz_data.initializeTimeZones();
      location = tz.getLocation(locationName);
    }
    return _location = location;
  }

  @override
  DateTime nowIst() => tz.TZDateTime.now(_ist);
}

/// Deterministic clock for tests. [now] is interpreted as IST wall time.
final class FixedClock implements Clock {
  FixedClock(this.now);

  /// Convenience: an IST wall-clock moment.
  FixedClock.ist(int year, int month, int day, [int hour = 9, int minute = 0])
    : now = DateTime(year, month, day, hour, minute);

  DateTime now;

  @override
  DateTime nowIst() => now;
}
