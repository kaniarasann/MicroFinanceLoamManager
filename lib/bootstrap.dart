import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'features/auth/data/secure_key_value_store.dart';
import 'features/onboarding/data/cache_reset_flag.dart';
import 'firebase_options.dart';

/// Initialises platform services, then starts the widget tree.
///
/// Called from `main()` inside `runZonedGuarded`, so binding initialisation
/// and `runApp` happen in the same zone.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline-first: unlimited local cache, persistence on.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // The user lost access to a company last session: wipe the local cache
  // before anything reads or listens.
  await clearFirestoreCacheIfScheduled(
    CacheResetFlag(FlutterSecureKeyValueStore()),
    FirebaseFirestore.instance.clearPersistence,
  );

  // All civil dates are IST (Asia/Kolkata).
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  Intl.defaultLocale = 'en_IN';

  runApp(const ProviderScope(child: App()));
}

/// Calls [clearPersistence] when [flag] is set, then clears the flag.
/// Failures are logged and never block start-up (the flag stays set, so the
/// next cold start retries).
Future<void> clearFirestoreCacheIfScheduled(
  CacheResetFlag flag,
  Future<void> Function() clearPersistence,
) async {
  try {
    if (!await flag.isPending()) return;
    await clearPersistence();
    await flag.clear();
    developer.log('Firestore cache cleared', name: 'bootstrap');
  } on Object catch (e, st) {
    developer.log(
      'Firestore cache clear failed',
      name: 'bootstrap',
      error: e,
      stackTrace: st,
    );
  }
}
