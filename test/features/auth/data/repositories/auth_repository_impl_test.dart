import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';
import 'package:farm_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('googleSignIn persists farms and default farm id via '
      'FarmStorageService', () async {
    final remote = _MockRemote();
    when(() => remote.googleSignIn(any())).thenAnswer((_) async => {
      'user': UserModel.empty(),
      'token': 'tok',
      'record': <String, dynamic>{},
      'farms': [
        {
          'id': 7, 'name': 'Green Acres', 'location': 'Nakuru',
          'fiscal_year_start_month': 3, 'owner_user_id': 1,
          'successor_user_id': null, 'max_members': 10,
          'role': 'owner', 'member_count': 1, 'is_default': true,
        },
      ],
      'defaultFarmId': 7,
    });
    final repo = AuthRepositoryImpl(remoteDataSource: remote);

    await repo.googleSignIn('id-token');

    final farms = await FarmStorageService.getFarms();
    expect(farms, hasLength(1));
    expect(farms.single.id, 7);
    expect(await FarmStorageService.getDefaultFarmId(), 7);
  });
}
