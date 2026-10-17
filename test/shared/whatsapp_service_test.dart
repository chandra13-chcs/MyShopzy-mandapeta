import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/shared/data/whatsapp_service.dart';

void main() {
  group('WhatsAppService', () {
    test('sends an OTP using the WhatsApp template endpoint', () async {
      http.Request? capturedRequest;
      final service = WhatsAppService(
        accessToken: 'test-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{}', 200);
        }),
      );

      await service.sendOtpMessage(
        recipientPhone: '+15551234567',
        otpCode: '123456',
      );

      expect(
        capturedRequest!.url.toString(),
        'https://graph.facebook.com/v17.0/1346981995167088/messages',
      );
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.headers['authorization'], 'Bearer test-token');
      expect(jsonDecode(capturedRequest!.body), {
        'messaging_product': 'whatsapp',
        'to': '+15551234567',
        'type': 'template',
        'template': {
          'name': 'otp',
          'language': {'code': 'en_US'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': '123456'},
              ],
            },
          ],
        },
      });
    });

    test('throws an exception for a non-200 API response', () async {
      final service = WhatsAppService(
        accessToken: 'test-token',
        httpClient: MockClient(
          (_) async => http.Response('Invalid template', 400),
        ),
      );

      await expectLater(
        service.sendOtpMessage(
          recipientPhone: '+15551234567',
          otpCode: '123456',
        ),
        throwsA(
          isA<WhatsAppApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.responseBody,
                'responseBody',
                'Invalid template',
              ),
        ),
      );
    });

    test('requires an access token before sending', () async {
      final service = WhatsAppService(
        accessToken: '',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        service.sendOtpMessage(
          recipientPhone: '+15551234567',
          otpCode: '123456',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
