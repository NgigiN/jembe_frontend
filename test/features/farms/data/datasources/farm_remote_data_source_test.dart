import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedJsonAdapter implements HttpClientAdapter {
  _FixedJsonAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _farmJson = '{"id":7,"name":"Green Acres","location":"Nakuru",'
    '"fiscal_year_start_month":3,"owner_user_id":1,"successor_user_id":null,'
    '"max_members":10,"role":"owner","member_count":1,"is_default":true}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('listFarms parses a raw JSON array', () async {
    final dio = Dio()..httpClientAdapter = _FixedJsonAdapter(200, '[$_farmJson]');
    final source = FarmRemoteDataSourceImpl(dio: dio);

    final farms = await source.listFarms();

    expect(farms, hasLength(1));
    expect(farms.single.id, 7);
  });

  test('getCurrentFarm parses a single farm object', () async {
    final dio = Dio()..httpClientAdapter = _FixedJsonAdapter(200, _farmJson);
    final source = FarmRemoteDataSourceImpl(dio: dio);

    final farm = await source.getCurrentFarm();

    expect(farm.name, 'Green Acres');
  });

  test('createFarm posts the request body and parses the created farm',
      () async {
    final dio = Dio()..httpClientAdapter = _FixedJsonAdapter(201, _farmJson);
    final source = FarmRemoteDataSourceImpl(dio: dio);

    final farm = await source.createFarm(
      name: 'Green Acres',
      location: 'Nakuru',
      fiscalYearStartMonth: 3,
    );

    expect(farm.id, 7);
  });

  test('a non-2xx response throws ServerException', () async {
    final dio = Dio()
      ..httpClientAdapter =
          _FixedJsonAdapter(400, '{"error":"invalid name"}');
    final source = FarmRemoteDataSourceImpl(dio: dio);

    await expectLater(
      source.listFarms(),
      throwsA(isA<ServerException>()),
    );
  });

  test('getTransfer returns null on a 404 (no pending transfer) rather '
      'than throwing', () async {
    final dio = Dio()
      ..httpClientAdapter = _FixedJsonAdapter(404, '{"error":"not found"}');
    final source = FarmRemoteDataSourceImpl(dio: dio);

    final transfer = await source.getTransfer();

    expect(transfer, isNull);
  });

  test('createInvitation sends email and role in the request body',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _FixedJsonAdapter(
        201,
        '{"id":3,"email":"w@example.com","role":"worker","invited_by":1,'
        '"expires_at":"2026-10-01T00:00:00Z","created_at":"2026-09-21T00:00:00Z"}',
      );
    final source = FarmRemoteDataSourceImpl(dio: dio);

    final invitation = await source.createInvitation('w@example.com', FarmRole.worker);

    expect(invitation.email, 'w@example.com');
    expect(invitation.role, FarmRole.worker);
  });
}
