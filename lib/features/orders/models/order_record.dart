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
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryChargeInPaise,
    required this.discountInPaise,
    this.trackingStatus,
    this.deliveryOtp,
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
  final String paymentMethod;
  final String paymentStatus;
  final int deliveryChargeInPaise;
  final int discountInPaise;
  String status;
  String statusMessage;
  OrdersTab orderTab;
  OrderTrackingStatus? trackingStatus;
  final String? deliveryOtp;

  int get itemTotalInPaise =>
      items.fold(0, (total, item) => total + item.lineTotalInPaise);

  String get total => '₹${(totalInPaise / 100).toStringAsFixed(0)}';
}
