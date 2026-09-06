import 'package:farm_tracker/core/database/db_key_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage secureStorage;
  late DbKeyService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage = MockFlutterSecureStorage();
    service = DbKeyService(secureStorage: secureStorage);
  });

  group('getOrCreateKey', () {
    test(
      'generates a fresh 256-bit (64 hex char) key and persists it via '
      'secure storage when none exists yet',
      () async {
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        final key = await service.getOrCreateKey();

        expect(key, hasLength(64));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
        verify(
          () => secureStorage.write(key: 'db_encryption_key', value: key),
        ).called(1);
      },
    );

    test('returns the SAME key on a second call once persisted', () async {
      String? stored;
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => stored);
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        stored = invocation.namedArguments[#value] as String;
      });

      final first = await service.getOrCreateKey();
      final second = await service.getOrCreateKey();

      expect(second, first);
      // Only generated (and thus written) once — the second call read the
      // value the first call persisted.
      verify(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test(
      'two independent services against the same backing store agree on '
      'the key (simulates two app-process cold starts on one device)',
      () async {
        String? stored;
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => stored);
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          stored = invocation.namedArguments[#value] as String;
        });

        final firstProcessKey = await service.getOrCreateKey();
        final secondProcessKey = await DbKeyService(
          secureStorage: secureStorage,
        ).getOrCreateKey();

        expect(secondProcessKey, firstProcessKey);
      },
    );

    test(
      'falls back to shared_preferences and still returns a usable key '
      'when secure storage throws on every call (degrade, not lock out)',
      () async {
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenThrow(Exception('secure storage unavailable'));
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(Exception('secure storage unavailable'));

        final first = await service.getOrCreateKey();
        final second = await service.getOrCreateKey();

        expect(first, hasLength(64));
        expect(second, first);
      },
    );
  });

  group('deleteKey', () {
    test('clears the key from secure storage', () async {
      when(
        () => secureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await service.deleteKey();

      verify(() => secureStorage.delete(key: 'db_encryption_key')).called(1);
    });

    test(
      'a key deleted via deleteKey is regenerated (not reused) by a '
      'later getOrCreateKey call',
      () async {
        String? stored = 'stale-key-from-a-previous-install';
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => stored);
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          stored = invocation.namedArguments[#value] as String;
        });
        when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((
          _,
        ) async {
          stored = null;
        });

        final before = await service.getOrCreateKey();
        expect(before, 'stale-key-from-a-previous-install');

        await service.deleteKey();
        final after = await service.getOrCreateKey();

        expect(after, isNot(before));
        expect(after, hasLength(64));
      },
    );

    test(
      'degrades gracefully (does not throw) when secure storage delete '
      'fails',
      () async {
        when(
          () => secureStorage.delete(key: any(named: 'key')),
        ).thenThrow(Exception('secure storage unavailable'));

        await expectLater(service.deleteKey(), completes);
      },
    );
  });
}
