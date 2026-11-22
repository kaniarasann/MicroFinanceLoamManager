import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/domain/` must stay pure Dart: no Flutter, Firebase or dart:ui.
void main() {
  const forbidden = <String>[
    'package:flutter/',
    'package:cloud_firestore',
    'package:firebase_',
    'dart:ui',
  ];

  final directivePattern = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  test('lib/domain imports no Flutter, Firebase or dart:ui', () {
    final domainDir = Directory('lib/domain');
    expect(
      domainDir.existsSync(),
      isTrue,
      reason: 'lib/domain/ must exist (run tests from the package root)',
    );

    final violations = <String>[];
    final dartFiles = domainDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final match in directivePattern.allMatches(source)) {
        final uri = match.group(1)!;
        if (forbidden.any(uri.startsWith)) {
          violations.add('${file.path}: $uri');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Forbidden imports in lib/domain/:\n${violations.join('\n')}',
    );
  });
}
