import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/utils/guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guard', () {
    test('returns Right with the body result on success', () async {
      final result = await guard<int>(() async => 42);

      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => -1), 42);
    });

    test('a void body succeeds as Right(null)', () async {
      final result = await guard<void>(() async {});

      expect(result.isRight(), isTrue);
    });

    test('maps a NetworkException to Left(NetworkFailure)', () async {
      final result = await guard<int>(() async => throw NetworkException());

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps a ServerException(message) to Left(ServerFailure(message))',
        () async {
      final result =
          await guard<int>(() async => throw const ServerException('boom'));

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).message, 'boom');
        },
        (_) => fail('expected Left'),
      );
    });

    test(
      'rethrows an unexpected (non-Exceptions) error when onUnexpected is '
      'not supplied — matching the repos with only the two standard catches',
      () async {
        await expectLater(
          guard<int>(() async => throw const FormatException('nope')),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'wraps an unexpected error via onUnexpected into Left(ServerFailure) — '
      'matching the repos that carried an extra catch-all',
      () async {
        final result = await guard<int>(
          () async => throw const FormatException('nope'),
          onUnexpected: (e) => 'Unexpected error: $e',
        );

        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(
              (failure as ServerFailure).message,
              'Unexpected error: FormatException: nope',
            );
          },
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'onUnexpected never intercepts NetworkException / ServerException',
      () async {
        final network = await guard<int>(
          () async => throw NetworkException(),
          onUnexpected: (_) => 'should not be used',
        );
        network.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );

        final server = await guard<int>(
          () async => throw const ServerException('server boom'),
          onUnexpected: (_) => 'should not be used',
        );
        server.fold(
          (failure) => expect((failure as ServerFailure).message, 'server boom'),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
