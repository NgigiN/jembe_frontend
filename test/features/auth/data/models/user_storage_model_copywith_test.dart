import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = UserStorageModel(
    email: 'a@b.com', farmName: 'Shamba', id: '1', location: 'Nyeri',
    name: 'Ngigi', token: 'tok', loginTime: DateTime(2026, 1, 1),
    pictureUrl: 'http://p',
  );

  test('copyWith changes only the named field', () {
    final updated = base.copyWith(name: 'New Name');
    expect(updated.name, 'New Name');
    expect(updated.email, base.email);
    expect(updated.id, base.id);
    expect(updated.token, base.token);
    expect(updated.pictureUrl, base.pictureUrl);
    expect(updated.loginTime, base.loginTime);
  });
}
