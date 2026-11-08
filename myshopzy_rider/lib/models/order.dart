import '../constants/app_config.dart';

/// How the customer pays for the order.
enum PaymentType { online, cod }

enum OrderType { food, parcel }

/// The 5 steps of one delivery, in order.
enum DeliveryStep {
  accepted,
  reachedHotel,
  pickedUp,
  reachedCustomer,
  delivered
}

/// One delivery request. Plain data - no logic about where it came from,
/// so a backend developer can fill it from a real API later.
class Order {
  final String id;
  final String shopName;
  final String shopPhone;
  final String shopAddress;
  final double shopLat;
  final double shopLng;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final String items;
  final double orderTotal; // what the customer pays for the food/goods
  final double earning; // what the rider earns for this delivery
  final double distanceKm;
  final OrderType type;
  final double? pickupDistanceKm;
  final PaymentType payment;
  final String deliveryOtp; // customer tells this to the rider at the door
  final double tip; // already INCLUDED in [earning]; shown so the rider sees it
  final String note; // customer's delivery instruction, may be empty
  final DateTime? expiresAt;

  const Order({
    required this.id,
    required this.shopName,
    required this.shopPhone,
    required this.shopAddress,
    required this.shopLat,
    required this.shopLng,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    required this.items,
    required this.orderTotal,
    required this.earning,
    required this.distanceKm,
    this.type = OrderType.food,
    this.pickupDistanceKm,
    required this.payment,
    required this.deliveryOtp,
    this.tip = 0,
    this.note = '',
    this.expiresAt,
  });

  /// Rough time for the whole trip in minutes (shown before accepting).
  int get etaMinutes => (distanceKm * 4 + 8).round();

  /// Cash the rider must collect at the door (0 for online payments).
  double get codAmount => payment == PaymentType.cod ? orderTotal : 0;

  bool withinLimits({double? riderToShopKm}) {
    if (type == OrderType.parcel) return distanceKm <= AppConfig.parcelMaxKm;
    return riderToShopKm != null &&
        riderToShopKm <= AppConfig.foodMaxPickupKm &&
        distanceKm <= AppConfig.foodMaxDropKm;
  }

  Order copyWith({double? pickupDistanceKm}) => Order(
        id: id,
        shopName: shopName,
        shopPhone: shopPhone,
        shopAddress: shopAddress,
        shopLat: shopLat,
        shopLng: shopLng,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        customerLat: customerLat,
        customerLng: customerLng,
        items: items,
        orderTotal: orderTotal,
        earning: earning,
        distanceKm: distanceKm,
        type: type,
        pickupDistanceKm: pickupDistanceKm ?? this.pickupDistanceKm,
        payment: payment,
        deliveryOtp: deliveryOtp,
        tip: tip,
        note: note,
        expiresAt: expiresAt,
      );

  /// Used to save the active delivery so it survives closing the app.
  Map<String, dynamic> toJson() => {
        'id': id,
        'shopName': shopName,
        'shopPhone': shopPhone,
        'shopAddress': shopAddress,
        'shopLat': shopLat,
        'shopLng': shopLng,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'customerLat': customerLat,
        'customerLng': customerLng,
        'items': items,
        'orderTotal': orderTotal,
        'earning': earning,
        'distanceKm': distanceKm,
        'type': type.name,
        'pickupDistanceKm': pickupDistanceKm,
        'payment': payment.name,
        'deliveryOtp': deliveryOtp,
        'tip': tip,
        'note': note,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        shopName: j['shopName'] as String,
        shopPhone: j['shopPhone'] as String,
        shopAddress: j['shopAddress'] as String,
        shopLat: (j['shopLat'] as num).toDouble(),
        shopLng: (j['shopLng'] as num).toDouble(),
        customerName: j['customerName'] as String,
        customerPhone: j['customerPhone'] as String,
        customerAddress: j['customerAddress'] as String,
        customerLat: (j['customerLat'] as num).toDouble(),
        customerLng: (j['customerLng'] as num).toDouble(),
        items: j['items'] as String,
        orderTotal: (j['orderTotal'] as num).toDouble(),
        earning: (j['earning'] as num).toDouble(),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        type: j['type'] == 'parcel' ? OrderType.parcel : OrderType.food,
        pickupDistanceKm: (j['pickupDistanceKm'] as num?)?.toDouble(),
        payment: j['payment'] == 'cod' ? PaymentType.cod : PaymentType.online,
        deliveryOtp: j['deliveryOtp'] as String,
        tip: (j['tip'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
        expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
      );
}

/// A finished delivery, kept for the earnings + history screens.
/// A few fields (shopAddress, customerName, items, payment) were added
/// after the first version shipped, so fromJson() fills them with safe
/// defaults when reading old saved data that does not have them yet.
class DeliveryRecord {
  final String orderId;
  final String shopName;
  final String shopAddress;
  final String customerName;
  final String customerAddress;
  final String items;
  final OrderType type;
  final PaymentType payment;
  final double earning;
  final double codCollected;
  final int rating; // 1-5 from the customer (mock)
  final DateTime completedAt;
  final String? photoPath;

  DeliveryRecord({
    required this.orderId,
    required this.shopName,
    this.shopAddress = '',
    this.customerName = '',
    required this.customerAddress,
    this.items = '',
    this.type = OrderType.food,
    this.payment = PaymentType.online,
    required this.earning,
    required this.codCollected,
    required this.rating,
    required this.completedAt,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'shopName': shopName,
        'shopAddress': shopAddress,
        'customerName': customerName,
        'customerAddress': customerAddress,
        'items': items,
        'type': type.name,
        'payment': payment.name,
        'earning': earning,
        'codCollected': codCollected,
        'rating': rating,
        'completedAt': completedAt.toIso8601String(),
        'photoPath': photoPath,
      };

  factory DeliveryRecord.fromJson(Map<String, dynamic> j) => DeliveryRecord(
        orderId: j['orderId'] as String,
        shopName: j['shopName'] as String,
        shopAddress: j['shopAddress'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        customerAddress: j['customerAddress'] as String,
        items: j['items'] as String? ?? '',
        type: j['type'] == 'parcel' ? OrderType.parcel : OrderType.food,
        payment: j['payment'] == 'cod' ? PaymentType.cod : PaymentType.online,
        earning: (j['earning'] as num).toDouble(),
        codCollected: (j['codCollected'] as num).toDouble(),
        rating: j['rating'] as int,
        completedAt: DateTime.parse(j['completedAt'] as String),
        photoPath: j['photoPath'] as String?,
      );
}

/// Money moving out of the rider's wallet: a withdrawal to the bank,
/// or a deposit of cash-on-delivery money back to MyShopzy.
class PayoutRecord {
  static const withdraw = 'withdraw';
  static const codDeposit = 'cod_deposit';

  final String kind;
  final double amount;
  final DateTime date;

  PayoutRecord({required this.kind, required this.amount, required this.date});

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'amount': amount, 'date': date.toIso8601String()};

  factory PayoutRecord.fromJson(Map<String, dynamic> j) => PayoutRecord(
        kind: j['kind'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
      );
}

/// A message in the notifications list.
class AppNotification {
  final String title;
  final String body;
  final DateTime time;

  AppNotification(
      {required this.title, required this.body, required this.time});

  Map<String, dynamic> toJson() =>
      {'title': title, 'body': body, 'time': time.toIso8601String()};

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        title: j['title'] as String,
        body: j['body'] as String,
        time: DateTime.parse(j['time'] as String),
      );
}
