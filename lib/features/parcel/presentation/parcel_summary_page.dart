import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import 'parcel_history_page.dart';

class ParcelSummaryPage extends StatefulWidget {
  const ParcelSummaryPage({
    required this.pickupLocation,
    required this.dropLocation,
    required this.parcelType,
    required this.weight,
    required this.instructions,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupPincode,
    this.dropLatitude,
    this.dropLongitude,
    this.dropPincode,
    super.key,
  });

  final String pickupLocation;
  final String dropLocation;
  final String parcelType;
  final String weight;
  final String instructions;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupPincode;
  final double? dropLatitude;
  final double? dropLongitude;
  final String? dropPincode;

  @override
  State<ParcelSummaryPage> createState() => _ParcelSummaryPageState();
}

class _ParcelSummaryPageState extends State<ParcelSummaryPage> {
  static const _ink = AppTheme.primaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;

  bool _submitting = false;
  bool _outcomeUnknown = false;
  bool _checkingServiceability = false;
  String? _error;
  String? _postalCoverageMessage;

  @override
  void initState() {
    super.initState();
    _outcomeUnknown = CustomerApi.instance.parcelOutcomeUnknown;
    if (_hasLocationData && CustomerApi.instance.isConfigured) {
      _checkPostalCoverage();
    }
  }

  bool get _hasLocationData =>
      _hasRouteCoordinates &&
      widget.pickupPincode != null &&
      widget.dropPincode != null;

