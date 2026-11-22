import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_breakpoints.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';

void main() {
  group('colour tokens match CLAUDE.md', () {
    const expected = <String, (Color, int)>{
      'background': (AppColors.background, 0xFFF8F9FA),
      'surface': (AppColors.surface, 0xFFFFFFFF),
      'border': (AppColors.border, 0xFFE5E7EB),
      'primary': (AppColors.primary, 0xFF1E3A5F),
      'borderFocus': (AppColors.borderFocus, 0xFF1E3A5F),
      'primarySubtle': (AppColors.primarySubtle, 0xFFEDF2F7),
      'collected': (AppColors.collected, 0xFF2E7D5B),
      'collectedTint': (AppColors.collectedTint, 0xFFEAF5F0),
      'upcoming': (AppColors.upcoming, 0xFFD97706),
      'upcomingTint': (AppColors.upcomingTint, 0xFFFEF3C7),
      'overdue': (AppColors.overdue, 0xFFC2410C),
      'overdueTint': (AppColors.overdueTint, 0xFFFFF1EB),
      'overdueBorder': (AppColors.overdueBorder, 0xFFFED7AA),
      'textPrimary': (AppColors.textPrimary, 0xFF111827),
      'textSecondary': (AppColors.textSecondary, 0xFF6B7280),
      'textTertiary': (AppColors.textTertiary, 0xFF9CA3AF),
      'track': (AppColors.track, 0xFFF1F3F5),
      'pressed': (AppColors.pressed, 0xFFF9FAFB),
    };
    expected.forEach((String name, (Color, int) pair) {
      test(name, () => expect(pair.$1.toARGB32(), pair.$2));
    });

    test('sheet shadow is 0 4 20 -2 rgba(17,24,39,.05)', () {
      const s = AppColors.sheetShadow;
      expect(s.offset, const Offset(0, 4));
      expect(s.blurRadius, 20);
      expect(s.spreadRadius, -2);
      expect(s.color.toARGB32() & 0x00FFFFFF, 0x111827);
      expect((s.color.a * 100).round(), 5);
    });
  });

  test('spacing and radii', () {
    expect(
      <double>[
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ],
      <double>[4, 8, 16, 24, 32],
    );
    expect(
      <double>[
        AppRadii.sm,
        AppRadii.base,
        AppRadii.md,
        AppRadii.lg,
        AppRadii.xl,
      ],
      <double>[4, 8, 12, 16, 24],
    );
  });

  group('typography', () {
    test('every style sets fontWeight and a matching wght variation', () {
      final all = <String, TextStyle>{
        ...AppTextStyles.baseStyles,
        ...AppTextStyles.tabularStyles,
      };
      all.forEach((String name, TextStyle style) {
        expect(style.fontWeight, isNotNull, reason: name);
        final wght = style.fontVariations
            ?.where((FontVariation v) => v.axis == 'wght')
            .toList();
        expect(wght, hasLength(1), reason: name);
        expect(
          wght!.single.value,
          style.fontWeight!.value.toDouble(),
          reason: name,
        );
      });
    });

    test('numeric styles include tabular figures', () {
      AppTextStyles.tabularStyles.forEach((String name, TextStyle style) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: name,
        );
      });
    });

    test('sizes and families', () {
      expect(AppTextStyles.headlineXl.fontSize, 28);
      expect(AppTextStyles.headlineXl.fontFamily, 'PlusJakartaSans');
      expect(AppTextStyles.currencyDisplay.fontSize, 32);
      expect(AppTextStyles.currencyItem.fontSize, 15);
      expect(AppTextStyles.currencyItem.fontFamily, 'Inter');
      expect(AppTextStyles.labelMd.fontSize, 12);
    });
  });

  group('ThemeData', () {
    final theme = AppTheme.light;

    test('Material 3 and scaffold background', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('cards: white, flat, 1px border, radius 16', () {
      final card = theme.cardTheme;
      expect(card.color, AppColors.surface);
      expect(card.elevation, 0);
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.border);
      expect(shape.side.width, 1);
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('filled button: navy, 48 tall, radius 8, flat', () {
      final style = theme.filledButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.primary,
      );
      expect(style.minimumSize!.resolve(<WidgetState>{})!.height, 48);
      expect(style.elevation!.resolve(<WidgetState>{}), 0);
      final shape =
          style.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));
    });

    test('inputs: white fill, focused navy border, radius 8', () {
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, AppColors.surface);
      final focused = input.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, AppColors.primary);
      expect(focused.borderRadius, BorderRadius.circular(8));
    });

    test('navigation indicator is navy', () {
      expect(theme.navigationBarTheme.indicatorColor, AppColors.primary);
      expect(theme.navigationRailTheme.indicatorColor, AppColors.primary);
    });

    test('bottom sheet top radius 24', () {
      final shape = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
    });
  });

  test('breakpoints', () {
    expect(WindowSize.fromWidth(599), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
    expect(WindowSize.compact.margin, 16);
    expect(WindowSize.medium.margin, 24);
    expect(WindowSize.expanded.margin, 32);
    expect(WindowSize.maxContentWidth, 1280);
  });
}
