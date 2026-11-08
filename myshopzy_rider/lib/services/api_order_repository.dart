import 'dart:async';
import '../models/order.dart';
import 'order_repository.dart';

/// STARTING POINT FOR THE BACKEND DEVELOPER. It is NOT used yet.
///
/// To switch the app from fake data to the real server:
///   1. Fill in the methods below (see API_CONTRACT.md in the project root).
///   2. In lib/main.dart change
///        ChangeNotifierProvider(create: (_) => RiderController())
///      to
///        ChangeNotifierProvider(create: (_) => RiderController(
///            repository: ApiOrderRepository(baseUrl: 'https://...', tokenProvider: ...)))
/// No screen has to change. Every method may THROW on failure - the app
/// catches it, shows an error message and lets the rider try again.
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository({required this.baseUrl, required this.tokenProvider});

  final String baseUrl;

  /// Returns the rider's login token (given by the server after OTP login).
  final Future<String?> Function() tokenProvider;

  // Feed these from your WebSocket / FCM / Firebase listener:
  //   _orders.add(Order.fromJson(json))   when the server offers an order
  //   _cancelled.add(orderId)             when the customer/shop cancels
  final _orders = StreamController<Order>.broadcast();
  final _cancelled = StreamController<String>.broadcast();

  @override
  Stream<Order> get incomingOrders => _orders.stream;

  @override
  Stream<String> get cancelledOrders => _cancelled.stream;

  @override
  void goOnline() {
    // TODO: tell the server the rider is online and open the live connection.
  }

  @override
  void goOffline() {
    // TODO: tell the server the rider is offline and close the live connection.
  }

  @override
  Future<void> acceptOrder(String orderId) async {
    throw UnimplementedError('POST /orders/$orderId/accept');
  }

  @override
  Future<void> rejectOrder(String orderId) async {
    // Fire and forget is fine here: POST /orders/{id}/reject
  }

  @override
  Future<void> completeOrder(String orderId) async {
    throw UnimplementedError('POST /orders/$orderId/complete');
  }

  @override
  Future<bool> requestWithdraw(double amount) async {
    throw UnimplementedError('POST /wallet/withdraw');
  }

  @override
  Future<bool> depositCash(double amount) async {
    throw UnimplementedError('POST /wallet/cash-deposit');
  }

  @override
  void dispose() {
    _orders.close();
    _cancelled.close();
  }
}
