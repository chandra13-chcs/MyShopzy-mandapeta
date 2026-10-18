import 'customer_api.dart';

class WhatsAppService {
  WhatsAppService({CustomerApi? customerApi})
    : _customerApi = customerApi ?? CustomerApi.instance;

  final CustomerApi _customerApi;

  Future<void> requestOtp({required String recipientPhone}) {
    return _customerApi.requestOtp(phoneNumber: recipientPhone);
  }
}
