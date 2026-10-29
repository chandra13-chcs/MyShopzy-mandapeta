import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_history_page.dart';
import 'package:myshopzy/features/parcel/presentation/parcel_summary_page.dart';
import 'package:myshopzy/features/profile/presentation/dues_page.dart';
import 'package:myshopzy/features/profile/presentation/edit_profile_page.dart';
import 'package:myshopzy/features/profile/presentation/profile_page.dart';
import 'package:myshopzy/features/profile/presentation/saved_addresses_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  final requests = <http.Request>[];
  late CustomerApi previewApi;

  setUp(() {
    CustomerApi.instance.close();
    requests.clear();
    previewApi = CustomerApi(
      baseUrl: 'https://shop.example',
      enableDevelopmentPreview: true,
      enableDevelopmentGuestCart: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 500);
      }),
    );
    CustomerApi.instance = previewApi;
  });

  tearDown(() {
    previewApi.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets(
    'profile and edit profile are reachable as a non-account preview',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to access your account.'), findsNothing);
      expect(find.text('Demo profile · not signed in'), findsOneWidget);
      await tester.tap(find.text('Edit Profile Preview'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfilePage), findsOneWidget);
      expect(
        find.text('Development preview only. Profile changes are not saved.'),
        findsOneWidget,
      );
      final saveButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('save-profile-button')),
      );
      expect(saveButton.onPressed, isNull);
      expect(requests, isEmpty);
    },
  );

  testWidgets('backend-owned account pages show usable preview states', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SavedAddressesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to access saved addresses.'), findsNothing);
    expect(
      find.text('Address management is a preview; no addresses are saved.'),
      findsOneWidget,
    );
    final addAddressButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Add New Address'),
    );
    expect(addAddressButton.onPressed, isNull);
    expect(requests, isEmpty);

    await tester.pumpWidget(const MaterialApp(home: DuesPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to access your dues.'), findsNothing);
    expect(find.textContaining('development preview'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to access your order history.'), findsNothing);
    expect(find.textContaining('Development preview'), findsOneWidget);
    expect(
      find.text('Orders are not created in preview mode.'),
      findsOneWidget,
    );
    expect(requests, isEmpty);

    await tester.pumpWidget(const MaterialApp(home: ParcelHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to access your parcel history.'), findsNothing);
    expect(
      find.textContaining('Development preview does not create bookings.'),
      findsOneWidget,
    );
    expect(requests, isEmpty);
  });

  testWidgets('parcel summary preview cannot book or request a quote', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ParcelSummaryPage(
          pickupLocation: 'Pickup',
          dropLocation: 'Drop',
          parcelType: 'Documents',
          weight: '1',
          instructions: '',
          pickupLatitude: 16.87,
          pickupLongitude: 81.93,
          pickupPincode: '533001',
          dropLatitude: 16.88,
          dropLongitude: 81.94,
          dropPincode: '533002',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Development preview only. No booking or server quote will be requested.',
      ),
      findsOneWidget,
    );
    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Preview Only · No Booking'),
    );
    expect(submitButton.onPressed, isNull);
    expect(requests, isEmpty);
  });

  test('disabled development flags do not grant customer access', () async {
    final api = CustomerApi(
      baseUrl: 'https://shop.example',
      enableDevelopmentPreview: false,
      enableDevelopmentGuestCart: false,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 500);
      }),
    );
    addTearDown(api.close);

    expect(api.isDevelopmentDemoMode, isFalse);
    expect(api.canAccessCustomerFeatures, isFalse);
    await expectLater(
      api.getProfile(),
      throwsA(
        isA<CustomerApiException>().having(
          (error) => error.code,
          'code',
          'AUTHENTICATION_REQUIRED',
        ),
      ),
    );
    expect(requests, isEmpty);
  });
}
