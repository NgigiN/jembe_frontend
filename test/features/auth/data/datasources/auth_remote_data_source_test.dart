import 'package:dio/dio.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedJsonAdapter implements HttpClientAdapter {
  _FixedJsonAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"user":${_userJson()},"token":"tok","farms":${_farmsJson()},'
      '"default_farm_id":${body['default_farm_id']}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _userJson() => '{"id":"1","email":"a@b.com","first_name":"A","last_name":"B",'
      '"farm_name":"F","location":"L","picture_url":""}';
  String _farmsJson() => '[{"id":7,"name":"Green Acres","location":"Nakuru",'
      '"fiscal_year_start_month":3,"owner_user_id":1,"successor_user_id":null,'
      '"max_members":10,"role":"owner","member_count":1,"is_default":true}]';

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('googleSignIn passes through farms and default_farm_id from the '
      'response', () async {
    final dio = Dio()..httpClientAdapter = _FixedJsonAdapter({'default_farm_id': 7});
    final source = AuthRemoteDataSourceImpl(dio: dio);

    final result = await source.googleSignIn('id-token');

    expect(result['farms'], isA<List<dynamic>>());
    expect((result['farms']! as List<dynamic>), hasLength(1));
    expect(result['defaultFarmId'], 7);
  });
}
