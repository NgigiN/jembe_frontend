import 'dart:convert';
import 'package:farm_tracker/features/farm/data/models/total_costs_by_season_model.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/annual_cost_summary_model.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../services/farm_data_service.dart';

abstract class AnalysisRemoteDataSource {
  Future<List<TotalCostsBySeasonModel>> getTotalCostsBySeason();
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType();
  Future<List<AnnualCostSummaryModel>> getAnnualCostSummary();
}

class AnalysisRemoteDataSourceImpl implements AnalysisRemoteDataSource {
  @override
  Future<List<TotalCostsBySeasonModel>> getTotalCostsBySeason() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching total costs by season');
      final response = await FarmDataService.getTotalCostsBySeason();

      appLogger.debug(
        LogCategory.http,
        'Total Costs by Season API Response Status: ${response.statusCode}',
      );
      appLogger.debug(
        LogCategory.http,
        'Total Costs by Season API Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<TotalCostsBySeasonModel> totalCosts = items
            .map((item) => TotalCostsBySeasonModel.fromJson(item))
            .toList();

        appLogger.info(
          LogCategory.farm,
          'Successfully fetched ${totalCosts.length} total costs by season',
        );
        return totalCosts;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        appLogger.warning(
          LogCategory.auth,
          'Authentication required for total costs by season',
        );
        throw ServerException('Authentication required. Please log in again.');
      } else {
        String errorMsg =
            'Failed to load total costs by season (Status: ${response.statusCode})';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'].toString();
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
      final response = await FarmDataService.getCostBreakdownByInputType();

      appLogger.debug(
        LogCategory.http,
        'Cost Breakdown API Response Status: ${response.statusCode}',
      );
      appLogger.debug(
        LogCategory.http,
        'Cost Breakdown API Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<CostBreakdownModel> breakdowns = items
            .map((item) => CostBreakdownModel.fromJson(item))
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
        throw ServerException('Authentication required. Please log in again.');
      } else {
        String errorMsg =
            'Failed to load cost breakdown (Status: ${response.statusCode})';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'].toString();
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
  Future<List<AnnualCostSummaryModel>> getAnnualCostSummary() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching annual cost summary');
      final response = await FarmDataService.getAnnualCostSummary();

      appLogger.debug(
        LogCategory.http,
        'Annual Cost Summary API Response Status: ${response.statusCode}',
      );
      appLogger.debug(
        LogCategory.http,
        'Annual Cost Summary API Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<AnnualCostSummaryModel> summaries = items
            .map((item) => AnnualCostSummaryModel.fromJson(item))
            .toList();

        appLogger.info(
          LogCategory.farm,
          'Successfully fetched ${summaries.length} annual cost summaries',
        );
        return summaries;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        appLogger.warning(
          LogCategory.auth,
          'Authentication required for annual cost summary',
        );
        throw ServerException('Authentication required. Please log in again.');
      } else {
        String errorMsg =
            'Failed to load annual cost summary (Status: ${response.statusCode})';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'].toString();
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
