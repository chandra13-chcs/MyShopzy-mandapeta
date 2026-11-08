import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import 'alert_service.dart';
import 'connectivity_service.dart';
import 'mock_order_service.dart';
import 'order_repository.dart';

/// All the live state of a working rider: online/offline, the incoming
/// order popup + countdown, the active delivery + its step, history,
/// earnings, wallet, notifications and language. Screens only read from
/// this and call its methods. Orders come from an [OrderRepository], so
/// swapping the mock for a real backend later does not touch any screen.
class RiderController extends ChangeNotifier with WidgetsBindingObserver {
  static const acceptSeconds = AppConfig.offerSeconds;
  static const minWithdraw = 100.0;
  static const dailyTarget = 8; // deliveries per day for the bonus
  static const dailyBonus = 100.0; // display only - a backend must pay it
  static const _kHistory = 'myshopzy_history';
  static const _kPayouts = 'myshopzy_payouts';
  static const _kNotifs = 'myshopzy_notifs';
  static const _kLang = 'myshopzy_lang';
  static const _kNotifOn = 'myshopzy_notif_on';
  static const _kActive = 'myshopzy_active';
  static const _kPayoutId = 'myshopzy_payout_id';
  static const maxQueue = 5; // orders waiting while the rider is busy
  static const codCashLimit =
      2000.0; // cannot go online above this cash in hand
  static const _kTheme = 'myshopzy_theme';
  static const _kStats = 'myshopzy_stats';
  static const _kOnlineDays = 'myshopzy_online_days';
  static const _kSeen = 'myshopzy_notif_seen';

  RiderController({OrderRepository? repository})
      : _repo = repository ?? MockOrderService() {
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _alertService.onStopped = () {
      if (!_disposed) notifyListeners();
    };
    _alertService.onNotificationTap = () {
      if (!_disposed) notifyListeners();
    };
    unawaited(_alertService.init());
    _sub = _repo.incomingOrders.listen(_onIncoming);
    _cancelSub = _repo.cancelledOrders.listen(_onCancelled);
  }

  final OrderRepository _repo;
  final AlertService _alertService = AlertService();
  StreamSubscription<Order>? _sub;
  StreamSubscription<String>? _cancelSub;
  Timer? _countdown;
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  bool _locationStarting = false;

  bool _online = false;
  bool _kycApproved = false;
  Order? _incoming;
  int _secondsLeft = 0;
  final List<Order> _queue = []; // orders that arrived while busy
  Order? _active;
  DeliveryStep _step = DeliveryStep.accepted;
  List<DeliveryRecord> _history = [];
  List<PayoutRecord> _payouts = [];
  List<AppNotification> _notifications = [];
  String _language = 'en';
  bool _notifEnabled = true;
  String? _payoutId; // rider's saved UPI ID / bank account number
  ThemeMode _themeMode = ThemeMode.system;
  DateTime? _acceptedAt; // when the current delivery was accepted
  bool _accepting = false; // waiting for the server to confirm Accept
  Order? _cancelled; // an accepted order the customer/shop cancelled
  bool _cancelledAfterPickup = false;
  int _offered = 0; // orders shown to the rider (for acceptance rate)
  int _accepted = 0;
  DateTime? _onlineSince; // set while online
  Timer? _onlineTicker; // refreshes the "online today" number
  Map<String, int> _onlineSecondsByDay = {}; // 'yyyy-m-d' -> seconds
  DateTime? _notifSeenAt; // notifications newer than this are "unread"
  bool _appResumed = true;
  bool _disposed = false;
  String? _mutedAlertOrderId;
  String? _alertStartingFor;

