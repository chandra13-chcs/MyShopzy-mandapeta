import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/data/customer_api.dart';
import '../../cart/presentation/cart_page.dart';
import '../../categories/presentation/categories_page.dart';
import '../../coupons/presentation/coupons_page.dart';
import '../../help_support/presentation/help_support_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../orders/presentation/orders_page.dart';
import '../../payments/presentation/payments_page.dart';
import '../../privacy_policy/presentation/privacy_policy_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../terms_conditions/presentation/terms_conditions_page.dart';
import '../../wishlist/presentation/wishlist_page.dart';
import '../../../shared/presentation/bottom_navigation_bar.dart';
import 'edit_profile_page.dart';
import 'dues_page.dart';
import 'saved_addresses_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onMainTabSelected});

  final ValueChanged<int>? onMainTabSelected;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _background = AppTheme.lightBackground;
  static const _green = AppTheme.primaryGreen;
  static const _lightGreen = AppTheme.lightBackground;
  static const _mainText = AppTheme.primaryText;
  static const _secondaryText = AppTheme.secondaryText;
  static const _border = Color(0xFFE7EAE8);
  static const _yellow = AppTheme.brandYellow;
  static const _yellowText = AppTheme.darkGreen;
  static const _logoutBackground = Color(0xFFFFF2F1);
  static const _logoutColor = Color(0xFFA85B5B);
  ApiCustomerProfile? _profile;
  String? _profileError;
  bool _profileLoading = false;

  bool get _backendMode =>
      CustomerApi.instance.isConfigured &&
      CustomerApi.instance.hasCustomerSession;

  @override
  void initState() {
    super.initState();
    if (_backendMode) {
      _profileLoading = true;
      unawaited(_loadProfile());
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final profile = await CustomerApi.instance.getProfile();
      if (mounted) setState(() => _profile = profile);
    } on CustomerApiException catch (error) {
      if (mounted) {
        setState(() {
          _profile = null;
          _profileError = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  static const _accountItems = [
    _ProfileMenuItem('My Orders', Icons.inventory_2_outlined),
    _ProfileMenuItem('My Dues', Icons.account_balance_wallet_outlined),
    _ProfileMenuItem('Saved Addresses', Icons.location_on_outlined),
    _ProfileMenuItem('Wishlist', Icons.favorite_border_rounded),
    _ProfileMenuItem('Coupons & Offers', Icons.local_offer_outlined),
    _ProfileMenuItem('Payments', Icons.credit_card_outlined),
    _ProfileMenuItem('Notifications', Icons.notifications_none_rounded),
    _ProfileMenuItem('Help & Support', Icons.help_outline_rounded),
    _ProfileMenuItem('Settings', Icons.tune_rounded),
  ];

  static const _moreItems = [
    _ProfileMenuItem('Privacy Policy', Icons.verified_user_outlined),
    _ProfileMenuItem('Terms & Conditions', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        NotificationsPage.unreadCount,
        CouponsPage.newDemoCouponCount,
        OrdersPage.ongoingOrderCount,
      ]),
      builder: (context, child) => Scaffold(
        backgroundColor: _background,
        body: !CustomerApi.instance.canAccessCustomerFeatures
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Sign in to access your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryText),
                  ),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Account',
                        style: TextStyle(
                          color: _mainText,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildProfileCard(context),
                      const SizedBox(height: 25),
                      _buildSectionTitle('QUICK ORDERS'),
                      const SizedBox(height: 10),
                      _buildQuickOrders(context),
                      const SizedBox(height: 25),
                      _buildSectionTitle('ACCOUNT'),
                      const SizedBox(height: 10),
                      _buildMenuCard(context, _accountItems),
                      const SizedBox(height: 25),
                      _buildSectionTitle('MORE'),
                      const SizedBox(height: 10),
                      _buildMoreCard(context),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: widget.onMainTabSelected == null
            ? _buildBottomNavigation(context)
            : null,
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final profile = _profile;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 22),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: _lightGreen,
              shape: BoxShape.circle,
              border: Border.all(color: _green, width: 1.5),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _green,
              size: 43,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: _profileLoading
                ? const Center(child: CircularProgressIndicator())
                : _profileError != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileError!,
                        style: const TextStyle(
                          color: _logoutColor,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: _profileLoading ? null : _loadProfile,
                        child: const Text('Retry profile'),
                      ),
                    ],
                  )
                : profile == null
                ? CustomerApi.instance.canAccessCustomerFeatures
                      ? _buildDemoProfilePreview(context)
                      : const Text(
                          'Profile details are unavailable.',
                          style: TextStyle(color: _secondaryText),
                        )
                : _buildProfileDetails(context, profile),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoProfilePreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demo profile · not signed in',
          style: TextStyle(color: _secondaryText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const EditProfilePage(),
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: const BorderSide(color: _green),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
          child: const Text('Edit Profile Preview'),
        ),
      ],
    );
  }

  Widget _buildProfileDetails(
    BuildContext context,
    ApiCustomerProfile profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your account',
          style: const TextStyle(color: _secondaryText, fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _mainText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        if (profile.phone?.isNotEmpty ?? false)
          Text(
            profile.phone!,
            style: const TextStyle(color: _secondaryText, fontSize: 14),
          ),
        if (profile.email?.isNotEmpty ?? false)
          Text(
            profile.email!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _secondaryText, fontSize: 12),
          ),
        if ((profile.phone == null || profile.phone!.isEmpty) &&
            (profile.email == null || profile.email!.isEmpty))
          const Text(
            'Add your contact details',
            style: TextStyle(color: _secondaryText, fontSize: 14),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            final updatedProfile = await Navigator.of(context)
                .push<ApiCustomerProfile>(
                  MaterialPageRoute<ApiCustomerProfile>(
                    builder: (context) => EditProfilePage(profile: profile),
                  ),
                );
            if (!context.mounted || updatedProfile == null) return;
            setState(() => _profile = updatedProfile);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile updated successfully.')),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            disabledForegroundColor: _green,
            side: const BorderSide(color: _green),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickOrders(BuildContext context) {
    const orders = [
      _QuickOrder('Ongoing', Icons.access_time_rounded, OrdersTab.ongoing),
      _QuickOrder(
        'Delivered',
        Icons.check_circle_outline_rounded,
        OrdersTab.delivered,
      ),
      _QuickOrder('Cancelled', Icons.cancel_outlined, OrdersTab.cancelled),
    ];

    return Container(
      height: 112,
      decoration: _cardDecoration(radius: 20),
      child: Row(
        children: [
          for (var index = 0; index < orders.length; index++) ...[
            Expanded(child: _buildQuickOrder(context, orders[index])),
            if (index < orders.length - 1)
              const SizedBox(
                height: 72,
                child: VerticalDivider(width: 1, color: _border),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickOrder(BuildContext context, _QuickOrder order) {
    final ongoingCount = OrdersPage.ongoingOrderCount.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => OrdersPage(initialTab: order.tab),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(order.icon, color: _green, size: 25),
              ),
              if (order.tab == OrdersTab.ongoing && ongoingCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: _Badge(label: '$ongoingCount'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.title,
            style: const TextStyle(
              color: _mainText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<_ProfileMenuItem> items) {
    return Container(
      decoration: _cardDecoration(radius: 20),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _buildMenuRow(context, items[index]),
            if (index < items.length - 1)
              const Divider(height: 1, thickness: 1, color: _border),
          ],
        ],
      ),
    );
  }

  Widget _buildMoreCard(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 20),
      child: Column(
        children: [
          for (final item in _moreItems) ...[
            _buildMenuRow(context, item),
            const Divider(height: 1, thickness: 1, color: _border),
          ],
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: _logoutColor,
                  disabledForegroundColor: _logoutColor,
                  backgroundColor: _logoutBackground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    _buildIconContainer(
                      Icons.logout_rounded,
                      background: _logoutBackground,
                      color: _logoutColor,
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: _logoutColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow(BuildContext context, _ProfileMenuItem item) {
    final badge = switch (item.title) {
      'Notifications' =>
        NotificationsPage.unreadCount.value == 0
            ? null
            : '${NotificationsPage.unreadCount.value}',
      'Coupons & Offers' =>
        CouponsPage.newDemoCouponCount.value == 0
            ? null
            : '${CouponsPage.newDemoCouponCount.value} New',
      _ => null,
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        children: [
          _buildIconContainer(item.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                color: _mainText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (badge != null) ...[
            _Badge(label: badge),
            const SizedBox(width: 9),
          ],
          const Icon(Icons.chevron_right_rounded, color: _secondaryText),
        ],
      ),
    );
    if (item.title == 'My Orders') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const OrdersPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'My Dues') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const DuesPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Notifications') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Wishlist') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const WishlistPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Coupons & Offers') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const CouponsPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Payments') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const PaymentsPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Help & Support') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const HelpSupportPage(),
            ),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Settings') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const SettingsPage()),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Privacy Policy') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const PrivacyPolicyPage(),
            ),
          );
        },
        child: row,
      );
    }
    if (item.title == 'Terms & Conditions') {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const TermsConditionsPage(),
            ),
          );
        },
        child: row,
      );
    }
    if (item.title != 'Saved Addresses') return row;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const SavedAddressesPage(),
          ),
        );
      },
      child: row,
    );
  }

  Widget _buildIconContainer(
    IconData icon, {
    Color background = _lightGreen,
    Color color = _green,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return ShopzyBottomNavigationBar(
      currentIndex: 4,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const CategoriesPage(),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const CartPage()),
          );
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const OrdersPage()),
          );
        }
      },
    );
  }

  BoxDecoration _cardDecoration({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _border),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _ProfilePageState._yellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _ProfilePageState._yellowText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickOrder {
  const _QuickOrder(this.title, this.icon, this.tab);

  final String title;
  final IconData icon;
  final OrdersTab tab;
}

class _ProfileMenuItem {
  const _ProfileMenuItem(this.title, this.icon);

  final String title;
  final IconData icon;
}