  bool get _hasRouteCoordinates =>
      widget.pickupLatitude != null &&
      widget.pickupLongitude != null &&
      widget.dropLatitude != null &&
      widget.dropLongitude != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: !CustomerApi.instance.hasCustomerSession
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Sign in to book a parcel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildErrorNotice(_error!),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 17, 16, 20),
                      children: [
                        _buildRouteSection(),
                        const SizedBox(height: 14),
                        _buildParcelDetails(),
                        const SizedBox(height: 14),
                        _buildDeliveryDetails(),
                        const SizedBox(height: 14),
                        _buildFareAndServiceability(),
                      ],
                    ),
                  ),
                  _buildBottomAction(context),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE8EBE6)),
              minimumSize: const Size(42, 42),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Parcel Summary',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return _SummarySection(
      title: 'Route',
      child: Column(
        children: [
          _RoutePoint(
            title: 'Pickup',
            location: widget.pickupLocation,
            icon: Icons.radio_button_checked_rounded,
            color: _green,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 18,
                width: 1,
                color: const Color(0xFFD9DED8),
              ),
            ),
          ),
          _RoutePoint(
            title: 'Drop',
            location: widget.dropLocation,
            icon: Icons.location_on_rounded,
            color: const Color(0xFFD16A53),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelDetails() {
    return _SummarySection(
      title: 'Parcel details',
      child: Column(
        children: [
          _SummaryRow(label: 'Parcel type', value: widget.parcelType),
          const SizedBox(height: 11),
          _SummaryRow(
            label: 'Weight',
            value: _displayValue(widget.weight, 'Not entered'),
          ),
          if (widget.instructions.isNotEmpty) ...[
            const SizedBox(height: 11),
            _SummaryRow(label: 'Instructions', value: widget.instructions),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    return _SummarySection(
      title: 'Delivery details',
      child: const Column(
        children: [
          _SummaryRow(label: 'Requested vehicle', value: 'Bike'),
          SizedBox(height: 11),
          _SummaryRow(
            label: 'Maximum route distance',
            value: '50 km (not verified by this API)',
          ),
          SizedBox(height: 11),
          _SummaryRow(label: 'Maximum weight', value: '20 kg'),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EBE6))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: _submitting
              ? null
              : _outcomeUnknown
              ? null
              : _submitParcelRequest,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _outcomeUnknown
                      ? 'Request status unknown'
                      : 'Submit Parcel Request',
                ),
        ),
      ),
    );
  }

  Widget _buildErrorNotice(String message) {
    return Container(
      key: const ValueKey('parcel-submit-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7C7C3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF914747), fontSize: 12),
      ),
    );
  }

  Widget _buildFareAndServiceability() {
    final coverageText = !_hasLocationData
        ? 'Postal-area coverage was not checked because postal codes are unavailable. The backend still verifies the road route when you submit.'
        : _checkingServiceability
        ? 'Checking whether both postal areas are listed for delivery...'
        : _postalCoverageMessage ??
              'Postal-area coverage has not been checked.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EA),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFD9E9DA)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _green, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'The backend calculates the charge from the road route when you submit. Its current rule is ₹25 for the first 2 km, then ₹10 per additional km (pro-rated); no price is quoted here.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('parcel-postal-coverage'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EBE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coverageText,
                style: const TextStyle(color: _ink, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 6),
              const Text(
                'This checks postal-area coverage only. Submission separately checks the road route for pricing, but the API does not enforce the 50 km limit.',
                style: TextStyle(
                  color: Color(0xFF727A74),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              if (!_hasRouteCoordinates) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('parcel-coordinates-required'),
                  child: _buildErrorNotice(
                    'Map locations are required for both pickup and drop. Choose saved addresses with coordinates; pickup can also use current location. Typed address text alone cannot be routed.',
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_outcomeUnknown) ...[
          const SizedBox(height: 10),
          _buildErrorNotice(
            'The request may have been received, but the response was not confirmed. Check parcel history before retrying, or contact support if the request is not listed.',
          ),
        ],
      ],
    );
  }

  Future<void> _checkPostalCoverage() async {
    if (!_hasLocationData || !CustomerApi.instance.isConfigured) return;
    setState(() {
      _checkingServiceability = true;
      _postalCoverageMessage = null;
    });
    try {
      final results = await Future.wait([
        CustomerApi.instance.checkLocationServiceability(
          widget.pickupLatitude!,
          widget.pickupLongitude!,
          widget.pickupPincode!,
        ),
        CustomerApi.instance.checkLocationServiceability(
          widget.dropLatitude!,
          widget.dropLongitude!,
          widget.dropPincode!,
        ),
      ]);
      if (!mounted) return;
      final bothListed = results.every((result) => result.isDeliverable);
      setState(() {
        _postalCoverageMessage = bothListed
            ? 'Both postal areas are listed for delivery.'
            : 'One or both postal areas are not listed for delivery.';
      });
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(
          () => _postalCoverageMessage =
              'Postal-area check unavailable: ${error.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _checkingServiceability = false);
    }
  }

  Future<void> _submitParcelRequest() async {
    final api = CustomerApi.instance;
    if (!api.hasCustomerSession) {
      setState(() => _error = 'Sign in to book a parcel.');
      return;
    }
    if (!api.isConfigured) {
      setState(() {
        _error = 'Parcel booking is unavailable because the service is not configured.';
      });
      return;
    }
    if (!_hasRouteCoordinates) {
      setState(() {
        _error = 'Choose pickup and drop locations with coordinates before submitting.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final booking = await api.createParcelBooking(
        ApiParcelBookingRequest(
          pickupLocation: widget.pickupLocation,
          dropLocation: widget.dropLocation,
          parcelType: widget.parcelType,
          weightKg: double.tryParse(widget.weight) ?? double.nan,
          instructions: widget.instructions,
          pickupLatitude: widget.pickupLatitude,
          pickupLongitude: widget.pickupLongitude,
          dropLatitude: widget.dropLatitude,
          dropLongitude: widget.dropLongitude,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => ParcelBookingDetailsPage(booking: booking),
        ),
      );
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _outcomeUnknown = api.parcelOutcomeUnknown;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _displayValue(String value, String fallback) {
    return value.isEmpty ? fallback : '$value kg';
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17251F),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.title,
    required this.location,
    required this.icon,
    required this.color,
  });

  final String title;
  final String location;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF727A74),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                location.isEmpty ? 'Not entered' : location,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17251F),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF727A74), fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF17251F),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
