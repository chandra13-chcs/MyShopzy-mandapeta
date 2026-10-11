import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/myshopzy_app.dart';
import 'package:myshopzy/app/router.dart';
import 'package:myshopzy/features/auth/presentation/otp_verification_page.dart';
import 'package:myshopzy/features/auth/presentation/phone_entry_page.dart';
import 'package:myshopzy/features/auth/presentation/auth_visuals.dart';
import 'package:myshopzy/features/auth/presentation/welcome_page.dart';
import 'package:myshopzy/features/privacy_policy/presentation/privacy_policy_page.dart';
import 'package:myshopzy/features/terms_conditions/presentation/terms_conditions_page.dart';

void main() {
  testWidgets('welcome opens immediately and Home remains routable', (
    tester,
  ) async {
    await tester.pumpWidget(const MyShopzyApp());
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-signup')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-number-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsNothing);
    expect(find.text('Forgot Password?'), findsNothing);
    expect(find.text('New customer? Create account'), findsNothing);
    expect(find.byKey(const ValueKey('create-account-link')), findsNothing);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRouter.home);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('welcome shows only Login and opens mobile-number entry', (
    tester,
  ) async {
    await _pumpAppToWelcome(tester);
    final banner = tester.widget<Image>(
      find.byKey(const ValueKey('welcome-banner')),
    );
    expect(banner.fit, BoxFit.contain);
    expect(banner.image, const AssetImage(AuthBrandBanner.assetPath));
    expect(banner.filterQuality, FilterQuality.high);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-signup')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('welcome-back-message'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('welcome-login'))).dy,
      ),
    );
    expect(find.text('Offers'), findsNothing);
    expect(find.text('Feedback'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-number-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-brand-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-password')), findsNothing);
  });

  testWidgets('login back action returns to the welcome screen', (
    tester,
  ) async {
    await _pumpAppToWelcome(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login-back')));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('phone entry validates number and opens disconnected OTP UI', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.byKey(const ValueKey('login-password-field')), findsNothing);
    expect(find.text('Forgot Password?'), findsNothing);
    expect(
      find.text('OTP verification is not connected yet. No SMS will be sent.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-brand-banner')), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('phone-continue')));
    await tester.tap(find.byKey(const ValueKey('phone-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '9876543210',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('phone-continue')));
    await tester.tap(find.byKey(const ValueKey('phone-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerificationPage), findsOneWidget);
    expect(find.text('+91 •••••• 3210'), findsOneWidget);
    expect(find.text('Login verification'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-brand-banner')), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(
      find.text('Real SMS OTP verification is not connected. No SMS was sent.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text('OTP verification is not connected. You are not signed in.'),
      findsOneWidget,
    );
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('legacy auth paths resolve to the mobile entry screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MyShopzyApp());
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    navigator.pushNamed(AppRouter.registration);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-password')), findsNothing);

    navigator.pushNamed(AppRouter.forgotPassword);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
    expect(find.text('Forgot Password?'), findsNothing);
  });

  testWidgets('phone entry opens the existing Terms and Privacy pages', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));

    await tester.ensureVisible(find.text('Terms of Service'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.byType(TermsConditionsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
  });

  testWidgets('OTP supports numeric paste but never verifies in demo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('otp-input')));
    await tester.tap(find.byKey(const ValueKey('otp-input')));
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '1234567');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('7'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No account was created or verified.'),
      findsOneWidget,
    );
    expect(find.text('OTP Verification'), findsOneWidget);
  });

  testWidgets('OTP requires six digits and supports resend after countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the complete 6-digit OTP.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const ValueKey('otp-resend')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('otp-resend')));
    await tester.pump();
    expect(find.text('UI demo only · no SMS was sent.'), findsOneWidget);
    expect(find.textContaining('Resend SMS in 30s'), findsOneWidget);
  });

  testWidgets('auth screens remain scrollable at compact dimensions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAppToWelcome(tester);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-signup')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.byKey(const ValueKey('phone-number-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-continue')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.byKey(const ValueKey('phone-number-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    expect(find.byKey(const ValueKey('auth-brand-banner')), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth banners show full artwork at its natural aspect ratio', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final expectedBannerHeight = AuthBrandBanner.heightForViewport(390, 844);

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    final welcomeBanner = tester.widget<Image>(
      find.byKey(const ValueKey('welcome-banner')),
    );
    expect(welcomeBanner.fit, BoxFit.contain);
    expect(
      tester.getSize(find.byKey(const ValueKey('welcome-banner'))).height,
      closeTo(expectedBannerHeight, 1),
    );

    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-brand-banner'))).height,
      closeTo(expectedBannerHeight, 1),
    );

    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-brand-banner'))).height,
      closeTo(expectedBannerHeight, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo asset uses contain and service animation disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(children: [MyShopzyBrand(), AuthServiceCategories()]),
      ),
    );
    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('myshopzy-logo')),
    );
    expect(logo.fit, BoxFit.contain);
    expect(logo.image, isA<AssetImage>());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone entry remains scrollable while the keyboard is visible', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    await tester.ensureVisible(
      find.byKey(const ValueKey('phone-number-field')),
    );
    expect(find.byKey(const ValueKey('phone-number-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAppToWelcome(WidgetTester tester) async {
  await tester.pumpWidget(const MyShopzyApp());
  await tester.pumpAndSettle();
}
