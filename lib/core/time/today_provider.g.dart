// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Today's IST civil date: the day ticker every projection depends on.
///
/// It changes only through [refresh], which [DayTicker] calls at IST
/// midnight and when the app resumes. Tests override [clockProvider].

@ProviderFor(Today)
final todayProvider = TodayProvider._();

/// Today's IST civil date: the day ticker every projection depends on.
///
/// It changes only through [refresh], which [DayTicker] calls at IST
/// midnight and when the app resumes. Tests override [clockProvider].
final class TodayProvider extends $NotifierProvider<Today, CivilDate> {
  /// Today's IST civil date: the day ticker every projection depends on.
  ///
  /// It changes only through [refresh], which [DayTicker] calls at IST
  /// midnight and when the app resumes. Tests override [clockProvider].
  TodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayHash();

  @$internal
  @override
  Today create() => Today();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CivilDate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CivilDate>(value),
    );
  }
}

String _$todayHash() => r'feeff855bd7e59956191ab7dedb5742eb212adf7';

/// Today's IST civil date: the day ticker every projection depends on.
///
/// It changes only through [refresh], which [DayTicker] calls at IST
/// midnight and when the app resumes. Tests override [clockProvider].

abstract class _$Today extends $Notifier<CivilDate> {
  CivilDate build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CivilDate, CivilDate>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CivilDate, CivilDate>,
              CivilDate,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
