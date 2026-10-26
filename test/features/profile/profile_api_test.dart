import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/profile/presentation/edit_profile_page.dart';
import 'package:myshopzy/features/profile/presentation/profile_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

void main() {
  setUp(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  tearDown(() {
    CustomerApi.instance.close();
    CustomerApi.instance = CustomerApi(baseUrl: '');
  });

  testWidgets('loads backend profile and updates only after API success', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final patchResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _jsonResponse(_profileJson());
      }
      return patchResponse.future;
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('API Customer'), findsOneWidget);
    expect(find.text('+15551234567'), findsOneWidget);
    expect(find.text('Chandra Shekar'), findsNothing);

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-name-field')),
          )
          .controller!
          .text,
      'API Customer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Updated Customer',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-button')));
    await tester.pump();

    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-name-field')),
          )
          .controller!
          .text,
      'Updated Customer',
    );
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/v1/me/profile');
    expect(jsonDecode(requests.last.body), {
      'displayName': 'Updated Customer',
      'phone': '+15551234567',
      'email': 'customer@example.com',
    });

    patchResponse.complete(
      _jsonResponse(
        _profileJson(
          displayName: 'Updated Customer',
          phone: '+15551234567',
          email: 'customer@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Updated Customer'), findsOneWidget);
    expect(find.text('Profile updated successfully.'), findsOneWidget);
  });

  testWidgets('shows loading and retries a failed profile request', (
    tester,
  ) async {
    var getCount = 0;
    final firstResponse = Completer<http.Response>();
    CustomerApi.instance = _api((request) async {
      getCount++;
      if (getCount == 1) return firstResponse.future;
      return _jsonResponse(_profileJson());
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstResponse.complete(
      _jsonResponse({
        'error': {
          'code': 'DATABASE_UNAVAILABLE',
          'message': 'Profile is temporarily unavailable.',
        },
      }, statusCode: 503),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Chandra Shekar'), findsNothing);

    await tester.tap(find.text('Retry profile'));
    await tester.pumpAndSettle();
    expect(find.text('API Customer'), findsOneWidget);
    expect(getCount, 2);
  });

  testWidgets('handles 401 without showing demo profile data', (tester) async {
    CustomerApi.instance = _api(
      (request) async => _jsonResponse({
        'error': {
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Customer authentication is required for profile access.',
        },
      }, statusCode: 401),
    );
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer authentication is required for profile access.'),
      findsOneWidget,
    );
    expect(find.text('Chandra Shekar'), findsNothing);
    expect(find.text('Edit Profile'), findsNothing);
    expect(find.text('Retry profile'), findsOneWidget);
  });

  testWidgets('does not expose profile editing without a customer session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    expect(find.text('Sign in to access your account.'), findsOneWidget);
    expect(find.text('Edit Profile'), findsNothing);
  });

  testWidgets(
    'validates profile input and leaves API data untouched on error',
    (tester) async {
      final requests = <http.Request>[];
      CustomerApi.instance = _api((request) async {
        requests.add(request);
        if (request.method == 'GET') return _jsonResponse(_profileJson());
        return _jsonResponse({
          'error': {
            'code': 'PROFILE_CONFLICT',
            'message': 'Email or phone is already in use.',
          },
        }, statusCode: 409);
      });
      await _authenticate();

      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-email-field')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const ValueKey('save-profile-button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(requests.where((request) => request.method == 'PATCH'), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('profile-email-field')),
        'customer@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('save-profile-button')));
      await tester.pumpAndSettle();
      expect(find.text('Email or phone is already in use.'), findsOneWidget);
      expect(find.text('API Customer'), findsOneWidget);
    },
  );

  testWidgets('configured edit screen retries profile loading after 401', (
    tester,
  ) async {
    var getCount = 0;
    CustomerApi.instance = _api((request) async {
      getCount++;
      if (getCount == 1) {
        return _jsonResponse({
          'error': {
            'code': 'AUTHENTICATION_REQUIRED',
            'message':
                'Customer authentication is required for profile access.',
          },
        }, statusCode: 401);
      }
      return _jsonResponse(_profileJson());
    });
    await _authenticate();

    await tester.pumpWidget(const MaterialApp(home: EditProfilePage()));
    await tester.pumpAndSettle();
    expect(
      find.text('Customer authentication is required for profile access.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('save-profile-button')), findsNothing);

    await tester.tap(find.text('Retry profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-profile-button')), findsOneWidget);
    expect(getCount, 2);
  });
}

CustomerApi _api(Future<http.Response> Function(http.Request) handler) {
  return CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/v1/auth/otp/verify') {
        return _jsonResponse({
          'data': {
            'accessToken': 'test-session',
            'tokenType': 'Bearer',
            'expiresIn': 300,
          },
        });
      }
      return handler(request);
    }),
  );
}

Future<void> _authenticate() =>
    CustomerApi.instance.verifyOtp(phoneNumber: '9876543210', otp: '123456');

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, Object?> _profileJson({
  String displayName = 'API Customer',
  String? phone = '+15551234567',
  String? email = 'customer@example.com',
}) => {
  'data': {
    'id': 'do-not-use-client-identity',
    'display_name': displayName,
    'email': email,
    'phone': phone,
    'created_at': '2026-01-01T00:00:00.000Z',
  },
};
