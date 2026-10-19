import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/auth/presentation/landing_page.dart';
import 'package:myshopzy/features/auth/presentation/login_page.dart';
import 'package:myshopzy/features/home/presentation/home_page.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

CustomerApi _installApi({
  required Future<http.Response> Function(http.Request request) handler,
}) {
  final previousApi = CustomerApi.instance;
  final api = CustomerApi(
    baseUrl: 'https://shop.example',
    httpClient: MockClient(handler),
  );
  CustomerApi.instance = api;
  addTearDown(() {
    api.close();
    CustomerApi.instance = previousApi;
  });
  return api;
}

Future<void> _openOtpPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LandingPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '9876543210');
  await tester.pump();
  await tester.ensureVisible(find.text('Get code'));
  await tester.tap(find.text('Get code'));
  await tester.pumpAndSettle();
}

http.Response _requestAccepted() => http.Response(
  jsonEncode({
    'data': {
      'message': 'If this number can receive verification messages, a code may be sent.',
      'expiresIn': 300,
      'resendAfter': 30,
    },
  }),
  202,
);

void main() {
  testWidgets('login requests a code before opening OTP entry', (tester) async {
    final requests = <http.Request>[];
    _installApi(
      handler: (request) async {
        requests.add(request);
        return _requestAccepted();
      },
    );

    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '9876543210',
    );
    await tester.ensureVisible(find.text('Get code'));
    final getCodeButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Get code'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(getCodeButton.onPressed, isNotNull);
    await tester.tap(find.text('Get code'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.text('Sent to +91 98765 43210'), findsOneWidget);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/auth/otp/request');
    expect(jsonDecode(requests.single.body), {'phoneNumber': '+919876543210'});
  });

  testWidgets('invalid verification stays on OTP page without a session', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = _installApi(
      handler: (request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/otp/request')) {
          return _requestAccepted();
        }
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'INVALID_OTP',
              'message': 'The verification code is invalid or expired.',
            },
          }),
          401,
        );
      },
    );

    await _openOtpPage(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(
      find.text('The verification code is invalid or expired.'),
      findsOneWidget,
    );
    expect(api.hasCustomerSession, isFalse);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/auth/otp/request',
      '/api/v1/auth/otp/verify',
    ]);
    expect(jsonDecode(requests.last.body), {
      'phoneNumber': '+919876543210',
      'otp': '123456',
    });
  });

  testWidgets('valid verification opens Home with the authenticated session', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = _installApi(
      handler: (request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/otp/request')) {
          return _requestAccepted();
        }
        if (request.url.path.endsWith('/auth/otp/verify')) {
          return http.Response(
            jsonEncode({
              'data': {
                'accessToken': 'test-session-token',
                'tokenType': 'Bearer',
                'expiresIn': 900,
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': [],
            'pagination': {'limit': 100, 'offset': 0},
          }),
          200,
        );
      },
    );

    await _openOtpPage(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(api.hasCustomerSession, isTrue);
    expect(
      requests.any((request) => request.url.path.endsWith('/auth/otp/verify')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
