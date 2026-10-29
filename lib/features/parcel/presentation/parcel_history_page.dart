import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';

class ParcelHistoryPage extends StatefulWidget {
  const ParcelHistoryPage({super.key});

  @override
  State<ParcelHistoryPage> createState() => _ParcelHistoryPageState();
}

class _ParcelHistoryPageState extends State<ParcelHistoryPage> {
  static const _pageSize = 20;

  List<ApiParcelBooking> _bookings = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _paginationError;

  bool get _backendMode =>
      CustomerApi.instance.isConfigured &&
      CustomerApi.instance.hasCustomerSession;

  @override
  void initState() {
    super.initState();
    if (_backendMode) unawaited(_loadBookings());
  }

  Future<void> _loadBookings({bool loadMore = false}) async {
    if (_loading || _loadingMore || (loadMore && !_hasMore)) return;
    setState(() {
      if (loadMore) {
        _loadingMore = true;
        _paginationError = null;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final bookings = await CustomerApi.instance.getParcelBookings(
        limit: _pageSize,
        offset: loadMore ? _bookings.length : 0,
      );
      if (mounted) {
        setState(() {
          _bookings = loadMore ? [..._bookings, ...bookings] : bookings;
          _hasMore = bookings.length == _pageSize;
        });
      }
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _paginationError = error.message;
          } else {
            _bookings = const [];
            _error = error.message;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Parcel History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!CustomerApi.instance.canAccessCustomerFeatures) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Sign in to access your parcel history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.secondaryText, height: 1.4),
          ),
        ),
      );
    }
    if (!_backendMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            CustomerApi.instance.canAccessCustomerFeatures
                ? 'Parcel history appears after a real booking. Development preview does not create bookings.'
                : 'Parcel history is currently unavailable.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.secondaryText, height: 1.4),
          ),
        ),
      );
    }
    if (_loading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _loadBookings,
                child: const Text('Retry parcel history'),
              ),
            ],
          ),
        ),
      );
    }
    if (_bookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: AppTheme.secondaryText,
                size: 48,
              ),
              SizedBox(height: 14),
              Text(
                'No parcel requests yet',
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount:
          _bookings.length +
          (_hasMore || _loadingMore || _paginationError != null ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < _bookings.length) {
          return _buildBookingCard(_bookings[index]);
        }
        if (_loadingMore) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_paginationError != null) {
          return Column(
            children: [
              Text(
                _paginationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
              TextButton(
                onPressed: () => _loadBookings(loadMore: true),
                child: const Text('Retry loading parcels'),
              ),
            ],
          );
        }
        return Center(
          child: TextButton(
            onPressed: () => _loadBookings(loadMore: true),
            child: const Text('Load more parcel requests'),
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(ApiParcelBooking booking) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8EBE6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(booking.id),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.parcelType,
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${booking.weightKg} kg',
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${booking.pickupLocation} → ${booking.dropLocation}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Request record: ${booking.status}',
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                  fontSize: 11,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openDetails(booking.id),
                  child: const Text('View parcel details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(String bookingId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ParcelBookingDetailsPage(bookingId: bookingId),
      ),
    );
  }
}

class ParcelBookingDetailsPage extends StatefulWidget {
  const ParcelBookingDetailsPage({this.bookingId, this.booking, super.key})
    : assert(bookingId != null || booking != null);

  final String? bookingId;
  final ApiParcelBooking? booking;

  @override
  State<ParcelBookingDetailsPage> createState() =>
      _ParcelBookingDetailsPageState();
}

class _ParcelBookingDetailsPageState extends State<ParcelBookingDetailsPage> {
  ApiParcelBooking? _booking;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (widget.booking == null &&
        CustomerApi.instance.isConfigured &&
        CustomerApi.instance.hasCustomerSession) {
      unawaited(_loadDetails());
    }
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await CustomerApi.instance.getParcelBookingDetails(
        widget.bookingId!,
      );
      if (mounted) setState(() => _booking = booking);
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _booking = null;
          _error = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Parcel Request Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _loadDetails,
                child: const Text('Retry parcel details'),
              ),
            ],
          ),
        ),
      );
    }
    final booking = _booking;
    if (!CustomerApi.instance.hasCustomerSession) {
      return const Center(
        child: Text(
          'Sign in to access parcel details.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.secondaryText),
        ),
      );
    }
    if (booking == null) {
      return const Center(
        child: Text(
          'Parcel details are unavailable.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.secondaryText),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _detailCard('Parcel request', [
          _DetailRow('Booking ID', booking.id),
          _DetailRow('Request record', booking.status),
          _DetailRow('Created', booking.createdAt),
        ]),
        const SizedBox(height: 12),
        _detailCard('Route', [
          _DetailRow('Pickup', booking.pickupLocation),
          _DetailRow('Drop', booking.dropLocation),
        ]),
        const SizedBox(height: 12),
        _detailCard('Parcel details', [
          _DetailRow('Parcel type', booking.parcelType),
          _DetailRow('Weight', '${booking.weightKg} kg'),
          if (booking.instructions.isNotEmpty)
            _DetailRow('Instructions', booking.instructions),
        ]),
        const SizedBox(height: 12),
        const Text(
          'This record reflects a parcel request only. It does not indicate acceptance, dispatch, or delivery.',
          style: TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _detailCard(String title, List<_DetailRow> rows) {
    return Container(
      padding: const EdgeInsets.all(15),
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
              color: AppTheme.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    rows[index].label,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[index].value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}
