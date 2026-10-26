import 'package:flutter/material.dart';

import '../presentation/order_tracking_page.dart';

enum OrdersTab { ongoing, delivered, cancelled }

class OrderLineItem {
  const OrderLineItem({
    required this.name,
    required this.quantity,
    required this.unitPriceInPaise,
    required this.icon,
    this.description,
    this.imageUrl,
    this.productId,
    this.serviceType,
    this.merchantId,
    this.serviceVariant,
    this.productVariantId,
    this.variantLabel,
  });

  final String name;
  final int quantity;
  final int unitPriceInPaise;
  final IconData icon;
  final String? description;
  final String? imageUrl;
  final String? productId;
  final String? serviceType;
  final String? merchantId;
  final String? serviceVariant;
  final String? productVariantId;
  final String? variantLabel;

  int get lineTotalInPaise => quantity * unitPriceInPaise;
}

class OrderRecord {
  OrderRecord({
    required this.storeName,
    required this.icon,
    required this.orderId,
    required this.dateTime,
    required this.itemSummary,
    required this.totalInPaise,
    required this.status,
    required this.statusMessage,
    required this.orderTab,
    required this.serviceType,
    required this.items,
    required this.deliveryAddress,
    this.deliveryAddressLabel = 'Home',
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryChargeInPaise,
    required this.discountInPaise,
    this.paymentVerified = false,
    this.trackingStatus,
    this.deliveryOtp,
    this.cancellationReason,
    this.deliveryInstruction,
    this.isBackendData = false,
    this.itemCount,
    this.cancellationEligible = false,
    this.cancellationDeadlineAt,
    this.serverNow,
  });

  final String storeName;
  final IconData icon;
  final String orderId;
  final String dateTime;
  final String itemSummary;
  final int totalInPaise;
  final String serviceType;
  final List<OrderLineItem> items;
  final String deliveryAddress;
  final String deliveryAddressLabel;
  final String paymentMethod;
  final String paymentStatus;
  final bool paymentVerified;
  final int deliveryChargeInPaise;
  final int discountInPaise;
  String status;
  String statusMessage;
  OrdersTab orderTab;
  OrderTrackingStatus? trackingStatus;
  final String? deliveryOtp;
  String? cancellationReason;
  final String? deliveryInstruction;
  final bool isBackendData;
  final int? itemCount;
  final bool cancellationEligible;
  final String? cancellationDeadlineAt;
  final String? serverNow;

  bool get isVerifiedSuccessfulPayment {
    final orderState = status.trim().toLowerCase();
    final paymentState = paymentStatus.trim().toLowerCase();
    return isBackendData &&
        paymentVerified &&
        const {
          'placed',
          'confirmed',
          'order placed',
          'order confirmed',
        }.contains(orderState) &&
        const {
          'paid',
          'success',
          'successful',
          'succeeded',
        }.contains(paymentState);
  }

  bool get canCustomerCancel =>
      orderTab == OrdersTab.ongoing &&
      switch (trackingStatus) {
        OrderTrackingStatus.orderPlaced ||
        OrderTrackingStatus.orderConfirmed ||
        OrderTrackingStatus.preparing => !isBackendData || cancellationEligible,
        _ => false,
      };

  bool cancelByCustomer(String reason) {
    final normalizedReason = reason.trim();
    if (!canCustomerCancel || normalizedReason.isEmpty) return false;

    status = 'Cancelled';
    statusMessage = 'This order was cancelled';
    orderTab = OrdersTab.cancelled;
    trackingStatus = null;
    cancellationReason = normalizedReason;
    return true;
  }

  int get itemTotalInPaise =>
      items.fold(0, (total, item) => total + item.lineTotalInPaise);

  String get total => '₹${(totalInPaise / 100).toStringAsFixed(0)}';
}
