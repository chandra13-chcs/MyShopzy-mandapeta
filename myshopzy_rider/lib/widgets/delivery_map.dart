import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../constants/translations.dart';
import '../models/order.dart';
import '../services/rider_controller.dart';

class DeliveryMap extends StatefulWidget {
  final Order order;
  final bool headingToShop;
  final double height;
  final bool showRider;
  final bool interactive;
  final bool showRecenter;

  const DeliveryMap({
    super.key,
    required this.order,
    required this.headingToShop,
    this.height = 220,
    this.showRider = true,
    this.interactive = true,
    this.showRecenter = true,
  });

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgentPackageName = 'com.example.myshopzy_rider';

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _tilesFailed = false;
  String? _lastFitKey;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RiderController>();
    final riderPosition = widget.showRider ? controller.currentPosition : null;
    final shop = LatLng(widget.order.shopLat, widget.order.shopLng);
    final customer = LatLng(widget.order.customerLat, widget.order.customerLng);
    final nextStop = widget.headingToShop ? shop : customer;
    final rider = riderPosition == null
        ? null
        : LatLng(riderPosition.latitude, riderPosition.longitude);
    final cameraPoints = rider == null ? [shop, customer] : [rider, nextStop];
    final routePoints = !widget.showRider
        ? [shop, customer]
        : rider == null
            ? <LatLng>[]
            : [rider, nextStop];
    final fitKey = cameraPoints
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');
    _scheduleCameraFit(fitKey, cameraPoints);

    final theme = Theme.of(context);
    final distanceLabel = riderPosition == null
        ? null
        : T
            .t(widget.headingToShop ? 'km_to_shop' : 'km_to_customer')
            .replaceAll(
              '{distance}',
              (Geolocator.distanceBetween(
                        riderPosition.latitude,
                        riderPosition.longitude,
                        nextStop.latitude,
                        nextStop.longitude,
                      ) /
                      1000)
                  .toStringAsFixed(1),
            );

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: cameraPoints,
                  padding: const EdgeInsets.all(42),
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
                onMapReady: () {
                  _mapReady = true;
                  _fitCamera(cameraPoints);
                  _lastFitKey = fitKey;
                },
              ),
              children: [
                if (!_tilesFailed)
                  TileLayer(
                    urlTemplate: _tileUrl,
                    userAgentPackageName: _userAgentPackageName,
                    errorTileCallback: (_, __, ___) {
                      if (mounted && !_tilesFailed) {
                        setState(() => _tilesFailed = true);
                      }
                    },
                  ),
                if (routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (rider != null)
                      Marker(
                        point: rider,
                        width: 30,
                        height: 30,
                        child: const _RiderMarker(),
                      ),
                    Marker(
                      point: shop,
                      width: 42,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: _PlaceMarker(
                        color: Colors.deepOrange,
                        icon: widget.order.type == OrderType.food
                            ? Icons.store
                            : Icons.inventory_2,
                      ),
                    ),
                    Marker(
                      point: customer,
                      width: 42,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const _PlaceMarker(
                        color: Colors.green,
                        icon: Icons.home,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_tilesFailed)
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(225),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      T.t('map_offline'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            if (widget.showRecenter)
              Positioned(
                top: 8,
                right: 8,
                child: FloatingActionButton.extended(
                  heroTag: null,
                  tooltip: T.t('recenter'),
                  onPressed: () => _fitCamera(cameraPoints),
                  icon: const Icon(Icons.my_location),
                  label: Text(T.t('recenter')),
                ),
              ),
            if (distanceLabel != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(225),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child:
                        Text(distanceLabel, style: theme.textTheme.labelSmall),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(225),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    T.t('map_attribution'),
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleCameraFit(String fitKey, List<LatLng> points) {
    if (!_mapReady || fitKey == _lastFitKey) return;
    _lastFitKey = fitKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapReady) _fitCamera(points);
    });
  }

  void _fitCamera(List<LatLng> points) {
    if (!_mapReady) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(42),
      ),
    );
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(3),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _PlaceMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PlaceMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          Container(width: 3, height: 8, color: color),
        ],
      );
}
