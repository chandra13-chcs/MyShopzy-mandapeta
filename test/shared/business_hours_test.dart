import 'package:flutter_test/flutter_test.dart';
import 'package:myshopzy/shared/config/business_hours.dart';

void main() {
  test('uses Asia/Kolkata time and includes the opening boundary', () {
    expect(BusinessHours.isOpenAt(DateTime.utc(2026, 10, 23, 1, 29)), isFalse);
    expect(BusinessHours.isOpenAt(DateTime.utc(2026, 10, 23, 1, 30)), isTrue);
  });

  test('closes at 10 PM Asia/Kolkata', () {
    expect(BusinessHours.isOpenAt(DateTime.utc(2026, 10, 23, 16, 29)), isTrue);
    expect(BusinessHours.isOpenAt(DateTime.utc(2026, 10, 23, 16, 30)), isFalse);
  });
}
