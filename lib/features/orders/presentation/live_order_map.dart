import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LiveOrderMap extends StatefulWidget {
  const LiveOrderMap({
    this.riderLocationStream,
    this.initialRiderLocation,
    this.initialCustomerLocation,
    this.tileProvider,
    super.key,
  });

  /// Supply rider updates from a WebSocket or another location stream.
  final Stream<LatLng>? riderLocationStream;
  final LatLng? initialRiderLocation;
  final LatLng? initialCustomerLocation;
  final TileProvider? tileProvider;

  @override
  State<LiveOrderMap> createState() => _LiveOrderMapState();
}

class _LiveOrderMapState extends State<LiveOrderMap> {
  static const _green = Color(0xFF006633);
  static const _mapFallback = LatLng(20.5937, 78.9629);

  final MapController _mapController = MapController();
  LatLng? _customerLocation;
  LatLng? _riderLocation;
  StreamSubscription<LatLng>? _riderSubscription;
  String? _locationMessage;
  String? _riderMessage;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _customerLocation = widget.initialCustomerLocation;
    _riderLocation = widget.initialRiderLocation;
    _listenForRiderUpdates();
    unawaited(_loadCustomerLocation());
  }

  @override
  void didUpdateWidget(covariant LiveOrderMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCustomerLocation != widget.initialCustomerLocation) {
      _customerLocation = widget.initialCustomerLocation;
      final customerLocation = _customerLocation;
      if (_mapReady && customerLocation != null) {
        _mapController.move(customerLocation, 14);
      }
      if (oldWidget.initialRiderLocation != widget.initialRiderLocation) {
        _riderLocation = widget.initialRiderLocation;
      }
    }
    if (oldWidget.riderLocationStream != widget.riderLocationStream) {
      unawaited(_riderSubscription?.cancel());
      _riderLocation = widget.initialRiderLocation;
      _listenForRiderUpdates();
    }
  }

  @override
  void dispose() {
    unawaited(_riderSubscription?.cancel());
    _mapController.dispose();
    super.dispose();
  }

  void _listenForRiderUpdates() {
    final stream = widget.riderLocationStream;
    if (stream == null) return;
    _riderSubscription = stream.listen(
      (location) {
        if (!mounted) return;
        setState(() {
          _riderLocation = location;
          _riderMessage = null;
        });
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _riderLocation = null;
          _riderMessage = 'Live rider location is unavailable.';
        });
      },
    );
  }

  Future<void> _loadCustomerLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationMessage('Turn on location services to show your location.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationMessage('Location permission was denied.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationMessage(
          'Allow location access in settings to show your location.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      final customerLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _customerLocation = customerLocation;
        _locationMessage = null;
      });
      if (_mapReady) _mapController.move(customerLocation, 14);
    } on LocationServiceDisabledException {
      _setLocationMessage('Turn on location services to show your location.');
    } on PermissionDeniedException {
      _setLocationMessage(
        'Location permission is required to show your location.',
      );
    } on TimeoutException {
      _setLocationMessage('Your location request timed out. Please try again.');
    } on PlatformException {
      _setLocationMessage('Your location is temporarily unavailable.');
    } on MissingPluginException {
      _setLocationMessage('Your location is temporarily unavailable.');
    }
  }

  void _setLocationMessage(String message) {
    if (!mounted) return;
    setState(() => _locationMessage = message);
  }

  void _centerOnRider(LatLng? riderLocation) {
    if (_mapReady && riderLocation != null) {
      _mapController.move(riderLocation, 15);
    }
  }

  void _onMapReady() {
    _mapReady = true;
    final customerLocation = _customerLocation;
    if (customerLocation != null) _mapController.move(customerLocation, 14);
  }

  @override
  Widget build(BuildContext context) {
    final riderLocation = _riderLocation;
    final customerLocation = _customerLocation;
    final center = customerLocation ?? _mapFallback;
    return SizedBox(
      height: 390,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: customerLocation == null ? 5 : 14,
                onMapReady: _onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.myshopzy.customer',
                  tileProvider: widget.tileProvider,
                ),
                if (riderLocation != null && customerLocation != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [riderLocation, customerLocation],
                        color: _green,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (customerLocation != null)
                      Marker(
                        point: customerLocation,
                        width: 52,
                        height: 52,
                        child: const _HomeMarker(),
                      ),
                    if (riderLocation != null)
                      Marker(
                        point: riderLocation,
                        width: 58,
                        height: 58,
                        child: const _RiderMarker(),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 14,
              left: 14,
              child: _MapStatus(
                message: riderLocation != null
                    ? 'Rider location live'
                    : 'Waiting for rider location',
                isLive: riderLocation != null,
              ),
            ),
            if (_locationMessage != null || _riderMessage != null)
              Positioned(
                left: 14,
                right: 72,
                bottom: 14,
                child: _LocationNotice(
                  message: _locationMessage ?? _riderMessage!,
                  onRetry: _locationMessage == null
                      ? null
                      : _loadCustomerLocation,
                ),
              ),
            Positioned(
              right: 14,
              bottom: 14,
              child: FloatingActionButton.small(
                tooltip: 'Center on rider',
                backgroundColor: Colors.white,
                foregroundColor: _green,
                elevation: 4,
                onPressed: riderLocation == null
                    ? null
                    : () => _centerOnRider(riderLocation),
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.home_rounded, color: _LiveOrderMapState._green),
    );
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _LiveOrderMapState._green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.two_wheeler_rounded,
        color: Color(0xFFFFC900),
        size: 31,
      ),
    );
  }
}

class _MapStatus extends StatelessWidget {
  const _MapStatus({required this.message, required this.isLive});

  final String message;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: isLive ? _LiveOrderMapState._green : Colors.grey,
            ),
            const SizedBox(width: 7),
            Text(
              message,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.only(left: 11, top: 5, bottom: 5, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 11)),
            ),
            if (onRetry != null)
              IconButton(
                tooltip: 'Retry location',
                visualDensity: VisualDensity.compact,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
