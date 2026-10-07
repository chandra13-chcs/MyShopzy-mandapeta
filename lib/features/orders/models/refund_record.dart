enum DemoRefundStatus {
  refundInitiated,
  refundProcessing,
  refundCompleted,
  refundFailed,
}

class DemoRefundRecord {
  const DemoRefundRecord({
    required this.orderId,
    required this.refundId,
    required this.refundAmountInPaise,
    required this.paymentMethod,
    required this.status,
    required this.initiatedAt,
    this.completedAt,
    this.expectedDate,
    this.failureReason,
  });

  final String orderId;
  final String refundId;
  final int refundAmountInPaise;
  final String paymentMethod;
  final DemoRefundStatus status;
  final String initiatedAt;
  final String? completedAt;
  final String? expectedDate;
  final String? failureReason;
}
