import 'package:flutter/material.dart';

/// Lets code outside a screen (like the new-order popup) open screens.
/// It is given to MaterialApp(navigatorKey: navigatorKey) in main.dart.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
