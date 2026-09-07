import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/dashboard_model.dart';

// ignore: one_member_abstracts
abstract class DashboardRemoteDataSource {
  Future<DashboardModel> getDashboard();
}

/// Online-only (Phase 8 B1): `GET /api/v1/dashboard` seeds the
/// `PlantsPage`/`AnimalsPage` landing-screen counts in one round trip
/// instead of each screen firing a separate list GET purely to learn a
/// count. Callers gate the call on `!OfflineConfig.enabled` — there is no
/// offline mirror for this aggregate.
class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<DashboardModel> getDashboard() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching dashboard summary');
      final response = await dio.get<dynamic>('/api/v1/dashboard');

      appLogger.debug(
        LogCategory.http,
        'Dashboard API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final result = DashboardModel.fromJson(
          response.data as Map<String, dynamic>,
        );
        appLogger.info(
          LogCategory.farm,
          'Successfully fetched dashboard summary',
        );
        return result;
      }
      final msg = extractServerErrorMessage(response.data);
      appLogger.error(
        LogCategory.http,
        'Failed to fetch dashboard: status ${response.statusCode}',
      );
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in getDashboard', e);
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('getDashboard', e);
      throw const ServerException();
    }
  }
}
