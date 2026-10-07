import '../models/order_record.dart';
import '../models/refund_record.dart';

class DemoRefundStore {
  DemoRefundStore._();

  static final Map<String, DemoRefundRecord> _refundsByOrderId = {};

  static bool requiresRefund(String paymentMethod) {
    final method = paymentMethod.trim().toLowerCase();
    return method == 'upi' ||
        method == 'card' ||
        method == 'credit card' ||
        method == 'debit card';
  }

  static bool isCashOnDelivery(String paymentMethod) {
    final method = paymentMethod.trim().toLowerCase();
    return method == 'cod' ||
        method == 'cash on delivery' ||
        method == 'cash-on-delivery';
  }

  static DemoRefundRecord? refundForCancelledOrder(OrderRecord order) {
    if (order.orderTab != OrdersTab.cancelled ||
        !requiresRefund(order.paymentMethod)) {
      return null;
    }

    return _refundsByOrderId.putIfAbsent(
      order.orderId,
      () => _createDemoRefund(order),
    );
  }

  static DemoRefundRecord? refundForOrderId(String orderId) =>
      _refundsByOrderId[orderId];

  static void recordCancellation(OrderRecord order) {
    if (order.orderTab != OrdersTab.cancelled ||
        !requiresRefund(order.paymentMethod)) {
      return;
    }
    _refundsByOrderId.putIfAbsent(order.orderId, () => _createDemoRefund(order));
  }

  static void saveDemoRecord(DemoRefundRecord refund) {
    _refundsByOrderId[refund.orderId] = refund;
  }

  static void clear() => _refundsByOrderId.clear();

  static DemoRefundRecord _createDemoRefund(OrderRecord order) {
    return DemoRefundRecord(
      orderId: order.orderId,
      refundId: 'DEMO-REF-${order.orderId}',
      refundAmountInPaise: order.totalInPaise,
      paymentMethod: order.paymentMethod,
      status: DemoRefundStatus.refundProcessing,
      initiatedAt: order.dateTime,
      expectedDate: '5–7 business days',
    );
  }
}
