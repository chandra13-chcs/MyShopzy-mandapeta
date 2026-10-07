import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/features/orders/presentation/orders_page.dart';

void main() {
  test('ongoing count follows the demo order status', () {
    expect(OrdersPage.ongoingOrderCount.value, 1);

    OrdersPage.updateDemoOrderTab('MSZ-DEMO-1042', OrdersTab.delivered);
    expect(OrdersPage.ongoingOrderCount.value, 0);

    OrdersPage.updateDemoOrderTab('MSZ-DEMO-1042', OrdersTab.ongoing);
    expect(OrdersPage.ongoingOrderCount.value, 1);
  });
}
