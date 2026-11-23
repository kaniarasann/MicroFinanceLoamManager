import 'package:flutter/material.dart';

/// Nordic Ledger design tokens. The ONLY place hex colours, font sizes,
/// radii, paddings and shadows may be written (see root `CLAUDE.md`).
abstract final class AppColors {
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color primary = Color(0xFF1E3A5F);
  static const Color borderFocus = primary;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primarySubtle = Color(0xFFEDF2F7);

  static const Color collected = Color(0xFF2E7D5B);
  static const Color collectedTint = Color(0xFFEAF5F0);
  static const Color upcoming = Color(0xFFD97706);
  static const Color upcomingTint = Color(0xFFFEF3C7);
  static const Color overdue = Color(0xFFC2410C);
  static const Color overdueTint = Color(0xFFFFF1EB);
  static const Color overdueBorder = Color(0xFFFED7AA);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color track = Color(0xFFF1F3F5);
  static const Color pressed = Color(0xFFF9FAFB);
  static const Color transparent = Color(0x00000000);

  /// Google brand colours, used only by the "Continue with Google" mark.
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  /// `rgba(17,24,39,.05)`: colour of the single ambient sheet shadow.
  static const Color shadow = Color(0x0D111827);

  /// Sheets/dialogs only: `0 4 20 -2 rgba(17,24,39,.05)`.
  static const BoxShadow sheetShadow = BoxShadow(
    color: shadow,
    offset: Offset(0, 4),
    blurRadius: 20,
    spreadRadius: -2,
  );
}

/// 4/8 spacing rhythm.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Card padding: 16 compact, 24 for balance summaries.
  static const double cardCompact = md;
  static const double cardSpacious = lg;
}

/// Component insets built from [AppSpacing].
abstract final class AppInsets {
  static const EdgeInsets cardCompact = EdgeInsets.all(AppSpacing.cardCompact);
  static const EdgeInsets cardSpacious = EdgeInsets.all(
    AppSpacing.cardSpacious,
  );
  static const EdgeInsets pill = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: AppSpacing.xs,
  );
  static const EdgeInsets segment = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xs,
  );
  static const EdgeInsets segmentTrack = EdgeInsets.all(AppSpacing.xs);
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.md,
  );
  static const EdgeInsets currencyPrefix = EdgeInsets.only(
    left: AppSpacing.md,
    right: AppSpacing.sm,
  );
  static const EdgeInsets banner = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.lg,
    AppSpacing.lg,
  );
  static const EdgeInsets sectionHeader = EdgeInsets.only(
    top: AppSpacing.lg,
    bottom: AppSpacing.sm,
  );
  static const EdgeInsets emptyState = EdgeInsets.all(AppSpacing.xl);

  /// Vertical padding of a plain list line (ledger rows, receipts).
  static const EdgeInsets listRow = EdgeInsets.symmetric(
    vertical: AppSpacing.sm,
  );
}

/// Fixed component dimensions.
abstract final class AppSizes {
  static const double buttonHeight = 48;
  static const double inputHeight = 56;
  static const double minTouchTarget = 48;
  static const double pillHeight = 28;
  static const double statusDot = 6;
  static const double segmentHeight = 40;
  static const double pinKey = 64;
  static const double pinDot = 14;
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double emptyStateBadge = 64;
  static const double borderWidth = 1;
  static const double dialogMaxWidth = 560;
  static const double navigationBarHeight = 72;

  /// Brand tile: 96dp on the splash, 64dp on sign-in / MPIN.
  static const double brandTileLg = 96;
  static const double brandTileMd = 64;

  /// Auth / lock screens: content column max width (centred on tablets).
  static const double authContentMaxWidth = 420;

  /// Splash "Syncing your ledger…" bar.
  static const double splashProgressWidth = 160;
  static const double progressBarHeight = 4;

  /// Google "G" mark inside the sign-in button.
  static const double googleMark = 20;

  /// Horizontal amplitude of the wrong-MPIN shake.
  static const double shakeOffset = 8;

  /// Onboarding (register / join) content column max width.
  static const double onboardingMaxWidth = 560;

  /// One invite-code character box.
  static const double codeBoxWidth = 48;
  static const double codeBoxHeight = 56;

  /// Avatars: account chip / switcher rows (sm), company tile (md).
  static const double avatarSm = 32;
  static const double avatarMd = 40;

  /// Borrower profile header avatar.
  static const double avatarLg = 56;

  /// Contract card "cleared %" bar.
  static const double clearedBarHeight = 8;

  /// Long single-column forms (create contract): content max width.
  static const double formMaxWidth = 720;

  /// Contract timeline: overdue left rail width.
  static const double timelineRail = 4;

  /// Dashed border of auto-extension rows: dash and gap length.
  static const double dashLength = 6;
  static const double dashGap = 4;
}

