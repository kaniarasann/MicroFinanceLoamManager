import 'dart:async';
import 'dart:developer' as developer;

import 'bootstrap.dart';

void main() {
  runZonedGuarded<Future<void>>(bootstrap, (Object error, StackTrace stack) {
    developer.log(
      'Uncaught zone error',
      name: 'nordic_ledger',
      error: error,
      stackTrace: stack,
    );
  });
}