  // ---- read-only state for screens ----
  bool get online => _online;
  bool get kycApproved => _kycApproved;
  Position? get currentPosition => _currentPosition;
  Order? get incoming => _incoming;
  int get secondsLeft => _secondsLeft;
  int get queueLength => _queue.length;
  Order? get active => _active;
  DeliveryStep get step => _step;
  List<DeliveryRecord> get history => List.unmodifiable(_history);
  List<PayoutRecord> get payouts => List.unmodifiable(_payouts);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  String get language => _language;
  bool get notifEnabled => _notifEnabled;
  String? get payoutId => _payoutId;
  ThemeMode get themeMode => _themeMode;
  bool get cashLimitReached => cashInHand >= codCashLimit;
  DateTime? get acceptedAt => _acceptedAt;
  bool get accepting => _accepting;
  bool get alertRinging =>
      _incoming != null &&
      (_alertService.isRinging || _alertStartingFor == _incoming!.id);
  Order? get cancelled => _cancelled;
  bool get cancelledAfterPickup => _cancelledAfterPickup;

  /// Share of shown orders that the rider accepted, 0-100. Null = no data yet.
  int? get acceptanceRate =>
      _offered == 0 ? null : (_accepted * 100 / _offered).round();

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Seconds the rider has been online today (live while online).
  int get onlineSecondsToday {
    final now = DateTime.now();
    var secs = _onlineSecondsByDay[_dayKey(now)] ?? 0;
    final since = _onlineSince;
    if (since != null) {
      final startOfDay = DateTime(now.year, now.month, now.day);
      final from = since.isAfter(startOfDay) ? since : startOfDay;
      secs += now.difference(from).inSeconds;
    }
    return secs;
  }

  int get unreadCount => _notifications
      .where((n) => _notifSeenAt == null || n.time.isAfter(_notifSeenAt!))
      .length;

  Future<void> prepareNewOrderAlerts(BuildContext context) async {
    await _alertService.unlockAudio();
    if (!context.mounted) return;
    await _alertService.explainAndRequestNotificationPermission(context);
  }

  Future<void> muteIncomingAlert() async {
    _mutedAlertOrderId = _incoming?.id;
    _alertStartingFor = null;
    await _alertService.stop();
    if (!_disposed) notifyListeners();
  }

  Future<void> testNewOrderAlert() async {
    await _alertService.unlockAudio();
    await _alertService.testAlert();
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    final order = _incoming;
    if (_appResumed) {
      unawaited(_alertService.cancelBackgroundNotification());
    } else if (order != null) {
      unawaited(_ensureIncomingAlert(order, showNotification: true));
    } else {
      unawaited(_alertService.stop());
    }
  }

  Future<void> _ensureIncomingAlert(
    Order order, {
    bool showNotification = false,
  }) async {
    if (_mutedAlertOrderId == order.id) return;
    _alertStartingFor = order.id;
    await _alertService.startNewOrderAlert(order.id);
    if (_alertStartingFor == order.id) _alertStartingFor = null;
    if (_incoming?.id != order.id) return;
    if (showNotification && !_appResumed) {
      await _alertService.showBackgroundNotification(
        orderId: order.id,
        body: T
            .t('new_order_notification')
            .replaceAll('{amount}', order.earning.toStringAsFixed(0))
            .replaceAll('{distance}', order.distanceKm.toStringAsFixed(1)),
      );
    }
    if (!_disposed) notifyListeners();
  }

  double _sum(Iterable<DeliveryRecord> r) =>
      r.fold(0.0, (a, b) => a + b.earning);

  List<DeliveryRecord> get todayDeliveries {
    final now = DateTime.now();
    return _history
        .where((r) =>
            r.completedAt.year == now.year &&
            r.completedAt.month == now.month &&
            r.completedAt.day == now.day)
        .toList();
  }

  double get todayEarnings => _sum(todayDeliveries);
  double get weekEarnings {
    final from = DateTime.now().subtract(const Duration(days: 7));
    return _sum(_history.where((r) => r.completedAt.isAfter(from)));
  }

  double get totalEarnings => _sum(_history);