/// Corner radii.
abstract final class AppRadii {
  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius baseAll = BorderRadius.all(Radius.circular(base));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xlTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Typography. Fonts are bundled VARIABLE fonts, so every style sets both
/// [TextStyle.fontWeight] and a matching `wght` [FontVariation].
abstract final class AppTextStyles {
  static const String jakarta = 'PlusJakartaSans';
  static const String inter = 'Inter';

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const List<FontVariation> _w400 = <FontVariation>[
    FontVariation('wght', 400),
  ];
  static const List<FontVariation> _w500 = <FontVariation>[
    FontVariation('wght', 500),
  ];
  static const List<FontVariation> _w600 = <FontVariation>[
    FontVariation('wght', 600),
  ];
  static const List<FontVariation> _w700 = <FontVariation>[
    FontVariation('wght', 700),
  ];

  // Headlines: Plus Jakarta Sans.
  static const TextStyle headlineXl = TextStyle(
    fontFamily: jakarta,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    letterSpacing: -0.56, // -0.02em
    color: AppColors.textPrimary,
  );
  static const TextStyle headlineLg = TextStyle(
    fontFamily: jakarta,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle headlineSm = TextStyle(
    fontFamily: jakarta,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );

  // Body and labels: Inter.
  static const TextStyle titleMd = TextStyle(
    fontFamily: inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyLg = TextStyle(
    fontFamily: inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    fontVariations: _w400,
    color: AppColors.textSecondary,
  );

  /// Button labels.
  static const TextStyle labelLg = TextStyle(
    fontFamily: inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle labelMd = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    fontVariations: _w500,
    letterSpacing: 0.24, // +0.02em
    color: AppColors.textPrimary,
  );

  /// Status pills and emphasised small labels.
  static const TextStyle labelMdStrong = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    letterSpacing: 0.24,
    color: AppColors.textPrimary,
  );

  // Currency: always tabular.
  static const TextStyle currencyDisplay = TextStyle(
    fontFamily: jakarta,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontVariations: _w700,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );
  static const TextStyle currencyItem = TextStyle(
    fontFamily: inter,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// The `₹` prefix inside currency inputs: PJS 600, textSecondary.
  static const TextStyle currencyPrefix = TextStyle(
    fontFamily: jakarta,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    fontVariations: _w600,
    color: AppColors.textSecondary,
  );

  /// Invite codes in the message preview chip: monospace bold, spaced.
  static const TextStyle codeMono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    fontFeatures: _tabular,
    color: AppColors.primary,
  );

  // Tabular variants for amounts, counts, dates and phone numbers.
  static final TextStyle headlineXlTabular = _tab(headlineXl);
  static final TextStyle headlineLgTabular = _tab(headlineLg);
  static final TextStyle headlineSmTabular = _tab(headlineSm);
  static final TextStyle titleMdTabular = _tab(titleMd);
  static final TextStyle bodyLgTabular = _tab(bodyLg);
  static final TextStyle bodyMdTabular = _tab(bodyMd);
  static final TextStyle bodySmTabular = _tab(bodySm);
  static final TextStyle labelLgTabular = _tab(labelLg);
  static final TextStyle labelMdTabular = _tab(labelMd);
  static const TextStyle currencyDisplayTabular = currencyDisplay;
  static const TextStyle currencyItemTabular = currencyItem;

  /// Every tabular style, for tests and tooling.
  static final Map<String, TextStyle> tabularStyles = <String, TextStyle>{
    'headlineXlTabular': headlineXlTabular,
    'headlineLgTabular': headlineLgTabular,
    'headlineSmTabular': headlineSmTabular,
    'titleMdTabular': titleMdTabular,
    'bodyLgTabular': bodyLgTabular,
    'bodyMdTabular': bodyMdTabular,
    'bodySmTabular': bodySmTabular,
    'labelLgTabular': labelLgTabular,
    'labelMdTabular': labelMdTabular,
    'currencyDisplay': currencyDisplay,
    'currencyItem': currencyItem,
    'currencyDisplayTabular': currencyDisplayTabular,
    'currencyItemTabular': currencyItemTabular,
  };

  /// Every base style, for tests and tooling.
  static const Map<String, TextStyle> baseStyles = <String, TextStyle>{
    'headlineXl': headlineXl,
    'headlineLg': headlineLg,
    'headlineSm': headlineSm,
    'titleMd': titleMd,
    'bodyLg': bodyLg,
    'bodyMd': bodyMd,
    'bodySm': bodySm,
    'labelLg': labelLg,
    'labelMd': labelMd,
    'labelMdStrong': labelMdStrong,
    'currencyDisplay': currencyDisplay,
    'currencyItem': currencyItem,
    'currencyPrefix': currencyPrefix,
  };

  /// Returns [style] with tabular figures added (idempotent).
  static TextStyle tabular(TextStyle style) => _tab(style);

  static TextStyle _tab(TextStyle style) {
    final existing = style.fontFeatures ?? const <FontFeature>[];
    if (existing.contains(const FontFeature.tabularFigures())) return style;
    return style.copyWith(
      fontFeatures: <FontFeature>[
        ...existing,
        const FontFeature.tabularFigures(),
      ],
    );
  }
}

/// Material 3 theme built only from the tokens above.
abstract final class AppTheme {
  static const BorderSide _border = BorderSide(color: AppColors.border);

