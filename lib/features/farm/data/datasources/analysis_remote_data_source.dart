import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/monthly_summary_model.dart';

abstract class AnalysisRemoteDataSource {
  Future<FarmDetailedCostModel> getTotalCostsBySeason();
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType();
  Future<List<MonthlySummaryModel>> getAnnualCostSummary();
}

class AnalysisRemoteDataSourceImpl implements AnalysisRemoteDataSource {
  AnalysisRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<FarmDetailedCostModel> getTotalCostsBySeason() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching unified total costs');
      final response = await dio.get('/api/v1/analytics/total-costs');

      appLogger.debug(
        LogCategory.http,
        'Unified Total Costs API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final result = FarmDetailedCostModel.fromJson(response.data);

        appLogger.info(
          LogCategory.farm,
          'Successfully fetched unified total costs',
        );
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        appLogger.warning(
          LogCategory.auth,
          'Authentication required for total costs by season',
        );
        throw const ServerException(
          'Authentication required. Please log in again.',
        );
      } else {
        var errorMsg =
            'Failed to load total costs by season (Status: ${response.statusCode})';
        try {
          if (response.data is Map && response.data['error'] != null) {
            errorMsg = response.data['error'].toString();
          }
        } catch (_) {}
        appLogger.error(
          LogCategory.http,
          'Failed to load total costs by season: $errorMsg',
        );
        throw ServerException(errorMsg);
      }
    } catch (e) {
      appLogger.logError('getTotalCostsBySeason', e);
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Failed to load total costs by season: $e');
    }
  }

  @override
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching cost breakdown by input type');
      final response = await dio.get(
        '/api/v1/analytics/cost-breakdown',
        queryParameters: {'type': 'plant'},
      );

      appLogger.debug(
        LogCategory.http,
        'Cost Breakdown API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        appLogger.warning(
          LogCategory.auth,
          'Authentication required for cost breakdown',
        );
        throw const ServerException(
          'Authentication required. Please log in again.',
        );
      } else {
        var errorMsg =
            'Failed to load cost breakdown (Status: ${response.statusCode})';
        try {
          if (response.data is Map && response.data['error'] != null) {
            errorMsg = response.data['error'].toString();
          }
        } catch (_) {}
        appLogger.error(
          LogCategory.http,
          'Failed to load cost breakdown: $errorMsg',
        );
        throw ServerException(errorMsg);
      }
    } catch (e) {
      appLogger.logError('getCostBreakdownByInputType', e);
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Failed to load cost breakdown: $e');
    }
  }

  @override
  Future<List<MonthlySummaryModel>> getAnnualCostSummary() async {
    try {
      appLogger.info(
        LogCategory.farm,
        'Fetching annual cost summary (monthly breakdown)',
      );
      final currentYear = DateTime.now().year;
      final response = await dio.get(
        '/api/v1/analytics/monthly-summary',
        queryParameters: {'year': currentYear.toString()},
      );

      appLogger.debug(
        LogCategory.http,
        'Monthly Summary API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        appLogger.warning(
          LogCategory.auth,
          'Authentication required for annual cost summary',
        );
        throw const ServerException(
          'Authentication required. Please log in again.',
        );
      } else {
        var errorMsg =
            'Failed to load annual cost summary (Status: ${response.statusCode})';
        try {
          if (response.data is Map && response.data['error'] != null) {
            errorMsg = response.data['error'].toString();
          }
        } catch (_) {}
        appLogger.error(
          LogCategory.http,
          'Failed to load annual cost summary: $errorMsg',
        );
        throw ServerException(errorMsg);
      }
    } catch (e) {
      appLogger.logError('getAnnualCostSummary', e);
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Failed to load annual cost summary: $e');
    }
  }
}
