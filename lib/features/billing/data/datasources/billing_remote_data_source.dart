import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';

/// What a checkout returned. The reference is worth keeping so a support
/// conversation can name the exact transaction.
class CheckoutResult {
  const CheckoutResult({required this.reference, required this.amountKes});

  final String reference;
  final int amountKes;
}

abstract class BillingRemoteDataSource {
  Future<EntitlementModel> getEntitlement();
  Future<CheckoutResult> checkout({
    required int seats,
    required int months,
    required String phone,
  });
}

class BillingRemoteDataSourceImpl implements BillingRemoteDataSource {
  BillingRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  static Options get _permissive =>
      Options(validateStatus: (status) => status != null && status < 500);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  void _throwIfNotOk(Response<dynamic> response, Set<int> okStatuses) {
    if (!okStatuses.contains(response.statusCode)) {
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    }
  }

  @override
  Future<EntitlementModel> getEntitlement() => _guard(() async {
    final response = await dio.get<dynamic>(
      '/api/v1/farms/current/entitlement',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
    return EntitlementModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  });

  @override
  Future<CheckoutResult> checkout({
    required int seats,
    required int months,
    required String phone,
  }) => _guard(() async {
    final response = await dio.post<dynamic>(
      '/api/v1/subscription/checkout',
      data: {'seats': seats, 'months': months, 'phone': phone},
      options: _permissive,
    );
    _throwIfNotOk(response, {200, 202});
    final body = Map<String, dynamic>.from(response.data as Map);
    return CheckoutResult(
      reference: (body['reference'] ?? '').toString(),
      amountKes: (body['amount_kes'] as num?)?.toInt() ?? 0,
    );
  });
}