  static const TextTheme textTheme = TextTheme(
    displayLarge: AppTextStyles.currencyDisplay,
    displayMedium: AppTextStyles.currencyDisplay,
    displaySmall: AppTextStyles.currencyDisplay,
    headlineLarge: AppTextStyles.headlineXl,
    headlineMedium: AppTextStyles.headlineLg,
    headlineSmall: AppTextStyles.headlineSm,
    titleLarge: AppTextStyles.headlineSm,
    titleMedium: AppTextStyles.titleMd,
    titleSmall: AppTextStyles.labelLg,
    bodyLarge: AppTextStyles.bodyLg,
    bodyMedium: AppTextStyles.bodyMd,
    bodySmall: AppTextStyles.bodySm,
    labelLarge: AppTextStyles.labelLg,
    labelMedium: AppTextStyles.labelMd,
    labelSmall: AppTextStyles.labelMd,
  );

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primarySubtle,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.collected,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.collectedTint,
    onSecondaryContainer: AppColors.collected,
    tertiary: AppColors.upcoming,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: AppColors.upcomingTint,
    onTertiaryContainer: AppColors.textPrimary,
    error: AppColors.overdue,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.overdueTint,
    onErrorContainer: AppColors.overdue,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.track,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    shadow: AppColors.shadow,
    scrim: AppColors.textPrimary,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.primarySubtle,
    surfaceTint: AppColors.transparent,
  );

  static WidgetStateProperty<T> _selected<T>(T selected, T other) =>
      WidgetStateProperty.resolveWith<T>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? selected : other,
      );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    fontFamily: AppTextStyles.inter,
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    highlightColor: AppColors.pressed,
    splashColor: AppColors.track,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: AppSizes.borderWidth,
      space: AppSizes.borderWidth,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.headlineSm,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: _border,
        borderRadius: AppRadii.lgAll,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.track,
        disabledForegroundColor: AppColors.textTertiary,
        minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
        padding: AppInsets.button,
        elevation: 0,
        shadowColor: AppColors.transparent,
        textStyle: AppTextStyles.labelLg,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.baseAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textTertiary,
        minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
        padding: AppInsets.button,
        elevation: 0,
        side: _border,
        textStyle: AppTextStyles.labelLg,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.baseAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textTertiary,
        minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
        textStyle: AppTextStyles.labelLg,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.baseAll),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: AppInsets.input,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
      helperStyle: AppTextStyles.bodySm,
      errorStyle: TextStyle(color: AppColors.overdue),
      border: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: _border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: _border,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: _border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: BorderSide(color: AppColors.borderFocus),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: BorderSide(color: AppColors.overdue),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.baseAll,
        borderSide: BorderSide(color: AppColors.overdue),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.transparent,
      elevation: 0,
      height: AppSizes.navigationBarHeight,
      indicatorColor: AppColors.primary,
      indicatorShape: const StadiumBorder(),
      iconTheme: _selected<IconThemeData>(
        const IconThemeData(color: AppColors.onPrimary),
        const IconThemeData(color: AppColors.textSecondary),
      ),
      labelTextStyle: _selected<TextStyle>(
        AppTextStyles.labelMd.copyWith(color: AppColors.primary),
        AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      useIndicator: true,
      indicatorColor: AppColors.primary,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: const IconThemeData(color: AppColors.onPrimary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.labelMd.copyWith(
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: AppTextStyles.labelMd.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primarySubtle,
      disabledColor: AppColors.track,
      side: _border,
      shape: StadiumBorder(side: _border),
      labelStyle: AppTextStyles.labelMd,
      secondaryLabelStyle: AppTextStyles.labelMd,
      padding: AppInsets.pill,
      elevation: 0,
      pressElevation: 0,
      checkmarkColor: AppColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: AppTextStyles.bodyMd.copyWith(
        color: AppColors.onPrimary,
      ),
      actionTextColor: AppColors.primarySubtle,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.baseAll),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.shadow,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xlTop),
      constraints: BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.shadow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      titleTextStyle: AppTextStyles.headlineSm,
      contentTextStyle: AppTextStyles.bodyMd,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.track,
      circularTrackColor: AppColors.track,
    ),
  );
}
