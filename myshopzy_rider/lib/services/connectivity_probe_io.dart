import 'dart:async';
import 'dart:io';

Stream<bool> get connectionChanges => const Stream<bool>.empty();

Future<bool> hasInternetConnection() async {
  for (final host in ['google.com', 'cloudflare.com']) {
    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addresses.any((address) => address.rawAddress.isNotEmpty)) {
        return true;
      }
    } on SocketException {
      continue;
    } on TimeoutException {
      continue;
    }
  }
  return false;
}
