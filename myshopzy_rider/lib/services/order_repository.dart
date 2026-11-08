import '../models/order.dart';

/// The ONLY thing the rest of the app knows about where orders come from.
/// Today it is implemented by MockOrderService (fake data on a timer).
/// A backend developer can write e.g. ApiOrderRepository (WebSocket /
/// Firebase / REST) that implements this class and pass it to
/// RiderController in main.dart - no screen needs to change.
///
/// ERRORS: every `Future` below may THROW (no internet, server down,
/// "order already taken"). The app catches this, shows a message and lets
/// the rider try again - so a real implementation should simply throw.
/// See API_CONTRACT.md in the project root for the full list of calls.
abstract class OrderRepository {
  /// New delivery requests, pushed to the rider while online.
  Stream<Order> get incomingOrders;

  /// Ids of orders the customer or shop CANCELLED. Can arrive at any time:
  /// while the popup is showing, while queued, or mid-delivery.
  Stream<String> get cancelledOrders;

  /// Rider toggled the Online switch on / off.
  void goOnline();
  void goOffline();

  /// Throw if the order can no longer be taken (already taken / cancelled).
  Future<void> acceptOrder(String orderId);
  Future<void> rejectOrder(String orderId);
  Future<void> completeOrder(String orderId);

  /// Ask for a bank withdrawal. Returns true when accepted.
  Future<bool> requestWithdraw(double amount);

  /// Tell MyShopzy the rider handed over [amount] of cash-on-delivery money.
  Future<bool> depositCash(double amount);

  void dispose();
}
