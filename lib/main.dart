import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/myshopzy_app.dart';
import 'shared/data/customer_api.dart';

void main() {
  CustomerApi.instance = CustomerApi.fromEnvironment(
    enableDevelopmentPreview: kDebugMode,
  );
  runApp(const MyShopzyApp());
}
