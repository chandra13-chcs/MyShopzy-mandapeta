import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    required this.storeLocation,
    required this.customerLocation,
    required this.riderLocationStream,
    this.initialRiderLocation,
    super.key,
  });

  final LatLng storeLocation;
  final LatLng customerLocation;
  final Stream<LatLng> riderLocationStream;
  final LatLng? initialRiderLocation;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();

  LatLng get _mapCenter {
    final riderLocation = widget.initialRiderLocation;
    if (riderLocation != null) return riderLocation;
    return LatLng(
      (widget.storeLocation.latitude + widget.customerLocation.latitude) / 2,
      (widget.storeLocation.longitude + widget.customerLocation.longitude) / 2,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerOnRider(LatLng? riderLocation) {
    if (riderLocation != null) {
      _mapController.move(riderLocation, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live order tracking')),
      body: StreamBuilder<LatLng>(
        stream: widget.riderLocationStream,
        initialData: widget.initialRiderLocation,
        builder: (context, snapshot) {
          final riderLocation = snapshot.data;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _mapCenter, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.myshopzy.customer',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [widget.storeLocation, widget.customerLocation],
                        color: const Color(0xFF168A52),
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.storeLocation,
                        width: 52,
                        height: 64,
                        child: const _LocationMarker(
                          color: Color(0xFF087F4F),
                          icon: Icons.storefront_rounded,
                          label: 'Store',
                        ),
                      ),
                      Marker(
                        point: widget.customerLocation,
                        width: 52,
                        height: 64,
                        child: const _LocationMarker(
                          color: Color(0xFFFFB300),
                          icon: Icons.location_on_rounded,
                          label: 'Drop-off',
                        ),
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
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _LiveStatus(isLive: riderLocation != null),
              ),
              Positioned(
                right: 16,
                bottom: 20,
                child: FloatingActionButton(
                  tooltip: 'Center on rider',
                  onPressed: riderLocation == null
                      ? null
                      : () => _centerOnRider(riderLocation),
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
              if (snapshot.hasError)
                Positioned(
                  left: 16,
                  right: 76,
                  bottom: 24,
                  child: const _LocationErrorMessage(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              BoxShadow(color: Color(0x33000000), blurRadius: 5),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF168A52), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
      ),
      child: Image.asset(
        'assets/icons/bike.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.delivery_dining_rounded,
          color: Color(0xFF168A52),
          size: 31,
        ),
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 9,
              color: isLive ? const Color(0xFF168A52) : Colors.grey,
            ),
            const SizedBox(width: 7),
            Text(
              isLive ? 'Rider location live' : 'Waiting for rider location',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationErrorMessage extends StatelessWidget {
  const _LocationErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Live rider location is unavailable.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
