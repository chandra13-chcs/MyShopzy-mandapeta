import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/myshopzy_app.dart';
import 'package:myshopzy/app/router.dart';
import 'package:myshopzy/features/auth/presentation/forgot_password_page.dart';
import 'package:myshopzy/features/auth/presentation/otp_verification_page.dart';
import 'package:myshopzy/features/auth/presentation/phone_entry_page.dart';
import 'package:myshopzy/features/auth/presentation/registration_page.dart';
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
    expect(find.byKey(const ValueKey('welcome-signup')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
    expect(find.text('Log in or sign up'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(find.text('New customer? Create account'), findsNothing);
    expect(find.byKey(const ValueKey('create-account-link')), findsNothing);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRouter.home);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('welcome actions open login and registration screens', (
    tester,
  ) async {
    await _pumpAppToWelcome(tester);
    final banner = tester.widget<Image>(
      find.byKey(const ValueKey('welcome-banner')),
    );
    expect(banner.fit, BoxFit.cover);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-signup')), findsOneWidget);
    expect(find.text('Offers'), findsNothing);
    expect(find.text('Feedback'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-signup')));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
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

  testWidgets('login validates fields and never creates a fake session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '9123456789',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Passw0rd!',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    expect(
      find.text('Sign-in is not connected yet. No account was authenticated.'),
      findsOneWidget,
    );
    expect(find.byType(OtpVerificationPage), findsNothing);
  });

  testWidgets('login password visibility control works', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    final passwordField = find.descendant(
      of: find.byKey(const ValueKey('login-password-field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);

    await tester.tap(find.byKey(const ValueKey('login-password-toggle')));
    await tester.pump();
    expect(tester.widget<EditableText>(passwordField).obscureText, isFalse);
  });

  testWidgets('login with OTP validates mobile then opens login OTP flow', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    await tester.ensureVisible(find.byKey(const ValueKey('login-with-otp')));
    await tester.tap(find.byKey(const ValueKey('login-with-otp')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );
    expect(find.byType(OtpVerificationPage), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '9876543210',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-with-otp')));
    await tester.tap(find.byKey(const ValueKey('login-with-otp')));
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerificationPage), findsOneWidget);
    expect(find.text('+91 •••••• 3210'), findsOneWidget);
    expect(find.text('Login verification'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text('OTP verification is not connected. You are not signed in.'),
      findsOneWidget,
    );
  });

  testWidgets('registration opens from welcome and returns to login', (
    tester,
  ) async {
    await _pumpAppToWelcome(tester);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-signup')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-signup')));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-login-link')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-login-link')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneEntryPage), findsOneWidget);
  });

  testWidgets('registration validates required inputs and password rules', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('registration-name-field')),
      'Customer Name',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-phone-field')),
      '9123456789',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-password')),
      'weak',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-confirm-password')),
      'weak',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Use at least 8 characters with a letter and a number.'),
      findsOneWidget,
    );
    expect(find.byType(OtpVerificationPage), findsNothing);
  });

  testWidgets('registration requires matching passwords and then opens OTP', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    await tester.enterText(
      find.byKey(const ValueKey('registration-name-field')),
      'Customer Name',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-phone-field')),
      '9123456789',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-password')),
      'Passw0rd!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-confirm-password')),
      'Passw0rd?',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.byType(OtpVerificationPage), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('registration-confirm-password')),
      'Passw0rd!',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerificationPage), findsOneWidget);
    expect(find.text('+91 •••••• 6789'), findsOneWidget);
    expect(find.text('Account registration'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'OTP verification is not connected. '
        'No account was created or verified.',
      ),
      findsOneWidget,
    );
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('registration password visibility control works', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    final passwordField = find.descendant(
      of: find.byKey(const ValueKey('registration-password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('registration-password-toggle')),
    );
    await tester.pump();
    expect(tester.widget<EditableText>(passwordField).obscureText, isFalse);
  });

  testWidgets('forgot password validates mobile and opens OTP demo', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
    await tester.tap(find.byKey(const ValueKey('forgot-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('forgot-phone-field')),
      '9123456789',
    );
    await tester.tap(find.byKey(const ValueKey('forgot-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(OtpVerificationPage), findsOneWidget);
    expect(find.text('Password recovery'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('otp-verify')));
    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'OTP verification and password reset are not connected. '
        'No password was changed.',
      ),
      findsOneWidget,
    );
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
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    expect(find.text('Create your MyShopzy account'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
    expect(find.text('Reset your password'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    expect(find.text('Verify'), findsOneWidget);
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

  testWidgets('login remains scrollable while the keyboard is visible', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    await tester.ensureVisible(
      find.byKey(const ValueKey('login-password-field')),
    );
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAppToWelcome(WidgetTester tester) async {
  await tester.pumpWidget(const MyShopzyApp());
  await tester.pumpAndSettle();
}
