// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WhatsAppService {
  WhatsAppService({
    required String accessToken,
    String phoneNumberId = defaultPhoneNumberId,
    String templateName = 'otp',
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _accessToken = accessToken.trim(),
       _phoneNumberId = phoneNumberId.trim(),
       _templateName = templateName.trim(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  factory WhatsAppService.fromEnvironment({http.Client? httpClient}) {
    return WhatsAppService(
      phoneNumberId: const String.fromEnvironment(
        'WHATSAPP_PHONE_NUMBER_ID',
        defaultValue: defaultPhoneNumberId,
      ),
      accessToken: const String.fromEnvironment('WHATSAPP_ACCESS_TOKEN'),
      httpClient: httpClient,
    );
  }

  static const defaultPhoneNumberId = '1346981995167088';
  static const graphApiVersion = 'v17.0';

  final String _accessToken;
  final String _phoneNumberId;
  final String _templateName;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration timeout;

  Future<void> sendOtpMessage({
    required String recipientPhone,
    required String otpCode,
  }) async {
    if (_accessToken.isEmpty) {
      throw StateError(
        'WhatsApp access token is not configured. Set '
        'WHATSAPP_ACCESS_TOKEN or pass accessToken to WhatsAppService.',
      );
    }
    if (_phoneNumberId.isEmpty) {
      throw StateError('WhatsApp phone number ID is not configured.');
    }
    if (_templateName.isEmpty) {
      throw StateError('WhatsApp OTP template name is not configured.');
    }
    if (recipientPhone.trim().isEmpty) {
      throw ArgumentError.value(recipientPhone, 'recipientPhone');
    }
    if (otpCode.isEmpty) {
      throw ArgumentError.value(otpCode, 'otpCode');
    }

    final endpoint = Uri.https(
      'graph.facebook.com',
      '/$graphApiVersion/$_phoneNumberId/messages',
    );
    final body = {
      'messaging_product': 'whatsapp',
      'to': recipientPhone.trim(),
      'type': 'template',
      'template': {
        'name': _templateName,
        'language': {'code': 'en_US'},
        'components': [
          {
            'type': 'body',
            'parameters': [
              {'type': 'text', 'text': otpCode},
            ],
          },
        ],
      },
    };

    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        print('WhatsApp OTP message sent successfully (HTTP 200).');
        return;
      }

      print(
        'WhatsApp OTP message request failed '
        '(HTTP ${response.statusCode}).',
      );
      throw WhatsAppApiException(
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } on WhatsAppApiException {
      rethrow;
    } catch (error) {
      print('Could not send WhatsApp OTP message: $error');
      rethrow;
    }
  }

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

class WhatsAppApiException implements Exception {
  const WhatsAppApiException({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;

  @override
  String toString() {
    return 'WhatsApp API request failed (HTTP $statusCode): $responseBody';
  }
}
