import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myshopzy/features/cart/data/cart_store.dart';
import 'package:myshopzy/features/profile/data/selected_delivery_address_store.dart';
import 'package:myshopzy/features/profile/models/saved_address.dart';
import 'package:myshopzy/shared/data/customer_api.dart';

const checkoutTestHomeAddress = SavedAddress(
  id: 'checkout-test-home',
  label: 'Home',
  address: '12 Test Road, Mandapeta',
  icon: Icons.home_outlined,
  isBackendData: true,
  latitude: 16.87,
  longitude: 81.93,
  pincode: '533201',
);

class CheckoutCartItemFixture {
  const CheckoutCartItemFixture({
    required this.productId,
    required this.variantId,
    required this.variantLabel,
    required this.name,
    required this.priceMinor,
    this.quantity = 1,
  });

  final String productId;
  final String variantId;
  final String variantLabel;
  final String name;
  final int priceMinor;
  final int quantity;

  Map<String, Object> toJson() => {
    'productId': productId,
    'variantId': variantId,
    'variantLabel': variantLabel,
    'shopId': 'checkout-test-shop',
    'name': name,
    'quantity': quantity,
    'priceMinor': priceMinor,
    'currency': 'INR',
    'available': true,
  };
}

Future<void> setUpAuthenticatedCheckout({
  List<CheckoutCartItemFixture> cartItems = const [
    CheckoutCartItemFixture(
      productId: 'checkout-test-product',
      variantId: 'checkout-test-variant',
      variantLabel: '1 serving',
      name: 'Checkout Test Item',
      priceMinor: 100000,
    ),
  ],
  bool selectHomeAddress = false,
}) async {
  final api = CustomerApi(
    baseUrl: 'https://checkout-test.example',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/auth/otp/verify') {
        return _jsonResponse({
          'data': {
            'accessToken': 'checkout-test-session',
            'tokenType': 'Bearer',
            'expiresIn': 900,
          },
        });
      }
      if (path == '/api/v1/carts') {
        return _jsonResponse({
          'data': {'cartToken': List.filled(43, 'C').join()},
        });
      }
      if (path == '/api/v1/cart') {
        return _jsonResponse({
          'data': {
            'items': cartItems.map((item) => item.toJson()).toList(),
            'itemSubtotalMinor': cartItems.fold<int>(
              0,
              (total, item) => total + item.priceMinor * item.quantity,
            ),
          },
        });
      }
      if (path == '/api/v1/me/addresses') {
        return _jsonResponse({
          'data': [
            {
              'id': checkoutTestHomeAddress.id,
              'label': checkoutTestHomeAddress.label,
              'address_snapshot': {
                'formattedAddress': checkoutTestHomeAddress.address,
                'latitude': checkoutTestHomeAddress.latitude,
                'longitude': checkoutTestHomeAddress.longitude,
                'pincode': checkoutTestHomeAddress.pincode,
              },
            },
          ],
        });
      }
      if (path == '/api/v1/me/dues') {
        return _jsonResponse({
          'data': {'outstandingMinor': 0, 'entries': []},
        });
      }
      if (path == '/api/v1/checkout/quote') {
        final subtotal = cartItems.fold<int>(
          0,
          (total, item) => total + item.priceMinor * item.quantity,
        );
        return _jsonResponse({
          'data': {
            'currency': 'INR',
            'itemSubtotalMinor': subtotal,
            'deliveryFeeMinor': 3000,
            'platformFeeMinor': 0,
            'discountMinor': 0,
            'totalMinor': subtotal + 3000,
            'isDeliverable': true,
            'message': 'Delivery is available.',
            'distanceMeters': 1200,
            'items': [
              for (final item in cartItems)
                {
                  'productId': item.productId,
                  'name': item.name,
                  'quantity': item.quantity,
                  'priceMinor': item.priceMinor,
                  'lineTotalMinor': item.priceMinor * item.quantity,
                  'variantId': item.variantId,
                  'variantLabel': item.variantLabel,
                },
            ],
          },
        });
      }
      return _jsonResponse({
        'error': {
          'code': 'UNEXPECTED_TEST_REQUEST',
          'message': 'Unexpected checkout test request: $path',
        },
      }, statusCode: 404);
    }),
  );
  CustomerApi.instance = api;
  await api.verifyOtp(phoneNumber: '9876543210', otp: '123456');
  if (selectHomeAddress) {
    SelectedDeliveryAddressStore.instance.select(checkoutTestHomeAddress);
  }
}

void tearDownCheckoutTest() {
  CartStore.instance.clear();
  SelectedDeliveryAddressStore.instance.select(null);
  CustomerApi.instance.close();
  CustomerApi.instance = CustomerApi(baseUrl: '');
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
