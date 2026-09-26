import 'package:flutter_test/flutter_test.dart';
import 'package:scanserve/shared/models/order_status.dart';

void main() {
  test('Order status transitions exclude COMPLETED and terminate at READY', () {
    expect(kOrderStatuses.contains('COMPLETED'), isFalse);
    expect(nextStatusesFor('PREPARING'), contains('READY'));
    expect(nextStatusesFor('READY'), isEmpty);
  });
}
