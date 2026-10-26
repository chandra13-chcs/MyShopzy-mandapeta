import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/config/business_hours.dart';
import '../../../shared/data/customer_api.dart';
import '../../../shared/data/money_formatter.dart';
import '../../../shared/presentation/motion.dart';
import '../../cart/data/cart_store.dart';
import '../../coupons/models/demo_coupon.dart';
import '../../parcel/data/parcel_location_service.dart';
import '../../orders/models/order_record.dart';
import '../../orders/presentation/order_success_page.dart';
import '../../orders/presentation/order_tracking_page.dart';
import '../../profile/models/saved_address.dart';
import '../../profile/data/selected_delivery_address_store.dart';
import '../../profile/presentation/dues_page.dart';
import '../../profile/presentation/outstanding_dues_banner.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    this.openNewAddressOnLoad = false,
    this.onAddressSelected,
  });

  final bool openNewAddressOnLoad;
  final ValueChanged<CheckoutDeliveryAddress>? onAddressSelected;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static int _activeCheckoutPageCount = 0;

  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);

  // The backend checks the confirmed destination, not an inferred buyer GPS.
  static const _demoDeliveryChargeInPaise = 3000;
  final _cartStore = CartStore.instance;
  final _checkoutPlayer = AudioPlayer();
  bool _registeredAsActive = false;
  final _locationService = ParcelLocationService();
  ApiCartQuote? _backendQuote;
  String? _quoteError;
  bool _quoteLoading = false;
  int _quoteRequestGeneration = 0;
  int _outstandingMinor = 0;
  String? _blockingDueOrderId;
  String? _duesError;
  bool _duesLoading = false;
  bool _storeClosedByServer = false;
  bool _placingOrder = false;
  static const _storeClosedMessage =
      'Store is closed. Orders are accepted between '
      '${BusinessHours.openingLabel} and ${BusinessHours.closingLabel}.';
  final _couponCodeController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverMobileController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _receiverPincodeController = TextEditingController();
  final _receiverLatitudeController = TextEditingController();
  final _receiverLongitudeController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _customDeliveryInstructionController = TextEditingController();
  final _newAddressController = TextEditingController();
  final _newAddressPincodeController = TextEditingController();
  final _newAddressLatitudeController = TextEditingController();
  final _newAddressLongitudeController = TextEditingController();
  final _newAddressLandmarkController = TextEditingController();
  List<CheckoutDeliveryAddress> _savedAddresses = [];
  bool _savedAddressesLoading = false;
  String? _savedAddressesError;
  CheckoutDeliveryAddress? _confirmedDeliveryAddress;
  bool _someoneElseSelected = false;
  String _newAddressType = 'Other';
  String _selectedPaymentMethod = 'Cash on Delivery';
  DemoCoupon? _selectedCoupon;
  String? _couponMessage;
  bool _couponMessageIsError = false;
  String? _selectedQuickInstruction;

  static const _quickDeliveryInstructions = [
    'Leave at the door',
    'Call me on arrival',
    'Hand it to me',
  ];

  String? get _deliveryInstruction {
    final customInstruction = _customDeliveryInstructionController.text.trim();
    final parts = [
      ?_selectedQuickInstruction,
      if (customInstruction.isNotEmpty) customInstruction,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  bool get _isBackendCart =>
      CustomerApi.instance.isConfigured &&
      CustomerApi.instance.hasCustomerSession &&
      _cartStore.hasBackendCart;

  bool get _hasPlaceableAddress {
    final address = _confirmedDeliveryAddress?.formattedAddress.trim();
    return address != null &&
        address.isNotEmpty &&
        address.toLowerCase() != 'choose your location';
  }

  int get _subtotalInPaise => _isBackendCart && _backendQuote != null
      ? _backendQuote!.itemSubtotalMinor
      : _isBackendCart
      ? 0
      : _cartStore.subtotalInPaise;

  int get _discountInPaise {
    if (_isBackendCart) return _backendQuote?.discountMinor ?? 0;
    final coupon = _selectedCoupon;
    if (coupon == null) return 0;
    return coupon.discountFor(_subtotalInPaise);
  }

  int get _deliveryChargeInPaise => _isBackendCart
      ? _backendQuote?.deliveryFeeMinor ?? 0
      : _cartStore.items.isEmpty
      ? 0
      : _demoDeliveryChargeInPaise;

  int get _totalInPaise => _isBackendCart
      ? _backendQuote?.totalMinor ?? 0
      : DemoCouponValidator.payableTotal(
          subtotalInPaise: _subtotalInPaise,
          deliveryFeeInPaise: _deliveryChargeInPaise,
          coupon: _selectedCoupon,
        );

  @override
  void initState() {
    super.initState();
    _registerActiveCheckoutPage();
    final selectedAddress =
        SelectedDeliveryAddressStore.instance.selectedAddress;
    if (selectedAddress != null &&
        selectedAddress.address.trim().isNotEmpty &&
        selectedAddress.address.toLowerCase().trim() !=
            'choose your location') {
      _confirmedDeliveryAddress = CheckoutDeliveryAddress(
        id: selectedAddress.id,
        addressType: selectedAddress.label,
        formattedAddress: selectedAddress.address,
        latitude: selectedAddress.latitude,
        longitude: selectedAddress.longitude,
        pincode: selectedAddress.pincode,
        receiverName: selectedAddress.receiverName,
        receiverMobile: selectedAddress.receiverMobile,
        landmark: selectedAddress.landmark,
        isBackendData: selectedAddress.isBackendData,
      );
    }
    _cartStore.addListener(_handleCartChanged);
    if (CustomerApi.instance.hasCustomerSession) {
      _savedAddressesLoading = true;
      Future<void>.delayed(Duration.zero, _loadSavedAddresses);
    }
    if (CustomerApi.instance.hasCustomerSession) {
      Future<void>.delayed(Duration.zero, _refreshDues);
    }
    if (_confirmedDeliveryAddress != null && _isBackendCart) {
      Future<void>.delayed(
        Duration.zero,
        () => _refreshBackendQuote(_confirmedDeliveryAddress),
      );
    }
    if (widget.openNewAddressOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNewAddressForm();
      });
    }
  }

  Future<void> _loadSavedAddresses() async {
    if (!mounted) return;
    setState(() {
      _savedAddressesLoading = true;
      _savedAddressesError = null;
    });
    try {
      final addresses = await CustomerApi.instance.getSavedAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses
            .map(
              (address) => CheckoutDeliveryAddress(
                id: address.id,
                addressType: address.label,
                formattedAddress: address.formattedAddress,
                isBackendData: true,
                latitude: address.latitude,
                longitude: address.longitude,
                pincode: address.pincode,
              ),
            )
            .toList(growable: false);
      });
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _savedAddressesError = error.message);
    } finally {
      if (mounted) setState(() => _savedAddressesLoading = false);
    }
  }

  Future<void> _refreshDues() async {
    if (!CustomerApi.instance.hasCustomerSession) return;
    if (!mounted) return;
    setState(() {
      _duesLoading = true;
      _duesError = null;
    });
    try {
      final dues = await CustomerApi.instance.getDues();
      if (!mounted) return;
      ApiDueEntry? blockingDue;
      for (final entry in dues.entries) {
        if (entry.status == 'confirmed' && entry.amountMinor > 0) {
          blockingDue = entry;
          break;
        }
      }
      setState(() {
        _outstandingMinor = dues.outstandingMinor;
        _blockingDueOrderId = blockingDue?.orderId;
      });
    } on CustomerApiException catch (error) {
      if (mounted) setState(() => _duesError = error.message);
    } finally {
      if (mounted) setState(() => _duesLoading = false);
    }
  }

  @override
  void dispose() {
    _unregisterActiveCheckoutPage();
    _cartStore.removeListener(_handleCartChanged);
    _couponCodeController.dispose();
    _receiverNameController.dispose();
    _receiverMobileController.dispose();
    _deliveryAddressController.dispose();
    _receiverPincodeController.dispose();
    _receiverLatitudeController.dispose();
    _receiverLongitudeController.dispose();
    _landmarkController.dispose();
    _customDeliveryInstructionController.dispose();
    _newAddressController.dispose();
    _newAddressPincodeController.dispose();
    _newAddressLatitudeController.dispose();
    _newAddressLongitudeController.dispose();
    _newAddressLandmarkController.dispose();
    unawaited(_checkoutPlayer.dispose());
    super.dispose();
  }

  void _registerActiveCheckoutPage() {
    if (_registeredAsActive) return;
    _registeredAsActive = true;
    if (_activeCheckoutPageCount++ == 0) unawaited(_playCheckoutSound());
  }

  void _unregisterActiveCheckoutPage() {
    if (!_registeredAsActive) return;
    _registeredAsActive = false;
    _activeCheckoutPageCount--;
  }

  Future<void> _playCheckoutSound() async {
    try {
      await _checkoutPlayer.play(AssetSource('audio/checkout and payment.mp3'));
    } catch (error) {
      debugPrint('Checkout sound playback failed: $error');
    }
  }

  void _handleCartChanged() {
    _quoteRequestGeneration++;
    if (_isBackendCart) {
      unawaited(_refreshBackendQuote());
    } else if (_cartStore.items.isEmpty) {
      _backendQuote = null;
      _quoteError = null;
    }
    final coupon = _selectedCoupon;
    if (!mounted ||
        coupon == null ||
        _subtotalInPaise >= coupon.minimumOrderInPaise) {
      return;
    }
    final shortBy = coupon.minimumOrderInPaise - _subtotalInPaise;
    setState(() {
      _selectedCoupon = null;
      _couponMessage = 'Add ${_formatPrice(shortBy)} more to use this coupon.';
      _couponMessageIsError = true;
    });
  }

  String _quoteAddressKey(CheckoutDeliveryAddress address) => [
    address.id,
    address.formattedAddress,
    address.pincode ?? '',
    address.latitude?.toString() ?? '',
    address.longitude?.toString() ?? '',
  ].join('|');

  void _clearBackendQuote() {
    _quoteRequestGeneration++;
    _backendQuote = null;
    _quoteError = null;
    _quoteLoading = false;
  }

  Future<void> _refreshBackendQuote([
    CheckoutDeliveryAddress? selectedAddress,
  ]) async {
    if (!mounted || !_isBackendCart) return;
    final requestGeneration = ++_quoteRequestGeneration;
    final address = selectedAddress ?? _confirmedDeliveryAddress;
    final key = address == null ? null : _quoteAddressKey(address);
    if (address == null ||
        address.latitude == null ||
        address.longitude == null ||
        address.pincode == null ||
        address.pincode!.trim().isEmpty) {
      setState(() {
        _backendQuote = null;
        _quoteLoading = false;
        _quoteError = address == null ? null : 'This address needs a valid pincode and map coordinates to calculate delivery.';
      });
      return;
    }
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
      _backendQuote = null;
    });
    try {
      final quote = await CustomerApi.instance.getCheckoutQuote(
        formattedAddress: address.formattedAddress,
        pincode: address.pincode!,
        latitude: address.latitude!,
        longitude: address.longitude!,
      );
      if (!mounted ||
          requestGeneration != _quoteRequestGeneration ||
          _confirmedDeliveryAddress == null ||
          _quoteAddressKey(_confirmedDeliveryAddress!) != key) {
        return;
      }
      setState(() {
        _backendQuote = quote;
        _storeClosedByServer = !quote.storeOpen;
        _quoteLoading = false;
      });
    } on CustomerApiException catch (error) {
      if (!mounted ||
          requestGeneration != _quoteRequestGeneration ||
          _confirmedDeliveryAddress == null ||
          _quoteAddressKey(_confirmedDeliveryAddress!) != key) {
        return;
      }
      setState(() {
        _backendQuote = null;
        _quoteError = error.message;
        if (error.code == 'OUTSTANDING_DUES') {
          _outstandingMinor = error.outstandingMinor ?? _outstandingMinor;
        }
        _quoteLoading = false;
      });
      if (error.code == 'OUTSTANDING_DUES') unawaited(_refreshDues());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: !CustomerApi.instance.canAccessCustomerFeatures
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Sign in to access checkout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _secondaryText),
                ),
              ),
            )
          : !_cartStore.hasBackendCart
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Checkout is unavailable until customer cart ownership is supported.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _secondaryText),
                ),
              ),
            )
          : SafeArea(
              child: AnimatedBuilder(
                animation: _cartStore,
                builder: (context, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isBackendCart &&
                            (_storeClosedByServer ||
                                _backendQuote?.storeOpen == false)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF2D4A8),
                              ),
                            ),
                            child: const Text(
                              _storeClosedMessage,
                              style: TextStyle(
                                color: Color(0xFF805000),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_outstandingMinor > 0) ...[
                          OutstandingDuesBanner(
                            amountMinor: _outstandingMinor,
                            orderId: _blockingDueOrderId,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => const DuesPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else if (_duesLoading) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        ] else if (_duesError != null &&
                            _quoteError == null) ...[
                          Text(
                            _duesError!,
                            style: const TextStyle(
                              color: Color(0xFFA85B5B),
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: _refreshDues,
                            child: const Text('Retry dues'),
                          ),
                        ],
                        if (_cartStore.items.isEmpty) ...[
                          _buildEmptyCartState(context),
                          const SizedBox(height: 16),
                        ],
                        _buildDeliverySection(),
                        if (_isBackendCart &&
                            _backendQuote?.isDeliverable == false) ...[
                          Container(
                            key: const ValueKey(
                              'checkout-delivery-unavailable',
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFD9A8),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Sorry! We don't deliver here yet",
                                    style: TextStyle(
                                      color: _mainText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showDeliveryOptions,
                                  child: const Text('Change Location'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 16),
                        _buildDeliveryInstructionsSection(),
                        const SizedBox(height: 16),
                        _buildOrderSummary(),
                        const SizedBox(height: 16),
                        _buildCouponSection(),
                        const SizedBox(height: 16),
                        _buildPaymentSection(),
                        const SizedBox(height: 16),
                        _buildPriceDetails(),
                        const SizedBox(height: 12),
                        Text(
                          _isBackendCart
                              ? _quoteError ??
                                    (_quoteLoading
                                        ? 'Refreshing server checkout quote…'
                                        : _backendQuote?.isDeliverable == false
                                        ? 'Choose a different delivery location to continue.'
                                        : _backendQuote?.message ??
                                              'Select a delivery address to get a server quote.')
                              : 'Sign in to get a checkout quote.',
                          style: TextStyle(
                            color: _quoteError == null
                                ? _secondaryText
                                : const Color(0xFFA85B5B),
                            fontSize: 11,
                          ),
                        ),
                        if (_isBackendCart && _quoteError != null)
                          TextButton(
                            onPressed: _quoteLoading
                                ? null
                                : () => unawaited(_refreshBackendQuote()),
                            child: const Text('Retry quote'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: !CustomerApi.instance.canAccessCustomerFeatures
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: _cartStore,
              builder: (context, child) {
                final hasItems = _cartStore.items.isNotEmpty;
                final hasConfirmedAddress = _hasPlaceableAddress;
                final orderOutcomeUnknown =
                    _isBackendCart && CustomerApi.instance.orderOutcomeUnknown;
                final canPlaceOrder =
                    _isBackendCart &&
                    hasItems &&
                    hasConfirmedAddress &&
                    (!_isBackendCart ||
                        (_backendQuote != null &&
                            _backendQuote!.isDeliverable &&
                            _backendQuote!.totalMinor != null)) &&
                    (!_isBackendCart || _backendQuote?.storeOpen != false) &&
                    _outstandingMinor <= 0 &&
                    !_storeClosedByServer &&
                    (!_isBackendCart ||
                        (!_quoteLoading && _quoteError == null)) &&
                    !_placingOrder &&
                    !orderOutcomeUnknown;
                if (!hasItems) return const SizedBox.shrink();
                return SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasConfirmedAddress)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Select or enter a complete delivery address to continue.',
                              key: ValueKey('checkout-address-validation'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (orderOutcomeUnknown)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Order status is unknown. Your cart has been kept. '
                              'Do not submit again until you have checked with '
                              'customer support.',
                              key: ValueKey('checkout-order-outcome-unknown'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFA85B5B),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canPlaceOrder ? _placeOrder : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _border,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _placingOrder
                                  ? 'Submitting…'
                                  : orderOutcomeUnknown
                                  ? 'Order Status Unknown'
                                  : 'Place Order',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyCartState(BuildContext context) {
    return Container(
      key: const ValueKey('checkout-empty-cart-title'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shopping_cart_outlined, color: _green, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your cart is empty',
                  style: TextStyle(
                    color: _mainText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add items before placing an order.',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Return to Cart'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return _sectionCard(
      title: 'Delivery Location',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: _green, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: _confirmedDeliveryAddress == null
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select delivery location',
                              style: TextStyle(
                                color: _mainText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Choose where this order should be delivered.',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivering to',
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _confirmedDeliveryAddress!.addressType,
                              style: const TextStyle(
                                color: _mainText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _confirmedDeliveryAddress!.formattedAddress,
                              style: const TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            if (!_hasPlaceableAddress) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'GPS did not resolve a postal address. Enter one to continue.',
                                style: TextStyle(
                                  color: _secondaryText,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (_confirmedDeliveryAddress!.receiverName !=
                                null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Receiver: '
                                '${_confirmedDeliveryAddress!.receiverName}',
                                style: const TextStyle(
                                  color: _secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                TextButton(
                  onPressed: _showDeliveryOptions,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          if (_someoneElseSelected) ...[
            const SizedBox(height: 12),
            _buildAddressForm(
              nameController: _receiverNameController,
              mobileController: _receiverMobileController,
              addressController: _deliveryAddressController,
              landmarkController: _landmarkController,
              pincodeController: _receiverPincodeController,
              latitudeController: _receiverLatitudeController,
              longitudeController: _receiverLongitudeController,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _deliveryAddressController.text.trim().isEmpty
                    ? null
                    : _confirmSomeoneElseAddress,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Delivery Address'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showNewAddressForm,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('+ Add New Address'),
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInstructionsSection() {
    final hasInstructions =
        _selectedQuickInstruction != null ||
        _customDeliveryInstructionController.text.trim().isNotEmpty;
    final instruction = _deliveryInstruction;
    return _sectionCard(
      title: 'Delivery Instructions',
      icon: Icons.edit_note_rounded,
      trailing: hasInstructions
          ? TextButton(
              onPressed: _clearDeliveryInstructions,
              child: const Text('Clear'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose one optional instruction',
            style: TextStyle(color: _secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 4,
            children: [
              for (final option in _quickDeliveryInstructions)
                ChoiceChip(
                  label: Text(option),
                  selected: _selectedQuickInstruction == option,
                  onSelected: (selected) {
                    setState(() {
                      _selectedQuickInstruction = selected ? option : null;
                    });
                  },
                  selectedColor: _lightGreen,
                  labelStyle: TextStyle(
                    color: _selectedQuickInstruction == option
                        ? _green
                        : _mainText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: _selectedQuickInstruction == option
                        ? _green
                        : _border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            key: const ValueKey('custom-delivery-instructions'),
            controller: _customDeliveryInstructionController,
            maxLength: 200,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Custom instructions (optional)',
              hintStyle: const TextStyle(color: _secondaryText, fontSize: 12),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green),
              ),
            ),
          ),
          if (instruction != null)
            Text(
              instruction,
              key: const ValueKey('delivery-instruction-preview'),
              style: const TextStyle(
                color: _secondaryText,
                fontSize: 11,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }

  void _clearDeliveryInstructions() {
    setState(() {
      _selectedQuickInstruction = null;
      _customDeliveryInstructionController.clear();
    });
  }

  Future<void> _showDeliveryOptions() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Delivery Location',
                style: TextStyle(
                  color: _mainText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _deliveryOptionTile(
                icon: Icons.my_location_outlined,
                title: 'Use Current Location',
                subtitle: 'Use your current location; enter an address if one is not resolved',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_useCurrentLocation(requestPermission: true));
                },
              ),
              const Padding(
                padding: EdgeInsets.only(left: 48, bottom: 8),
                child: Text(
                  'We use your device location and address details to price the order.',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 5),
                child: Text(
                  'Saved Addresses',
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_savedAddressesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_savedAddressesError != null) ...[
                Text(
                  _savedAddressesError!,
                  style: const TextStyle(
                    color: Color(0xFFA85B5B),
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: _savedAddressesLoading
                      ? null
                      : _loadSavedAddresses,
                  child: const Text('Retry addresses'),
                ),
              ],
              if (!_savedAddressesLoading &&
                  _savedAddressesError == null &&
                  _savedAddresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No saved addresses.',
                    style: TextStyle(color: _secondaryText, fontSize: 12),
                  ),
                ),
              for (final address in _savedAddresses)
                _deliveryOptionTile(
                  icon: _addressIcon(address.addressType),
                  title: address.addressType,
                  subtitle: address.formattedAddress,
                  onTap: () {
                    _confirmAddress(address);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              _deliveryOptionTile(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Deliver to Someone Else',
                subtitle: 'Enter receiver and delivery details',
                onTap: () {
                  setState(() {
                    _clearBackendQuote();
                    _confirmedDeliveryAddress = null;
                    _someoneElseSelected = true;
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation({bool requestPermission = false}) async {
    try {
      final location = await _locationService.detectCurrentLocation(
        requestPermission: requestPermission,
      );
      if (!mounted) return;
      final address = CheckoutDeliveryAddress(
        id: 'current-location',
        addressType: 'Current location',
        formattedAddress: location.address,
        latitude: location.latitude,
        longitude: location.longitude,
        pincode: location.pincode,
      );
      _confirmAddress(address);
    } on ParcelLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _clearBackendQuote();
        _someoneElseSelected = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location is unavailable right now. $error')),
      );
    }
  }

  Widget _deliveryOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _green),
        title: Text(
          title,
          style: const TextStyle(
            color: _mainText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: _secondaryText, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: _green),
      ),
    );
  }

  Widget _buildAddressForm({
    required TextEditingController nameController,
    required TextEditingController mobileController,
    required TextEditingController addressController,
    required TextEditingController landmarkController,
    required TextEditingController pincodeController,
    required TextEditingController latitudeController,
    required TextEditingController longitudeController,
  }) {
    return Column(
      children: [
        _addressField(nameController, 'Receiver Name'),
        const SizedBox(height: 9),
        _addressField(
          mobileController,
          'Receiver Mobile Number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 9),
        _addressField(addressController, 'Delivery Address', maxLines: 2),
        if (CustomerApi.instance.isConfigured) ...[
          const SizedBox(height: 9),
          _addressField(
            pincodeController,
            '6-digit Pincode',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 9),
          _addressField(
            latitudeController,
            'Latitude',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          const SizedBox(height: 9),
          _addressField(
            longitudeController,
            'Longitude',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
        ],
        const SizedBox(height: 9),
        _addressField(landmarkController, 'Landmark (optional)'),
      ],
    );
  }

  Future<void> _showNewAddressForm() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Address',
                    style: TextStyle(
                      color: _mainText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _newAddressType,
                    decoration: InputDecoration(
                      labelText: 'Address Type',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Work', child: Text('Work')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _newAddressType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _addressField(
                    _newAddressController,
                    'Full Address',
                    maxLines: 2,
                    onChanged: () => setSheetState(() {}),
                  ),
                  if (CustomerApi.instance.isConfigured) ...[
                    const SizedBox(height: 10),
                    _addressField(
                      _newAddressPincodeController,
                      '6-digit Pincode',
                      keyboardType: TextInputType.number,
                      onChanged: () => setSheetState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _addressField(
                      _newAddressLatitudeController,
                      'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: () => setSheetState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _addressField(
                      _newAddressLongitudeController,
                      'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: () => setSheetState(() {}),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _addressField(
                    _newAddressLandmarkController,
                    'Landmark (optional)',
                    onChanged: () => setSheetState(() {}),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _newAddressController.text.trim().isEmpty
                          ? null
                          : () {
                              _saveNewAddress();
                              Navigator.of(sheetContext).pop();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save and Deliver Here'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _newAddressController.clear();
      _newAddressPincodeController.clear();
      _newAddressLatitudeController.clear();
      _newAddressLongitudeController.clear();
      _newAddressLandmarkController.clear();
      _newAddressType = 'Other';
    });
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) {
        setState(() {});
        onChanged?.call();
      },
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final items = _cartStore.items;
    return _sectionCard(
      title: 'Order Summary',
      icon: Icons.shopping_bag_outlined,
      trailing: Text(
        '${items.length} ${items.length == 1 ? 'item' : 'items'}',
        style: const TextStyle(color: _secondaryText, fontSize: 12),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Your cart is empty.',
                style: TextStyle(color: _secondaryText, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _buildCartItem(items[index]),
                  if (index < items.length - 1)
                    const Divider(height: 20, color: _border),
                ],
                const Divider(height: 22, color: _border),
                _priceRow(
                  'Merchandise Subtotal',
                  _displayPrice(
                    _isBackendCart
                        ? _backendQuote?.itemSubtotalMinor
                        : _subtotalInPaise,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    ApiCartQuoteItem? quoteItem;
    if (_isBackendCart && _backendQuote != null) {
      for (final quoted in _backendQuote!.items) {
        if (quoted.productId == item.productId &&
            quoted.variantId == item.productVariantId) {
          quoteItem = quoted;
          break;
        }
      }
    }
    final quantity = quoteItem?.quantity ?? item.quantity;
    final priceMinor = quoteItem?.priceMinor ?? item.priceInPaise;
    final lineTotalMinor =
        quoteItem?.lineTotalMinor ?? item.priceInPaise * item.quantity;
    final variantLabel = quoteItem?.variantLabel ?? item.variantLabel;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: _green, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quoteItem?.name ?? item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mainText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (variantLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  variantLabel,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                _isBackendCart && quoteItem == null
                    ? (_quoteLoading
                          ? 'Refreshing server price…'
                          : 'Server price unavailable')
                    : 'Qty $quantity · ${_formatPrice(priceMinor)} each',
                style: const TextStyle(color: _secondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _isBackendCart && quoteItem == null
              ? '—'
              : _formatPrice(lineTotalMinor),
          style: const TextStyle(
            color: _mainText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCouponSection() {
    return _sectionCard(
      title: 'Apply Coupon',
      icon: Icons.local_offer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCoupon != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: _green, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCoupon!.code,
                        key: const ValueKey('applied-coupon-code'),
                        style: const TextStyle(
                          color: _mainText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Discount ${_formatPrice(_discountInPaise)} · demo',
                        style: const TextStyle(color: _green, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _removeCoupon,
                  child: const Text('Remove'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('coupon-code-field'),
                  controller: _couponCodeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _applyCoupon(),
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _green),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              FilledButton(
                key: const ValueKey('apply-coupon-button'),
                onPressed: _applyCoupon,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _showCouponPicker,
              style: TextButton.styleFrom(
                foregroundColor: _green,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const Text('View demo coupons'),
            ),
          ),
          if (_couponMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _couponMessage!,
                key: const ValueKey('coupon-validation-message'),
                style: TextStyle(
                  color: _couponMessageIsError
                      ? const Color(0xFFA85B5B)
                      : _green,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _applyCoupon() {
    if (_isBackendCart) {
      setState(() {
        _couponMessage =
            'Demo coupons are not included in the backend checkout quote.';
        _couponMessageIsError = true;
        _selectedCoupon = null;
      });
      return;
    }
    final result = DemoCouponValidator.validate(
      code: _couponCodeController.text,
      subtotalInPaise: _subtotalInPaise,
      hasCartItems: _cartStore.items.isNotEmpty,
      appliedCouponCode: _selectedCoupon?.code,
    );
    if (!result.isValid) {
      final message = switch (result.status) {
        CouponValidationStatus.invalidCode => 'Coupon code is not valid.',
        CouponValidationStatus.expired => 'This coupon has expired.',
        CouponValidationStatus.minimumOrderNotMet =>
          'Add ${_formatPrice(result.amountShortInPaise)} more to use this coupon.',
        CouponValidationStatus.cartNotEligible =>
          'Add items to your cart to use this coupon.',
        CouponValidationStatus.alreadyApplied =>
          'This coupon is already applied.',
        CouponValidationStatus.anotherCouponAlreadyApplied =>
          'Remove the applied coupon before using another.',
        CouponValidationStatus.valid => 'Coupon applied successfully.',
      };
      setState(() {
        _couponMessage = message;
        _couponMessageIsError = true;
      });
      return;
    }

    setState(() {
      _selectedCoupon = result.coupon;
      _couponMessage = 'Coupon applied successfully.';
      _couponMessageIsError = false;
    });
  }

  void _removeCoupon() {
    setState(() {
      _selectedCoupon = null;
      _couponMessage = null;
      _couponMessageIsError = false;
      _couponCodeController.clear();
    });
  }

  Widget _buildPaymentSection() {
    return _sectionCard(
      title: 'Payment Method',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        children: [
          _paymentOption(
            title: 'UPI',
            status: 'Unavailable',
            icon: Icons.account_balance_wallet_outlined,
            selected: false,
            enabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _paymentOption(
            title: 'Cash on Delivery',
            status: 'Available',
            icon: Icons.payments_outlined,
            selected: _selectedPaymentMethod == 'Cash on Delivery',
            onTap: () =>
                setState(() => _selectedPaymentMethod = 'Cash on Delivery'),
          ),
          const SizedBox(height: 8),
          _paymentOption(
            title: 'Credit/Debit Card',
            status: 'Coming soon',
            icon: Icons.credit_card_outlined,
            selected: false,
            enabled: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String title,
    required String status,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final textColor = enabled ? _mainText : _secondaryText;
    return Material(
      color: selected ? _lightGreen : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? _green : _border),
          ),
          child: Row(
            children: [
              Icon(icon, color: enabled ? _green : _secondaryText, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: enabled ? _green : _secondaryText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? _green : _secondaryText,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDetails() {
    return _sectionCard(
      title: 'Price Details',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _priceRow(
            'Merchandise Subtotal',
            _displayPrice(
              _isBackendCart
                  ? _backendQuote?.itemSubtotalMinor
                  : _subtotalInPaise,
            ),
          ),
          const SizedBox(height: 10),
          _priceRow(
            'Delivery Distance',
            _isBackendCart
                ? _backendQuote?.distanceMeters == null
                      ? _displayPrice(null)
                      : '${(_backendQuote!.distanceMeters! / 1000).toStringAsFixed(2)} km'
                : '—',
          ),
          const SizedBox(height: 10),
          _priceRow(
            'Delivery Charge',
            _displayPrice(
              _isBackendCart
                  ? _backendQuote?.deliveryFeeMinor
                  : _deliveryChargeInPaise,
            ),
          ),
          const SizedBox(height: 10),
          _priceRow(
            'Platform Fee',
            _isBackendCart
                ? _displayPrice(_backendQuote?.platformFeeMinor)
                : '—',
            valueKey: const ValueKey('checkout-platform-fee-value'),
          ),
          const SizedBox(height: 10),
          _priceRow(
            'Discount',
            _isBackendCart && _backendQuote == null
                ? _displayPrice(null)
                : '−${_formatPrice(_discountInPaise)}',
            valueColor: _green,
            valueKey: const ValueKey('coupon-discount-value'),
          ),
          const Divider(height: 24, color: _border),
          _priceRow(
            'Total',
            _displayPrice(
              _isBackendCart ? _backendQuote?.totalMinor : _totalInPaise,
            ),
            emphasize: true,
            valueKey: const ValueKey('checkout-total-value'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isBackendCart
                  ? 'Prices and charges are calculated by the server for the selected location.'
                  : 'Delivery charge is a demo value; serviceability and final '
                        'pricing are not checked here.',
              style: const TextStyle(
                color: _secondaryText,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _green, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
    Key? valueKey,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _mainText : _secondaryText,
              fontSize: emphasize ? 14 : 12,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            color: valueColor ?? (emphasize ? _mainText : _secondaryText),
            fontSize: emphasize ? 14 : 12,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Future<void> _showCouponPicker() async {
    final coupon = await showModalBottomSheet<DemoCoupon>(
      context: context,
      backgroundColor: _background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Coupons',
                style: TextStyle(
                  color: _mainText,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final option in demoCoupons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.local_offer_outlined,
                    color: _green,
                  ),
                  title: Text(
                    option.code,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    option.discountInPaise != null
                        ? 'Save ${_formatPrice(option.discountInPaise!)} · demo'
                        : 'Save ${option.discountPercent}% · demo',
                  ),
                  trailing: const Icon(Icons.add_circle_outline, color: _green),
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (coupon != null && mounted) {
      setState(() {
        _couponCodeController.text = coupon.code;
        _couponMessage = null;
        _couponMessageIsError = false;
      });
      _applyCoupon();
    }
  }

  void _confirmSomeoneElseAddress() {
    final formattedAddress = _deliveryAddressController.text.trim();
    if (formattedAddress.isEmpty) return;
    _confirmAddress(
      CheckoutDeliveryAddress(
        id: 'someone-else',
        addressType: 'Someone else',
        formattedAddress: formattedAddress,
        receiverName: _receiverNameController.text.trim(),
        receiverMobile: _receiverMobileController.text.trim(),
        pincode: _receiverPincodeController.text.trim(),
        latitude: double.tryParse(_receiverLatitudeController.text.trim()),
        longitude: double.tryParse(_receiverLongitudeController.text.trim()),
        landmark: _landmarkController.text.trim(),
      ),
    );
  }

  void _saveNewAddress() {
    final address = CheckoutDeliveryAddress(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      addressType: _newAddressType,
      formattedAddress: _newAddressController.text.trim(),
      pincode: _newAddressPincodeController.text.trim(),
      latitude: double.tryParse(_newAddressLatitudeController.text.trim()),
      longitude: double.tryParse(_newAddressLongitudeController.text.trim()),
      landmark: _newAddressLandmarkController.text.trim(),
    );
    _confirmAddress(address);
  }

  void _confirmAddress(CheckoutDeliveryAddress address) {
    setState(() {
      _clearBackendQuote();
      _confirmedDeliveryAddress = address;
      _someoneElseSelected = false;
    });
    SelectedDeliveryAddressStore.instance.select(
      SavedAddress(
        id: address.id,
        label: address.addressType,
        address: address.formattedAddress,
        icon: _addressIcon(address.addressType),
        isBackendData: address.isBackendData,
        latitude: address.latitude,
        longitude: address.longitude,
        pincode: address.pincode,
        receiverName: address.receiverName,
        receiverMobile: address.receiverMobile,
        landmark: address.landmark,
      ),
    );
    widget.onAddressSelected?.call(address);
    unawaited(_refreshBackendQuote(address));
  }

  Future<void> _placeOrder() async {
    if (!CustomerApi.instance.hasCustomerSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to place an order.')),
      );
      return;
    }
    if (!CustomerApi.instance.isConfigured || !_cartStore.hasBackendCart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Checkout is unavailable until customer cart ownership is supported.',
          ),
        ),
      );
      return;
    }
    if (_cartStore.items.isEmpty || !_hasPlaceableAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select or enter a complete delivery address and add items to continue.',
          ),
        ),
      );
      return;
    }
    final address = _confirmedDeliveryAddress!;
    if (_isBackendCart &&
        (_backendQuote == null || !_backendQuote!.isDeliverable)) {
      return;
    }
    setState(() => _placingOrder = true);
    try {
      final deliveryAddress = <String, Object?>{
        'label': address.addressType,
        'formattedAddress': address.formattedAddress,
        if (address.pincode?.isNotEmpty ?? false) 'pincode': address.pincode,
        if (address.receiverName?.isNotEmpty ?? false)
          'receiverName': address.receiverName,
        if (address.receiverMobile?.isNotEmpty ?? false)
          'receiverMobile': address.receiverMobile,
        if (address.landmark?.isNotEmpty ?? false) 'landmark': address.landmark,
        if (address.latitude != null) 'latitude': address.latitude,
        if (address.longitude != null) 'longitude': address.longitude,
      };
      final order = await CustomerApi.instance.placeOrder(deliveryAddress);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final confirmedOrder = OrderRecord(
        storeName: _cartStore.items.first.merchantId ?? 'MyShopzy Store',
        icon: _cartStore.items.first.icon,
        orderId: order.orderId,
        dateTime: DateTime.now().toLocal().toString(),
        itemSummary: _cartStore.items
            .map((item) => '${item.quantity} ${item.name}')
            .join(', '),
        totalInPaise: order.totalMinor,
        status: order.status,
        statusMessage: 'We have received your order',
        orderTab: OrdersTab.ongoing,
        serviceType: _cartStore.items.first.serviceType,
        items: [
          for (final item in _cartStore.items)
            OrderLineItem(
              name: item.name,
              quantity: item.quantity,
              unitPriceInPaise: item.priceInPaise,
              icon: item.icon,
              description: item.description,
              imageUrl: item.imageUrl,
              productId: item.productId,
              serviceType: item.serviceType,
              merchantId: item.merchantId,
              serviceVariant: item.serviceVariant,
              productVariantId: item.productVariantId,
              variantLabel: item.variantLabel,
            ),
        ],
        deliveryAddress: address.formattedAddress,
        deliveryAddressLabel: address.addressType,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: order.paymentStatus ?? 'Pending',
        paymentVerified: order.paymentVerified,
        deliveryChargeInPaise: order.deliveryFeeMinor,
        discountInPaise: order.discountMinor,
        trackingStatus: OrderTrackingStatus.orderPlaced,
        isBackendData: true,
        itemCount: order.itemCount,
      );
      _cartStore.clear();
      await Navigator.of(context).pushReplacement<void, void>(
        AppPageRoute<void>.builder(
          builder: (context) =>
              OrderSuccessPage(confirmedOrder: confirmedOrder),
        ),
      );
    } on CustomerApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'OUTSTANDING_DUES') {
        setState(() {
          _outstandingMinor = error.outstandingMinor ?? _outstandingMinor;
        });
        unawaited(_refreshDues());
      }
      if (error.code == 'STORE_CLOSED') {
        setState(() => _storeClosedByServer = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'STORE_CLOSED'
                ? _storeClosedMessage
                : CustomerApi.instance.orderOutcomeUnknown
                ? 'Order status is unknown. Do not submit again until checked.'
                : error.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  IconData _addressIcon(String addressType) {
    return switch (addressType) {
      'Home' => Icons.home_outlined,
      'Work' => Icons.business_outlined,
      _ => Icons.location_on_outlined,
    };
  }

  String _formatPrice(int priceInPaise) {
    return formatMinorCurrency(priceInPaise);
  }

  String _displayPrice(int? amountInPaise) {
    if (_isBackendCart && amountInPaise == null) {
      if (_quoteLoading) return 'Refreshing…';
      if (_quoteError != null) return 'Unavailable';
      return '—';
    }
    return _formatPrice(amountInPaise ?? 0);
  }
}

// Future backend validation: shop/store location -> confirmed delivery
// destination. Never use buyer GPS as the destination; no distance is checked.
const int serviceRadiusKm = 18;
const serviceRadiusCategories = [
  'Restaurants',
  'Bakery',
  'Local Stores',
  'Meat',
  'Vegetables & Fruits',
];

class CheckoutDeliveryAddress {
  const CheckoutDeliveryAddress({
    required this.id,
    required this.addressType,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
    this.pincode,
    this.receiverName,
    this.receiverMobile,
    this.landmark,
    this.isBackendData = false,
  });

  final String id;
  final double? latitude;
  final double? longitude;
  final String? pincode;
  final String formattedAddress;
  final String? receiverName;
  final String? receiverMobile;
  final String addressType;
  final String? landmark;
  final bool isBackendData;
}
