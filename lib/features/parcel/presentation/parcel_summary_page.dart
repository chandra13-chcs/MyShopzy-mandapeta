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
    super.key,
  });

  final String pickupLocation;
  final String dropLocation;
  final String parcelType;
  final String weight;
  final String instructions;

  @override
  State<ParcelSummaryPage> createState() => _ParcelSummaryPageState();
}

class _ParcelSummaryPageState extends State<ParcelSummaryPage> {
  static const _ink = AppTheme.primaryText;
  static const _green = AppTheme.primaryGreen;
  static const _page = AppTheme.lightBackground;

  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
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
                  _buildEstimate(),
                  if (!CustomerApi.instance.isConfigured) ...[
                    const SizedBox(height: 12),
                    _buildDemoNotice(),
                  ],
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
          _SummaryRow(label: 'Vehicle', value: 'Bike'),
          SizedBox(height: 11),
          _SummaryRow(label: 'Maximum service radius', value: '50 km'),
          SizedBox(height: 11),
          _SummaryRow(label: 'Maximum weight', value: '20 kg'),
        ],
      ),
    );
  }

  Widget _buildEstimate() {
    return Container(
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
              'Delivery charge will be calculated after location verification.',
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
          onPressed: _submitting ? null : _submitParcelRequest,
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
              : const Text('Submit Parcel Request'),
        ),
      ),
    );
  }

  Widget _buildDemoNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEED9A8)),
      ),
      child: const Text(
        'Demo mode · submitting here will not create a parcel request because the backend is not configured.',
        style: TextStyle(color: _ink, fontSize: 12, height: 1.4),
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

  Future<void> _submitParcelRequest() async {
    final api = CustomerApi.instance;
    if (!api.isConfigured) {
      setState(() {
        _error = 'Demo mode: parcel request was not submitted. Configure the backend to submit requests.';
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
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => ParcelBookingDetailsPage(bookingId: booking.id),
        ),
      );
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
