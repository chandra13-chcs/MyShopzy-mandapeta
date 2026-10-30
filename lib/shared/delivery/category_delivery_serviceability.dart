import 'package:flutter/material.dart';

import '../../features/profile/data/selected_delivery_address_store.dart';
import '../../features/profile/models/saved_address.dart';
import '../data/customer_api.dart';

enum DeliveryCategory {
  grocery('grocery', 'Groceries'),
  meat('meat', 'Meat'),
  vegetablesFruits('vegetables_fruits', 'Vegetables & Fruits'),
  bakery('bakery', 'Bakery'),
  restaurant('restaurant', 'Restaurant'),
  parcel('parcel', 'Parcel');

  const DeliveryCategory(this.apiValue, this.displayName);

  final String apiValue;
  final String displayName;
}

class CategoryDeliveryServiceability {
  CategoryDeliveryServiceability._();

  static final instance = CategoryDeliveryServiceability._();

  static const _cacheDuration = Duration(minutes: 3);
  static const _maximumCacheEntries = 100;

  final Map<String, _CachedServiceability> _cache = {};

  CategoryServiceabilityResponse? cachedResult({
    required DeliveryCategory category,
    required double latitude,
    required double longitude,
  }) {
    final key =
        '${category.apiValue}:${latitude.toStringAsPrecision(12)}:${longitude.toStringAsPrecision(12)}';
    final cached = _cache[key];
    if (cached == null || !cached.expiresAt.isAfter(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    return cached.response;
  }

  Future<CategoryServiceabilityResponse> check({
    required DeliveryCategory category,
    required double latitude,
    required double longitude,
  }) async {
    final key =
        '${category.apiValue}:${latitude.toStringAsPrecision(12)}:${longitude.toStringAsPrecision(12)}';
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.response;
    }
    if (cached != null) _cache.remove(key);

    final response = await CustomerApi.instance.checkCategoryServiceability(
      category: category.apiValue,
      latitude: latitude,
      longitude: longitude,
    );
    if (_cache.length >= _maximumCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CachedServiceability(
      response,
      DateTime.now().add(_cacheDuration),
    );
    return response;
  }
}

class CategoryDeliveryLimitBadge extends StatelessWidget {
  const CategoryDeliveryLimitBadge({
    required this.category,
    required this.foregroundColor,
    required this.backgroundColor,
    super.key,
  });

  final DeliveryCategory category;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SavedAddress?>(
      valueListenable: SelectedDeliveryAddressStore.instance.listenable,
      builder: (context, address, child) {
        final latitude = address?.latitude;
        final longitude = address?.longitude;
        if (latitude == null || longitude == null) {
          return const SizedBox.shrink();
        }
        final result = CategoryDeliveryServiceability.instance.cachedResult(
          category: category,
          latitude: latitude,
          longitude: longitude,
        );
        if (result == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '${result.maximumDistanceMeters ~/ 1000} km',
            style: TextStyle(
              color: foregroundColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class CategoryDeliveryGate extends StatefulWidget {
  const CategoryDeliveryGate({
    required this.category,
    required this.child,
    super.key,
  });

  final DeliveryCategory category;
  final Widget child;

  @override
  State<CategoryDeliveryGate> createState() => _CategoryDeliveryGateState();
}

class _CategoryDeliveryGateState extends State<CategoryDeliveryGate> {
  SavedAddress? _address;
  CategoryServiceabilityResponse? _result;
  bool _isChecking = true;
  bool _hasInvalidAddress = false;
  String? _errorMessage;
  int _requestRevision = 0;

  @override
  void initState() {
    super.initState();
    SelectedDeliveryAddressStore.instance.listenable.addListener(
      _handleAddressChanged,
    );
    _address = SelectedDeliveryAddressStore.instance.selectedAddress;
    _checkServiceability();
  }

  @override
  void didUpdateWidget(covariant CategoryDeliveryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) _checkServiceability();
  }

  @override
  void dispose() {
    SelectedDeliveryAddressStore.instance.listenable.removeListener(
      _handleAddressChanged,
    );
    super.dispose();
  }

  void _handleAddressChanged() {
    final address = SelectedDeliveryAddressStore.instance.selectedAddress;
    if (address == _address) return;
    _address = address;
    _checkServiceability();
  }

  Future<void> _checkServiceability() async {
    final revision = ++_requestRevision;
    final address = _address;
    if (address == null) {
      setState(() {
        _isChecking = false;
        _hasInvalidAddress = false;
        _result = null;
        _errorMessage = null;
      });
      return;
    }
    final latitude = address.latitude;
    final longitude = address.longitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() {
        _isChecking = false;
        _hasInvalidAddress = true;
        _result = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _hasInvalidAddress = false;
      _result = null;
      _errorMessage = null;
    });
    try {
      final result = await CategoryDeliveryServiceability.instance.check(
        category: widget.category,
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _result = result;
        _isChecking = false;
      });
    } on CustomerApiException catch (error) {
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _errorMessage = error.message;
        _isChecking = false;
      });
    } on Exception catch (error) {
      if (!mounted || revision != _requestRevision) return;
      debugPrint('Unable to verify ${widget.category.apiValue} route: $error');
      setState(() {
        _errorMessage = 'We could not verify the driving route. Check your connection and try again.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Checking delivery distance...'),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result?.isDeliverable == true) return widget.child;
    final title = _hasInvalidAddress
        ? 'Choose a valid delivery address'
        : _address == null
        ? 'Choose a delivery address'
        : result != null
        ? '${widget.category.displayName} delivery is unavailable'
        : 'Could not check delivery availability';
    final message = _hasInvalidAddress
        ? 'This address does not have valid map coordinates. Choose another saved address or set its location.'
        : _address == null
        ? 'Select an address on Home before browsing ${widget.category.displayName.toLowerCase()}.'
        : result?.message ??
              _errorMessage ??
              'We could not verify the driving route. Please try again.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  result != null
                      ? Icons.location_off_outlined
                      : Icons.route_outlined,
                  size: 42,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (result != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Driving distance: ${(result.distanceMeters / 1000).toStringAsFixed(1)} km · Limit: ${(result.maximumDistanceMeters / 1000).toStringAsFixed(0)} km',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  FilledButton(
                    onPressed: _checkServiceability,
                    child: const Text('Try again'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(_address == null ? 'Back to Home' : 'Go back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CachedServiceability {
  const _CachedServiceability(this.response, this.expiresAt);

  final CategoryServiceabilityResponse response;
  final DateTime expiresAt;
}
