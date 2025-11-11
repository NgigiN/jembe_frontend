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
      final response = await FarmDataService.getTotalCosts(type: 'plant');

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
        final totalCosts = data['total_costs']?.toDouble() ?? 0.0;
        final breakdown = data['breakdown'] ?? {};

        final List<TotalCostsBySeasonModel> result = [
          TotalCostsBySeasonModel(
            seasonId: '',
            seasonName: 'Total',
            startDate: DateTime.now(),
            cropName: '',
            landName: '',
            farmName: '',
            totalCost: totalCosts,
          ),
        ];

        appLogger.info(
          LogCategory.farm,
          'Successfully fetched total costs by season',
        );
        return result;
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
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
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
      final response = await FarmDataService.getCostBreakdown(type: 'plant');

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
        final byCategory = data['by_category'] ?? {};
        final List<CostBreakdownModel> breakdowns = [];

        if (byCategory['inputs'] != null) {
          final inputs = byCategory['inputs'];
          final items = inputs['items'] ?? [];
          for (var item in items) {
            breakdowns.add(CostBreakdownModel(
              seasonId: '',
              seasonName: '',
              cropName: '',
              landName: '',
              inputType: item['type'] ?? '',
              farmName: '',
              inputCost: (item['amount'] ?? 0.0).toDouble(),
              percentage: (item['amount'] ?? 0.0).toDouble() /
                  ((inputs['total'] ?? 1.0).toDouble()) * 100,
            ));
          }
        }

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
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
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
      final currentYear = DateTime.now().year;
      final response = await FarmDataService.getMonthlySummary(year: currentYear);

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
        final monthlyData = data['monthly_data'] ?? [];
        final totals = data['totals'] ?? {};

        final List<AnnualCostSummaryModel> summaries = monthlyData
            .map<AnnualCostSummaryModel>((item) => AnnualCostSummaryModel(
              year: currentYear.toString(),
              cropName: '',
              landName: '',
              farmName: '',
              totalCost: (item['costs'] ?? 0.0).toDouble(),
            ))
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
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
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
