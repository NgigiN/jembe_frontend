import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with one canned status and body.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a 402 on createInvitation raises PaymentRequiredException', () async {
    final dio = Dio()
      ..httpClientAdapter = _CannedAdapter(
        402,
        '{"error":"the plan does not cover another team member",'
        ' "code":"seat_not_paid"}',
      );
    final remote = FarmRemoteDataSourceImpl(dio: dio);

    expect(
      () => remote.createInvitation('a@b.test', FarmRole.worker),
      throwsA(isA<PaymentRequiredException>()),
    );
  });

  test('a 422 seat_limit_reached stays a plain ServerException — it is the '
      'per-farm member cap and has nothing to do with money', () async {
    final dio = Dio()
      ..httpClientAdapter = _CannedAdapter(
        422,
        '{"error":"seat limit reached for this farm",'
        ' "code":"seat_limit_reached"}',
      );
    final remote = FarmRemoteDataSourceImpl(dio: dio);

    expect(
      () => remote.createInvitation('a@b.test', FarmRole.worker),
      throwsA(
        allOf(isA<ServerException>(), isNot(isA<PaymentRequiredException>())),
      ),
    );
  });
}
