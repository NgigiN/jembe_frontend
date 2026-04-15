import 'dart:convert';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/annual_cost_summary_model.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../services/farm_data_service.dart';

abstract class AnalysisRemoteDataSource {
  Future<FarmDetailedCostModel> getTotalCostsBySeason();
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType();
  Future<List<AnnualCostSummaryModel>> getAnnualCostSummary();
}

class AnalysisRemoteDataSourceImpl implements AnalysisRemoteDataSource {
  @override
  Future<FarmDetailedCostModel> getTotalCostsBySeason() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching unified total costs');
      final response = await FarmDataService.getTotalCosts();

      appLogger.debug(
        LogCategory.http,
        'Unified Total Costs API Response Status: ${response.statusCode}',
      );
      appLogger.debug(
        LogCategory.http,
        'Unified Total Costs API Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = FarmDetailedCostModel.fromJson(data);

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
        final List<CostBreakdownModel> breakdowns = [];

        if (data is List) {
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              breakdowns.add(
                CostBreakdownModel(
                  seasonId: '',
                  seasonName: '',
                  cropName: '',
                  landName: '',
                  inputType: (item['Type'] ?? item['type'] ?? '').toString(),
                  farmName: '',
                  inputCost: ((item['TotalCost'] ??
                              item['total_cost'] ??
                              item['amount'] ??
                              0.0) as num)
                          .toDouble(),
                  percentage: ((item['Percentage'] ?? item['percentage'] ?? 0.0) as num)
                      .toDouble(),
                  category: (item['Category'] ?? item['category'] ?? '').toString(),
                ),
              );
            }
          }
        } else if (data is Map) {
          final byCategory = data['by_category'] as Map<String, dynamic>? ?? {};
          if (byCategory['inputs'] != null) {
            final inputs = byCategory['inputs'] as Map<String, dynamic>;
            final items = (inputs['items'] as List<dynamic>?) ?? [];
            for (var item in items) {
              if (item is! Map<String, dynamic>) continue;
              breakdowns.add(
                CostBreakdownModel(
                  seasonId: '',
                  seasonName: '',
                  cropName: '',
                  landName: '',
                  inputType: (item['type'] ?? '').toString(),
                  farmName: '',
                  inputCost: ((item['amount'] ?? 0.0) as num).toDouble(),
                  percentage:
                      ((item['amount'] ?? 0.0) as num).toDouble() /
                      ((inputs['total'] ?? 1.0) as num).toDouble() *
                      100,
                  category: (item['category'] ?? '').toString(),
                ),
              );
            }
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
      final response = await FarmDataService.getMonthlySummary(
        year: currentYear,
      );

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
        final List<AnnualCostSummaryModel> summaries = [];

        if (data is List) {
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              String year = currentYear.toString();
              if (item['Month'] != null) {
                final monthStr = item['Month'].toString();
                if (monthStr.contains('-')) {
                  year = monthStr.split('-')[0];
                }
              }
              summaries.add(
                AnnualCostSummaryModel(
                  year: year,
                  cropName: '',
                  landName: '',
                  farmName: '',
                  totalCost:
                      ((item['TotalCosts'] ??
                              item['total_costs'] ??
                              item['costs'] ??
                              0.0) as num)
                          .toDouble(),
                ),
              );
            }
          }
        } else if (data is Map) {
          final monthlyData = (data['monthly_data'] as List<dynamic>?) ?? [];
          summaries.addAll(
            monthlyData
                .map<AnnualCostSummaryModel>(
                  (item) {
                    if (item is! Map<String, dynamic>) {
                      return AnnualCostSummaryModel(
                        year: currentYear.toString(),
                        cropName: '',
                        landName: '',
                        farmName: '',
                        totalCost: 0.0,
                      );
                    }
                    return AnnualCostSummaryModel(
                      year: currentYear.toString(),
                      cropName: '',
                      landName: '',
                      farmName: '',
                      totalCost: ((item['costs'] ?? 0.0) as num).toDouble(),
                    );
                  },
                )
                .toList(),
          );
        }

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
