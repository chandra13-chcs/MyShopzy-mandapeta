import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/myshopzy_app.dart';
import 'shared/data/customer_api.dart';

void main() {
  CustomerApi.instance = CustomerApi.fromEnvironment(
    enableDevelopmentPreview: kDebugMode,
    enableDevelopmentGuestCart:
        kDebugMode &&
        const bool.fromEnvironment(
          'MYSHOPZY_ENABLE_DEV_GUEST_CART',
          defaultValue: false,
        ),
  );
  runApp(const MyShopzyApp());
}
