import 'package:flutter/material.dart';

import '../../product_details/data/recently_viewed_store.dart';
import 'recently_viewed_product_card.dart';

class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key});

  static const _background = Color(0xFFF7F8F5);
  static const _ink = Color(0xFF17251F);
  static const _green = Color(0xFF16834A);

  @override
  Widget build(BuildContext context) {
    final store = RecentlyViewedStore.instance;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        surfaceTintColor: _background,
        title: const Text(
          'Recently Viewed',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          AnimatedBuilder(
            animation: store,
            builder: (context, child) => store.products.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _confirmClear(context),
                    style: TextButton.styleFrom(foregroundColor: _green),
                    child: const Text('Clear All'),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, child) {
            final products = store.products;
            if (products.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: Color(0xFF8A948C),
                        size: 44,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No recently viewed products',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Products you open will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF727A74),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) =>
                  RecentlyViewedProductCard(product: products[index]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recently viewed?'),
        content: const Text(
          'This will clear the locally saved recently viewed list on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (shouldClear == true) RecentlyViewedStore.instance.clear();
  }
}
