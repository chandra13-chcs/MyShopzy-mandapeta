enum LocalStoreStatus { open, closed }

class LocalStore {
  const LocalStore({
    required this.id,
    required this.name,
    required this.rating,
    required this.deliveryTime,
    required this.distance,
    required this.locality,
    required this.isOpen,
    this.isBackendData = false,
    this.imageUrl,
    this.offer,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final double rating;
  final String deliveryTime;
  final String distance;
  final String locality;
  final String? offer;
  final bool isOpen;
  final bool isBackendData;

  double get distanceInKm =>
      double.tryParse(distance.toLowerCase().replaceAll('km', '').trim()) ??
      double.infinity;
}

const localStoreDeliveryRadiusKm = 18.0;

const sampleLocalStores = [
  LocalStore(
    id: 'sri-lakshmi-general-store',
    name: 'Sri Lakshmi General Store',
    rating: 4.6,
    deliveryTime: '15–20 min',
    distance: '1.2 km',
    locality: 'Mandapeta',
    offer: '10% OFF',
    isOpen: true,
  ),
  LocalStore(
    id: 'venkateswara-stores',
    name: 'Venkateswara Stores',
    rating: 4.4,
    deliveryTime: '20–25 min',
    distance: '2.4 km',
    locality: 'Mandapeta',
    isOpen: true,
  ),
  LocalStore(
    id: 'sai-balaji-supermarket',
    name: 'Sai Balaji Supermarket',
    rating: 4.7,
    deliveryTime: '20–30 min',
    distance: '3.1 km',
    locality: 'Mandapeta',
    offer: 'FREE DELIVERY',
    isOpen: true,
  ),
  LocalStore(
    id: 'sri-durga-general-stores',
    name: 'Sri Durga General Stores',
    rating: 4.3,
    deliveryTime: '25–30 min',
    distance: '4.8 km',
    locality: 'Mandapeta',
    isOpen: false,
  ),
];

List<LocalStore> sortLocalStoresByDistance(Iterable<LocalStore> stores) {
  final sortedStores = stores.toList();
  sortedStores.sort((first, second) {
    return first.distanceInKm.compareTo(second.distanceInKm);
  });
  return sortedStores;
}

List<LocalStore> eligibleLocalStores(Iterable<LocalStore> stores) {
  return sortLocalStoresByDistance(
    stores.where(
      (store) => store.distanceInKm <= localStoreDeliveryRadiusKm,
    ),
  );
}
