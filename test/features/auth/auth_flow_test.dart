import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/app/myshopzy_app.dart';
import 'package:myshopzy/app/router.dart';
import 'package:myshopzy/features/auth/presentation/otp_verification_page.dart';
import 'package:myshopzy/features/auth/presentation/phone_entry_page.dart';
import 'package:myshopzy/features/privacy_policy/presentation/privacy_policy_page.dart';
import 'package:myshopzy/features/terms_conditions/presentation/terms_conditions_page.dart';

void main() {
  testWidgets('phone entry is the app start route and Home remains routable', (
    tester,
  ) async {
    await tester.pumpWidget(const MyShopzyApp());
    expect(find.text('Log in or sign up'), findsOneWidget);
    expect(find.byType(PhoneEntryPage), findsOneWidget);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRouter.home);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('phone entry does not show a substitute logo and uses basket art', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));

    expect(find.byIcon(Icons.shopping_cart_rounded), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/category_tiles/fruits_vegetables.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone number is validated before demo OTP navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));

    await tester.tap(find.byKey(const ValueKey('phone-entry-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );
    expect(find.byType(OtpVerificationPage), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '9123456789',
    );
    await tester.tap(find.byKey(const ValueKey('phone-entry-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(OtpVerificationPage), findsOneWidget);
    expect(find.text('UI demo only · no SMS was sent'), findsOneWidget);
    expect(find.text('+91 •••••• 6789'), findsOneWidget);
  });

  testWidgets('phone entry opens the existing terms and privacy pages', (
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

  testWidgets('OTP input supports numeric paste and never verifies in demo', (
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

    await tester.tap(find.byKey(const ValueKey('otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('OTP verification is unavailable in this UI demo.'),
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

  testWidgets('auth layouts remain scrollable at compact device dimensions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: OtpVerificationPage(phoneNumber: '9123456789')),
    );
    expect(find.text('Verify'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
