import 'package:connectivity_plus/connectivity_plus.dart';

final _connectivity = Connectivity();

Stream<bool> get connectionChanges => _connectivity.onConnectivityChanged.map(
    (results) => results.any((result) => result != ConnectivityResult.none));

Future<bool> hasInternetConnection() async {
  final results = await _connectivity.checkConnectivity();
  return results.any((result) => result != ConnectivityResult.none);
}
