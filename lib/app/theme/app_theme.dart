import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/presentation/motion.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF00552F);
  static const brandYellow = Color(0xFFFFD51E);
  static const darkGreen = Color(0xFF004225);
  static const white = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF4F7F3);
  static const primaryText = Color(0xFF202321);
  static const secondaryText = Color(0xFF777C79);
  static const hairline = Color(0xFFE6EBE6);
  static const mist = Color(0xFFEEF4EF);
  static const navBackground = Color(0xFF004D2B);
  static const navSelected = Color(0xFFFFC900);

  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 28.0;

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x14001810),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get softShadow => const [
    BoxShadow(
      color: Color(0x0F001810),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  static const _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.15,
      color: primaryText,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.2,
      color: primaryText,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.2,
      color: primaryText,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: primaryText,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      color: primaryText,
    ),
    bodyLarge: TextStyle(height: 1.4, color: primaryText),
    bodyMedium: TextStyle(height: 1.4, color: primaryText),
    bodySmall: TextStyle(height: 1.4, color: secondaryText),
    labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
  );

  static ButtonStyle get _filledButton => FilledButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: white,
    disabledBackgroundColor: const Color(0xFFB7C4BA),
    disabledForegroundColor: white,
    elevation: 0,
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );

  static final light = ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryGreen,
          onPrimary: white,
          secondary: brandYellow,
          onSecondary: darkGreen,
          surface: white,
          onSurface: primaryText,
          surfaceContainerLowest: white,
          surfaceContainerLow: mist,
          error: const Color(0xFFB63E32),
          onError: white,
          outline: hairline,
        ),
    scaffoldBackgroundColor: lightBackground,
    textTheme: _textTheme,
    iconTheme: const IconThemeData(color: primaryText),
    dividerColor: hairline,
    dividerTheme: const DividerThemeData(
      color: hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: hairline),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _filledButton),
    filledButtonTheme: FilledButtonThemeData(style: _filledButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen, width: 1.2),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      hintStyle: const TextStyle(color: secondaryText, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryGreen, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: mist,
      selectedColor: const Color(0xFFE8F3E9),
      labelStyle: const TextStyle(
        color: primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: darkGreen,
      contentTextStyle: const TextStyle(color: white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFD5DDD6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: brandYellow,
      unselectedLabelColor: white,
      indicatorColor: brandYellow,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryGreen,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 2,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: navBackground,
      selectedItemColor: navSelected,
      unselectedItemColor: white,
      type: BottomNavigationBarType.fixed,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const ShopzyPageTransitionsBuilder(),
      },
    ),
  );
}

class ShopzyPageTransitionsBuilder extends PageTransitionsBuilder {
  const ShopzyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: kMotionCurve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class ShopzyScrollBehavior extends MaterialScrollBehavior {
  const ShopzyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
