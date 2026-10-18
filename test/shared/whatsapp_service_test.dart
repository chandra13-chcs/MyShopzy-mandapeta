import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/shared/data/customer_api.dart';
import 'package:myshopzy/shared/data/whatsapp_service.dart';

void main() {
  group('WhatsAppService', () {
    test('requests OTP through the configured backend only', () async {
      http.Request? capturedRequest;
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'data': {
                'message': 'If this number can receive verification messages, a code may be sent.',
                'expiresIn': 300,
                'resendAfter': 30,
              },
            }),
            202,
          );
        }),
      );
      addTearDown(api.close);
      final service = WhatsAppService(customerApi: api);

      await service.requestOtp(recipientPhone: '+919876543210');

      expect(
        capturedRequest!.url.toString(),
        'https://shop.example/api/v1/auth/otp/request',
      );
      expect(capturedRequest!.headers.containsKey('authorization'), isFalse);
      expect(jsonDecode(capturedRequest!.body), {
        'phoneNumber': '+919876543210',
      });
    });

    test('surfaces backend OTP delivery failures', () async {
      final api = CustomerApi(
        baseUrl: 'https://shop.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'OTP_DELIVERY_FAILED',
                'message': 'The verification message could not be accepted. Try again later.',
              },
            }),
            503,
          ),
        ),
      );
      addTearDown(api.close);
      final service = WhatsAppService(customerApi: api);

      await expectLater(
        service.requestOtp(recipientPhone: '+919876543210'),
        throwsA(
          isA<CustomerApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.code, 'code', 'OTP_DELIVERY_FAILED'),
        ),
      );
    });
  });
}
