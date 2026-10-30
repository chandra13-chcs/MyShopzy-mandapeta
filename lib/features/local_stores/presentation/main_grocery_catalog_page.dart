import 'package:flutter/material.dart';

import '../../../shared/data/customer_api.dart';
import '../models/local_store.dart';
import 'local_store_catalog_page.dart';

class MainGroceryCatalogPage extends StatefulWidget {
  const MainGroceryCatalogPage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<MainGroceryCatalogPage> createState() => _MainGroceryCatalogPageState();
}

class _MainGroceryCatalogPageState extends State<MainGroceryCatalogPage> {
  late Future<LocalStore> _storeFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = _loadMainStore();
  }

  Future<LocalStore> _loadMainStore() async {
    final api = CustomerApi.instance;
    if (!api.isConfigured) return sampleLocalStores.first;

    final shops = await api.getAllShops(partnerType: 'grocery');
    if (shops.isEmpty) {
      throw StateError('No Grocery catalogue is currently available.');
    }
    final shop = shops.firstWhere(
      (candidate) => candidate.storeOpen,
      orElse: () => shops.first,
    );
    return LocalStore(
      id: shop.id,
      name: shop.name,
      rating: 0,
      deliveryTime: 'Not provided',
      distance: '—',
      locality: shop.address ?? 'Address not provided',
      isOpen: shop.storeOpen,
      isBackendData: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return LocalStoreCatalogPage(
            store: snapshot.data!,
            initialCategoryId: widget.initialCategoryId,
            displayTitle: 'Groceries',
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Groceries'),
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'The Grocery catalogue is unavailable right now.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _storeFuture = _loadMainStore());
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