  /// Earnings per day for the last 7 days, oldest first (last item = today).
  List<double> get last7DaysEarnings {
    final now = DateTime.now();
    return List<double>.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day - (6 - i));
      return _sum(_history.where((r) =>
          r.completedAt.year == day.year &&
          r.completedAt.month == day.month &&
          r.completedAt.day == day.day));
    });
  }

  double get averageRating => _history.isEmpty
      ? 0
      : _history.fold(0, (a, b) => a + b.rating) / _history.length;

  double _paid(String kind) =>
      _payouts.where((p) => p.kind == kind).fold(0.0, (a, b) => a + b.amount);

  /// COD cash the rider collected and has not yet deposited.
  double get cashInHand {
    final collected = _history.fold(0.0, (a, b) => a + b.codCollected);
    final v = collected - _paid(PayoutRecord.codDeposit);
    return v < 0 ? 0 : v;
  }

  /// Earnings not yet withdrawn.
  double get balance {
    final v = totalEarnings - _paid(PayoutRecord.withdraw);
    return v < 0 ? 0 : v;
  }

  // ---- load / save ----
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _language = p.getString(_kLang) ?? 'en';
    T.lang = _language;
    _notifEnabled = p.getBool(_kNotifOn) ?? true;
    _payoutId = p.getString(_kPayoutId);
    final savedTheme = p.getString(_kTheme);
    _themeMode = ThemeMode.values.firstWhere((m) => m.name == savedTheme,
        orElse: () => ThemeMode.system);
    try {
      final st =
          jsonDecode(p.getString(_kStats) ?? '{}') as Map<String, dynamic>;
      _offered = st['offered'] as int? ?? 0;
      _accepted = st['accepted'] as int? ?? 0;
      final days =
          jsonDecode(p.getString(_kOnlineDays) ?? '{}') as Map<String, dynamic>;
      _onlineSecondsByDay = days.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _offered = 0;
      _accepted = 0;
      _onlineSecondsByDay = {};
    }
    final seen = p.getString(_kSeen);
    _notifSeenAt = seen == null ? null : DateTime.tryParse(seen);
    _history = _readList(p, _kHistory, DeliveryRecord.fromJson);
    _payouts = _readList(p, _kPayouts, PayoutRecord.fromJson);
    _notifications = _readList(p, _kNotifs, AppNotification.fromJson);
    // Bring back a delivery that was in progress when the app was closed.
    final rawActive = p.getString(_kActive);
    if (rawActive != null) {
      try {
        final m = jsonDecode(rawActive) as Map<String, dynamic>;
        _active = Order.fromJson(m['order'] as Map<String, dynamic>);
        _acceptedAt =
            DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now();
        final i = m['step'] as int;
        final last = DeliveryStep.reachedCustomer.index;
        _step = DeliveryStep.values[i < 0 ? 0 : (i > last ? last : i)];
      } catch (_) {
        _active = null; // corrupted data: ignore it
        _step = DeliveryStep.accepted;
      }
    }
    notifyListeners();
  }

  List<E> _readList<E>(SharedPreferences p, String key,
      E Function(Map<String, dynamic>) fromJson) {
    final raw = p.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // corrupted data: start clean instead of crashing
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kHistory, jsonEncode(_history.map((e) => e.toJson()).toList()));
    await p.setString(
        _kPayouts, jsonEncode(_payouts.map((e) => e.toJson()).toList()));
    await p.setString(
        _kNotifs, jsonEncode(_notifications.map((e) => e.toJson()).toList()));
    await p.setString(_kLang, _language);
    await p.setBool(_kNotifOn, _notifEnabled);
    await p.setString(_kTheme, _themeMode.name);
    if (_payoutId != null) await p.setString(_kPayoutId, _payoutId!);
    await p.setString(
        _kStats, jsonEncode({'offered': _offered, 'accepted': _accepted}));
    await p.setString(_kOnlineDays, jsonEncode(_onlineSecondsByDay));
    if (_notifSeenAt != null) {
      await p.setString(_kSeen, _notifSeenAt!.toIso8601String());
    }
    if (_active != null) {
      await p.setString(
          _kActive,
          jsonEncode({
            'order': _active!.toJson(),
            'step': _step.index,
            'at': (_acceptedAt ?? DateTime.now()).toIso8601String(),
          }));
    } else {
      await p.remove(_kActive);
    }
  }

  // ---- Feature 2: online / offline ----
  /// Returns false when the rider is not allowed to switch online/offline.
  void setKycApproved(bool value) {
    if (_kycApproved == value) return;
    _kycApproved = value;
    if (!value && _online) {
      setOnline(false);
    } else {
      notifyListeners();
    }
  }

  bool setOnline(bool value) {
    if (value && !_kycApproved) return false;
    if (value == _online) return true;
    if (!value && _active != null) return false;
    if (value && cashLimitReached) return false; // deposit the cash first
    _online = value;
    if (value) {
      unawaited(_startLocationTracking());
      _repo.goOnline();
      _startOnlineClock();
    } else {
      unawaited(_alertService.stop());
      _repo.goOffline();
      _stopLocationTracking();
      _stopOnlineClock();
      _queue.clear(); // stop offering orders that queued up while busy
      if (_incoming != null) reject(countAsOffered: false);
    }
    notifyListeners();
    _save();
    return true;
  }

  Future<void> _startLocationTracking() async {
    if (_positionSub != null || _locationStarting) return;
    _locationStarting = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Rider location unavailable: permission $permission');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!_online) return;
      _updatePosition(position);
      _positionSub = Geolocator.getPositionStream().listen(
        _updatePosition,
        onError: (Object error) =>
            debugPrint('Rider location stream failed: $error'),
      );
    } catch (error) {
      debugPrint('Could not obtain rider location: $error');
    } finally {
      _locationStarting = false;
    }
  }

  void _updatePosition(Position position) {
    _currentPosition = position;
    MockOrderService.riderLat = position.latitude;
    MockOrderService.riderLng = position.longitude;
    notifyListeners();
  }

  void _stopLocationTracking() {
    _currentPosition = null;
    final subscription = _positionSub;
    _positionSub = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _startOnlineClock() {
    _onlineSince = DateTime.now();
    _onlineTicker?.cancel();
    // Refresh the "online today" number on screen every 30 seconds.
    _onlineTicker =
        Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  void _stopOnlineClock() {
    final since = _onlineSince;
    _onlineTicker?.cancel();
    _onlineTicker = null;
    _onlineSince = null;
    if (since == null) return;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final from = since.isAfter(startOfDay) ? since : startOfDay;
    final key = _dayKey(now);
    _onlineSecondsByDay[key] =
        (_onlineSecondsByDay[key] ?? 0) + now.difference(from).inSeconds;
  }

  // ---- Feature 3: incoming order, accept / reject, timer, queue ----
  /// Called whenever the repository pushes a new order. If the rider is
  /// free (no popup showing, no active delivery) it is shown right away.
  /// If the rider is busy, it waits in a short queue instead of being
  /// lost, and is shown automatically as soon as the rider is free again -
  /// this is what keeps a steady stream of orders arriving while online
  /// from ever silently disappearing.
  void _onIncoming(Order o) {
    if (!_online || cashLimitReached) return;
    final position = _currentPosition;
    final riderToShopKm = position == null
        ? null
        : Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              o.shopLat,
              o.shopLng,
            ) /
            1000;
    if (!o.withinLimits(riderToShopKm: riderToShopKm)) {
      final reason = o.type == OrderType.food
          ? position == null
              ? 'rider location unavailable'
              : 'pickup ${riderToShopKm!.toStringAsFixed(2)} km, '
                  'drop ${o.distanceKm.toStringAsFixed(2)} km'
          : 'parcel ${o.distanceKm.toStringAsFixed(2)} km';
      debugPrint('Ignoring ${o.type.name} order ${o.id}: $reason');
      return;
    }
    o = o.copyWith(pickupDistanceKm: riderToShopKm);
    if (_incoming != null || _active != null || _cancelled != null) {
      if (_queue.length < maxQueue) {
        _queue.add(o);
        notifyListeners();
      }
      return;
    }
    _presentIncoming(o);
  }

  void _presentIncoming(Order o) {
    _incoming = o;
    _mutedAlertOrderId = null;
    _offered++;
    final now = DateTime.now();
    final maxDeadline = now.add(const Duration(seconds: acceptSeconds));
    final deadline = o.expiresAt != null && o.expiresAt!.isBefore(maxDeadline)
        ? o.expiresAt!
        : maxDeadline;
    _secondsLeft = (deadline.difference(now).inMilliseconds / 1000)
        .ceil()
        .clamp(0, acceptSeconds)
        .toInt();
    if (_secondsLeft == 0) {
      reject(countAsOffered: true);
      return;
    }
    // Count down against a real deadline (not "minus 1 per tick") so the
    // number is still right if the phone paused the app in the background.
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_accepting) return; // the server is confirming Accept - wait for it
      final msLeft = deadline.difference(DateTime.now()).inMilliseconds;
      _secondsLeft = (msLeft / 1000).ceil();
      if (_secondsLeft <= 0) {
        reject(countAsOffered: true); // timed out = same as rejecting
      } else {
        notifyListeners();
      }
    });
    unawaited(_ensureIncomingAlert(o, showNotification: !_appResumed));
    if (_notifEnabled) {
      _addNotification(T.t('notif_new_order'),
          '${o.shopName} - ${o.distanceKm} ${T.t('km')} - ${T.t('you_earn')} ₹${o.earning.toStringAsFixed(0)}');
    }
    notifyListeners();
  }

  /// Shows the next queued order, if the rider is online, free, and one
  /// is waiting. Called after accept/reject/timeout and after a delivery
  /// finishes or is released, so queued orders are never stuck.
  void _tryShowNext() {
    if (_online &&
        _incoming == null &&
        _active == null &&
        _cancelled == null &&
        _queue.isNotEmpty) {
      _presentIncoming(_queue.removeAt(0));
    }
  }

  /// Rider tapped Accept. Asks the server first and only then starts the
  /// delivery. Returns null on success, or a translation key on failure
  /// (no internet, order already taken...). On failure the popup is closed.
  Future<String?> accept() async {
    final o = _incoming;
    if (o == null || _accepting) return null;
    _alertStartingFor = null;
    await _alertService.stop();
    final position = _currentPosition;
    final riderToShopKm = position == null
        ? null
        : Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              o.shopLat,
              o.shopLng,
            ) /
            1000;
    if (!o.withinLimits(riderToShopKm: riderToShopKm)) {
      _countdown?.cancel();
      _incoming = null;
      if (_offered > 0) _offered--;
      notifyListeners();
      _tryShowNext();
      return 'err_too_far';
    }
    final acceptedOrder = o.copyWith(pickupDistanceKm: riderToShopKm);
    _accepting = true;
    notifyListeners();
    try {
      await _repo.acceptOrder(o.id);
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      _accepting = false;
      _countdown?.cancel();
      if (_incoming?.id == o.id) _incoming = null;
      notifyListeners();
      _tryShowNext();
      return 'err_accept_failed';
    }
    ConnectivityService.instance.reportRepositorySuccess();
    _accepting = false;
    if (_incoming?.id != o.id) {
      // The order was cancelled while we were waiting for the server.
      notifyListeners();
      return 'err_accept_failed';
    }
    _countdown?.cancel();
    _incoming = null;
    _accepted++;
    _active = acceptedOrder;
    _step = DeliveryStep.accepted;
    _acceptedAt = DateTime.now();
    notifyListeners();
    _save();
    return null;
  }

  // ---- Order cancelled by the customer / shop ----
  void _onCancelled(String id) {
    // 1) The popup on screen.
    if (_incoming?.id == id) {
      _alertStartingFor = null;
      unawaited(_alertService.stop());
      _countdown?.cancel();
      _incoming = null;
      _addNotification(T.t('notif_cancelled'), id);
      notifyListeners();
      if (!_accepting) _tryShowNext();
      return;
    }
    // 2) Waiting in the queue.
    final before = _queue.length;
    _queue.removeWhere((q) => q.id == id);
    if (_queue.length != before) {
      notifyListeners();
      return;
    }
    // 3) The delivery in progress.
    final a = _active;
    if (a != null && a.id == id) {
      _cancelled = a;
      _cancelledAfterPickup = _step.index >= DeliveryStep.pickedUp.index;
      _active = null;
      _step = DeliveryStep.accepted;
      _acceptedAt = null;
      _addNotification(T.t('notif_cancelled'), '$id - ${a.shopName}');
      notifyListeners();
      _save();
    }
  }

  /// Rider tapped OK on the "order cancelled" notice.
  void acknowledgeCancelled() {
    _cancelled = null;
    _cancelledAfterPickup = false;
    notifyListeners();
    _tryShowNext();
  }

  /// [countAsOffered] is only false when the rider goes offline with a
  /// popup open (that is not a "no" to the order, so it does not hurt the
  /// acceptance rate).
  void reject({bool countAsOffered = true}) {
    final o = _incoming;
    _alertStartingFor = null;
    unawaited(_alertService.stop());
    _countdown?.cancel();
    _incoming = null;
    if (o != null && !countAsOffered && _offered > 0) _offered--;
    if (o != null) _repo.rejectOrder(o.id);
    notifyListeners();
    _tryShowNext();
  }

  // ---- Feature 4: delivery steps ----
  /// Moves accepted -> reachedHotel -> pickedUp -> reachedCustomer.
  /// The last step (delivered) happens in [completeDelivery] after proof.
  void advanceStep() {
    if (_active == null) return;
    if (_step.index < DeliveryStep.reachedCustomer.index) {
      _step = DeliveryStep.values[_step.index + 1];
      notifyListeners();
      _save();
    }
  }

  /// The rider cannot finish this delivery (shop closed, customer not
  /// answering, wrong address, vehicle problem). The order is released.
  Future<void> reportIssue(String reasonKey) async {
    final o = _active;
    if (o == null) return;
    _repo.rejectOrder(o.id);
    _addNotification(T.t('notif_issue'), '${o.id} - ${T.t(reasonKey)}');
    _active = null;
    _step = DeliveryStep.accepted;
    notifyListeners();
    await _save();
    _tryShowNext();
  }

  // ---- Feature 6 + 8: finish delivery (OTP/photo already checked by screen) ----
  bool otpMatches(String code) =>
      _active != null && code == _active!.deliveryOtp;

  /// Returns null on success, or a translation key when it failed
  /// (no internet, or the order was cancelled meanwhile).
  Future<String?> completeDelivery({String? photoPath}) async {
    final o = _active;
    if (o == null) return null;
    try {
      await _repo.completeOrder(o.id);
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      return 'err_network';
    }
    ConnectivityService.instance.reportRepositorySuccess();
    if (_active?.id != o.id) return 'order_cancelled';
    _history.insert(
      0,
      DeliveryRecord(
        orderId: o.id,
        shopName: o.shopName,
        shopAddress: o.shopAddress,
        customerName: o.customerName,
        customerAddress: o.customerAddress,
        items: o.items,
        type: o.type,
        payment: o.payment,
        earning: o.earning,
        codCollected: o.codAmount,
        rating: 3 + Random().nextInt(3), // mock customer rating 3-5
        completedAt: DateTime.now(),
        photoPath: photoPath,
      ),
    );
    _step = DeliveryStep.delivered;
    _active = null;
    _addNotification(
        T.t('notif_delivered'), '${o.id} - ₹${o.earning.toStringAsFixed(0)}');
    notifyListeners();
    await _save();
    _tryShowNext();
    return null;
  }

  // ---- Feature 8: wallet ----
  /// Returns null on success, or a translation key describing the problem.
  Future<String?> withdraw(double amount) async {
    if (_payoutId == null || _payoutId!.trim().isEmpty) return 'err_payout_id';
    if (amount < minWithdraw) return 'min_withdraw';
    if (amount > balance) return 'too_much';
    bool ok;
    try {
      ok = await _repo.requestWithdraw(amount);
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      return 'err_network';
    }
    ConnectivityService.instance.reportRepositorySuccess();
    if (!ok) return 'err_withdraw_rejected';
    _payouts.insert(
        0,
        PayoutRecord(
            kind: PayoutRecord.withdraw, amount: amount, date: DateTime.now()));
    _addNotification(T.t('notif_withdraw'), '₹${amount.toStringAsFixed(0)}');
    notifyListeners();
    await _save();
    return null;
  }

  /// Returns null on success, or a translation key when it failed.
  Future<String?> depositCash() async {
    final amount = cashInHand;
    if (amount <= 0) return null;
    try {
      if (!await _repo.depositCash(amount)) {
        ConnectivityService.instance.reportRepositoryFailure();
        return 'err_network';
      }
    } catch (_) {
      ConnectivityService.instance.reportRepositoryFailure();
      return 'err_network';
    }
    ConnectivityService.instance.reportRepositorySuccess();
    _payouts.insert(
        0,
        PayoutRecord(
            kind: PayoutRecord.codDeposit,
            amount: amount,
            date: DateTime.now()));
    notifyListeners();
    await _save();
    return null;
  }

  /// Saves the rider's UPI ID or bank account number, so it only has to
  /// be typed once and is remembered for every future withdrawal.
  Future<void> setPayoutId(String id) async {
    _payoutId = id.trim();
    notifyListeners();
    await _save();
  }

  // ---- Feature 9: language + notifications ----
  Future<void> setLanguage(String code) async {
    _language = code;
    T.lang = code;
    notifyListeners();
    await _save();
  }

  Future<void> setNotifEnabled(bool v) async {
    _notifEnabled = v;
    notifyListeners();
    await _save();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    notifyListeners();
    await _save();
  }

  /// Marks everything in the notification list as read (removes the badge).
  Future<void> markNotificationsSeen() async {
    _notifSeenAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> clearNotifications() async {
    _notifications = [];
    _notifSeenAt = DateTime.now();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kNotifs);
    await _save();
  }

  void _addNotification(String title, String body) {
    _notifications.insert(
        0, AppNotification(title: title, body: body, time: DateTime.now()));
    if (_notifications.length > 50) _notifications.removeLast();
  }

  /// Called on sign out: forget everything about this rider.
  Future<void> reset() async {
    await _alertService.stop();
    _mutedAlertOrderId = null;
    _countdown?.cancel();
    _repo.goOffline();
    _stopLocationTracking();
    _online = false;
    _incoming = null;
    _queue.clear();
    _active = null;
    _history = [];
    _payouts = [];
    _notifications = [];
    _payoutId = null;
    _acceptedAt = null;
    _cancelled = null;
    _accepting = false;
    _offered = 0;
    _accepted = 0;
    _onlineSince = null;
    _onlineTicker?.cancel();
    _onlineSecondsByDay = {};
    _notifSeenAt = null;
    final p = await SharedPreferences.getInstance();
    _step = DeliveryStep.accepted;
    for (final k in [
      _kHistory,
      _kPayouts,
      _kNotifs,
      _kActive,
      _kPayoutId,
      _kStats,
      _kOnlineDays,
      _kSeen
    ]) {
      await p.remove(k);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_alertService.dispose());
    _countdown?.cancel();
    _onlineTicker?.cancel();
    _stopLocationTracking();
    _sub?.cancel();
    _cancelSub?.cancel();
    _repo.dispose();
    super.dispose();
  }
}
