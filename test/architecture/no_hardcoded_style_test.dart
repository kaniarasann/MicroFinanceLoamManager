import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens and shared widgets must take colours and type sizes from
/// `lib/core/theme/` tokens only.
void main() {
  const roots = <String>['lib/features', 'lib/core/widgets'];

  final rules = <String, RegExp>{
    'Color(0x literal': RegExp(r'Color\(0x'),
    // `Colors.` not preceded by an identifier char (so `AppColors.` is fine),
    // except `Colors.transparent`.
    'Colors.* (except transparent)': RegExp(
      r'(?<![A-Za-z0-9_$])Colors\.(?!transparent\b)',
    ),
    'fontSize:': RegExp(r'fontSize\s*:'),
  };

  test(
    'no hard-coded colours or font sizes in features and shared widgets',
    () {
      final violations = <String>[];
      for (final root in roots) {
        final dir = Directory(root);
        expect(dir.existsSync(), isTrue, reason: '$root must exist');
        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'));
        for (final file in files) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            rules.forEach((String name, RegExp pattern) {
              if (pattern.hasMatch(lines[i])) {
                violations.add('${file.path}:${i + 1}: $name');
              }
            });
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Use AppColors / AppTextStyles tokens:\n${violations.join('\n')}',
      );
    },
  );

  test('the guard patterns catch violations', () {
    expect(
      rules['Colors.* (except transparent)']!.hasMatch('Colors.red'),
      isTrue,
    );
    expect(
      rules['Colors.* (except transparent)']!.hasMatch('Colors.transparent'),
      isFalse,
    );
    expect(
      rules['Colors.* (except transparent)']!.hasMatch('AppColors.primary'),
      isFalse,
    );
    expect(rules['Color(0x literal']!.hasMatch('Color(0xFF000000)'), isTrue);
    expect(rules['fontSize:']!.hasMatch('fontSize: 12'), isTrue);
  });
}
