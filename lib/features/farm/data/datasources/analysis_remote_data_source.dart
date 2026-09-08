import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';
import 'package:farm_tracker/features/farm/data/models/monthly_summary_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';

/// Read-only analytics endpoints. Every call carries an [AnalyticsScope],
/// sent as the server's `source` / `land_id` / `herd_id` query params
/// (spec 2026-09-08 §3.1); a farm-wide scope sends no params at all.
abstract class AnalysisRemoteDataSource {
  Future<FarmDetailedCostModel> getTotalCostsBySeason(AnalyticsScope scope);
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType(
    AnalyticsScope scope,
  );
  Future<List<MonthlySummaryModel>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
    AnalyticsScope scope,
  );
}

class AnalysisRemoteDataSourceImpl implements AnalysisRemoteDataSource {
  AnalysisRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<FarmDetailedCostModel> getTotalCostsBySeason(
    AnalyticsScope scope,
  ) async {
    try {
      appLogger.info(
        LogCategory.farm,
        'Fetching unified total costs ${scope.toQueryParams()}',
      );
      final response = await dio.get<dynamic>(
        '/api/v1/analytics/total-costs',
        queryParameters: scope.toQueryParams(),
      );

      appLogger.debug(
        LogCategory.http,
        'Unified Total Costs API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final result = FarmDetailedCostModel.fromJson(
          response.data as Map<String, dynamic>,
        );
        appLogger.info(
          LogCategory.farm,
          'Successfully fetched unified total costs',
        );
        return result;
      }
      final msg = extractServerErrorMessage(response.data);
      appLogger.error(
        LogCategory.http,
        'Failed to fetch total costs: status ${response.statusCode}',
      );
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(
        LogCategory.http,
        'DioException in getTotalCostsBySeason',
        e,
      );
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('getTotalCostsBySeason', e);
      throw const ServerException();
    }
  }

  @override
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType(
    AnalyticsScope scope,
  ) async {
    try {
      appLogger.info(
        LogCategory.farm,
        'Fetching cost breakdown by input type ${scope.toQueryParams()}',
      );
      final response = await dio.get<dynamic>(
        '/api/v1/analytics/cost-breakdown',
        queryParameters: scope.toQueryParams(),
      );

      appLogger.debug(
        LogCategory.http,
        'Cost Breakdown API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>? ?? [];
        final breakdowns = data
            .map(
              (item) =>
                  CostBreakdownModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        appLogger.info(
          LogCategory.farm,
          'Successfully fetched ${breakdowns.length} cost breakdowns',
        );
        return breakdowns;
      }
      final msg = extractServerErrorMessage(response.data);
      appLogger.error(
        LogCategory.http,
        'Failed to fetch cost breakdown: status ${response.statusCode}',
      );
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(
        LogCategory.http,
        'DioException in getCostBreakdownByInputType',
        e,
      );
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('getCostBreakdownByInputType', e);
      throw const ServerException();
    }
  }

  @override
  Future<List<MonthlySummaryModel>> getAnnualCostSummary(
    DateTime startDate,
    DateTime endDate,
    AnalyticsScope scope,
  ) async {
    try {
      appLogger.info(
        LogCategory.farm,
        'Fetching annual cost summary (monthly breakdown) '
        '${scope.toQueryParams()}',
      );
      final response = await dio.get<dynamic>(
        '/api/v1/analytics/monthly-summary',
        queryParameters: {
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          ...scope.toQueryParams(),
        },
      );

      appLogger.debug(
        LogCategory.http,
        'Monthly Summary API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>? ?? [];
        final summaries = data
            .map(
              (item) =>
                  MonthlySummaryModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        appLogger.info(
          LogCategory.farm,
          'Successfully fetched ${summaries.length} monthly summaries',
        );
        return summaries;
      }
      final msg = extractServerErrorMessage(response.data);
      appLogger.error(
        LogCategory.http,
        'Failed to fetch annual cost summary: status ${response.statusCode}',
      );
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(
        LogCategory.http,
        'DioException in getAnnualCostSummary',
        e,
      );
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('getAnnualCostSummary', e);
      throw const ServerException();
    }
  }
}
