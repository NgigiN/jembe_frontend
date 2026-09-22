import 'package:farm_tracker/features/farms/data/models/farm_transfer_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FarmTransferModel.fromJson parses every TransferResponse field', () {
    final model = FarmTransferModel.fromJson(const {
      'id': 1,
      'farm_id': 7,
      'from_user_id': 12,
      'to_user_id': 34,
      'expires_at': '2026-10-05T00:00:00Z',
      'created_at': '2026-09-21T00:00:00Z',
    });

    expect(model.id, 1);
    expect(model.farmId, 7);
    expect(model.fromUserId, 12);
    expect(model.toUserId, 34);
  });
}
