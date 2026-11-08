import 'dart:async';
import 'dart:math';
import '../constants/app_config.dart';
import '../models/order.dart';
import 'order_repository.dart';

/// Fake order source for testing the whole app with no backend.
/// While the rider is online it creates a new order after ~4 seconds,
/// then another every 20 seconds (the controller ignores extras while
/// the rider already has an order on screen).
class MockOrderService implements OrderRepository {
  final _controller = StreamController<Order>.broadcast();
  final _cancelled = StreamController<String>.broadcast();
  final List<Timer> _cancelTimers = [];

  /// TEST SWITCHES (change them here to test the error screens):
  /// 1 in N accepted orders gets cancelled 25 seconds later (0 = never).
  static int cancelOneIn = 5;

  /// 1 in N server calls throws a fake network error (0 = never, try 4).
  static int failOneIn = 0;
  static double riderLat = 17.4948;
  static double riderLng = 78.3996;

  void _maybeFail() {
    if (failOneIn > 0 && _rand.nextInt(failOneIn) == 0) {
      throw Exception('Mock network error');
    }
  }

  final _rand = Random();
  Timer? _timer;
  int _counter = 1000;

  static const _shops = [
    [
      'Paradise Biryani',
      '9000000001',
      'Plot 12, Main Road, Kukatpally',
      17.4948,
      78.3996
    ],
    [
      'Sri Balaji Tiffins',
      '9000000002',
      'Shop 4, KPHB Colony',
      17.4849,
      78.3908
    ],
    [
      'Fresh Mart Grocery',
      '9000000003',
      '2-45, Moosapet Circle',
      17.4642,
      78.4260
    ],
    [
      'Apollo Pharmacy',
      '9000000004',
      'Opp. Metro Station, Ameerpet',
      17.4375,
      78.4483
    ],
  ];
  static const _customers = [
    ['Ravi Kumar', '9111111101', 'Flat 301, Sai Residency, Nizampet'],
    ['Lakshmi Devi', '9111111102', 'H.No 8-3-12, Ameerpet'],
    ['Arjun Reddy', '9111111103', 'Block C, Vasanth Nagar Apartments'],
    ['Priya Sharma', '9111111104', '15-7, Madhapur Main Road'],
  ];
  static const _items = [
    '2 x Chicken Biryani, 1 x Raita',
    '3 x Idli, 2 x Masala Dosa',
    'Rice 5kg, Dal 1kg, Oil 1L',
    'Paracetamol, Cough syrup',
  ];

  static const _notes = [
    '',
    '',
    'Ring the bell twice',
    'Leave at the gate, do not call',
    'Please call before arriving',
  ];

  @override
  Stream<Order> get incomingOrders => _controller.stream;

  @override
  Stream<String> get cancelledOrders => _cancelled.stream;

  @override
  void goOnline() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      _emit();
      _timer = Timer.periodic(const Duration(seconds: 20), (_) => _emit());
    });
  }

  @override
  void goOffline() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit() {
    if (_controller.isClosed) return;
    final shop = _shops[_rand.nextInt(_shops.length)];
    final cust = _customers[_rand.nextInt(_customers.length)];
    final type = _rand.nextInt(10) < 7 ? OrderType.food : OrderType.parcel;
    final shopPoint = _destination(
      riderLat,
      riderLng,
      _rand.nextDouble() * 5,
      _rand.nextDouble() * 2 * pi,
    );
    final requestedDropKm = type == OrderType.food
        ? 1 + _rand.nextDouble() * 13
        : 3 + _rand.nextDouble() * 32;
    final customerPoint = _destination(
      shopPoint.$1,
      shopPoint.$2,
      requestedDropKm,
      _rand.nextDouble() * 2 * pi,
    );
    final distance = _haversine(
      shopPoint.$1,
      shopPoint.$2,
      customerPoint.$1,
      customerPoint.$2,
    );
    final total = (150 + _rand.nextInt(60) * 10).toDouble();
    final tip =
        _rand.nextInt(3) == 0 ? (10 + _rand.nextInt(3) * 10).toDouble() : 0.0;
    final parcelContact = _customers[_rand.nextInt(_customers.length)];
    _counter++;
    _controller.add(Order(
      id: 'MS$_counter',
      shopName: type == OrderType.parcel ? 'Pickup contact' : shop[0] as String,
      shopPhone:
          type == OrderType.parcel ? parcelContact[1] : shop[1] as String,
      shopAddress: type == OrderType.parcel
          ? '${parcelContact[0]} · ${parcelContact[2]}'
          : shop[2] as String,
      shopLat: shopPoint.$1,
      shopLng: shopPoint.$2,
      customerName: cust[0],
      customerPhone: cust[1],
      customerAddress: cust[2],
      customerLat: customerPoint.$1,
      customerLng: customerPoint.$2,
      items: type == OrderType.parcel
          ? const ['Documents', 'Small box (1 kg)'][_rand.nextInt(2)]
          : _items[_rand.nextInt(_items.length)],
      orderTotal: total,
      earning: type == OrderType.food
          ? (25 + distance * 8 + tip).roundToDouble()
          : (40 + distance * 10).roundToDouble(),
      distanceKm: distance,
      type: type,
      payment: _rand.nextBool() ? PaymentType.cod : PaymentType.online,
      deliveryOtp: (1000 + _rand.nextInt(9000)).toString(),
      tip: type == OrderType.food ? tip : 0,
      note: _notes[_rand.nextInt(_notes.length)],
      expiresAt:
          DateTime.now().add(const Duration(seconds: AppConfig.offerSeconds)),
    ));
  }

  (double, double) _destination(
      double latitude, double longitude, double distanceKm, double bearing) {
    const earthRadiusKm = 6371.0;
    final angularDistance = distanceKm / earthRadiusKm;
    final lat1 = latitude * pi / 180;
    final lon1 = longitude * pi / 180;
    final lat2 = asin(sin(lat1) * cos(angularDistance) +
        cos(lat1) * sin(angularDistance) * cos(bearing));
    final lon2 = lon1 +
        atan2(
          sin(bearing) * sin(angularDistance) * cos(lat1),
          cos(angularDistance) - sin(lat1) * sin(lat2),
        );
    return (lat2 * 180 / pi, lon2 * 180 / pi);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = pow(sin(dLat / 2), 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLon / 2), 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Future<void> acceptOrder(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _maybeFail();
    if (cancelOneIn > 0 && _rand.nextInt(cancelOneIn) == 0) {
      _cancelTimers.add(Timer(const Duration(seconds: 25), () {
        if (!_cancelled.isClosed) _cancelled.add(orderId);
      }));
    }
  }

  @override
  Future<void> rejectOrder(String orderId) async {}

  @override
  Future<void> completeOrder(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _maybeFail();
  }

  @override
  Future<bool> requestWithdraw(double amount) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _maybeFail();
    return true;
  }

  @override
  Future<bool> depositCash(double amount) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _maybeFail();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final t in _cancelTimers) {
      t.cancel();
    }
    _controller.close();
    _cancelled.close();
  }
}
