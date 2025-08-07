import 'dart:convert';
import 'package:farm_tracker/features/farm/data/models/total_costs_by_season_model.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';
import 'package:farm_tracker/features/farm/data/models/annual_cost_summary_model.dart';
import '../../../../core/error/exceptions.dart';
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
      final response = await FarmDataService.getTotalCostsBySeason();
      print(
        'Total Costs by Season API Response Status: ${response.statusCode}',
      );
      print('Total Costs by Season API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<TotalCostsBySeasonModel> totalCosts = items
            .map((item) => TotalCostsBySeasonModel.fromJson(item))
            .toList();

        print('Found ${totalCosts.length} total costs by season');
        return totalCosts;
      } else {
        throw ServerException('Failed to load total costs by season');
      }
    } catch (e) {
      print('Error fetching total costs by season: $e');
      throw ServerException('Failed to load total costs by season: $e');
    }
  }

  @override
  Future<List<CostBreakdownModel>> getCostBreakdownByInputType() async {
    try {
      final response = await FarmDataService.getCostBreakdownByInputType();
      print('Cost Breakdown API Response Status: ${response.statusCode}');
      print('Cost Breakdown API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<CostBreakdownModel> breakdowns = items
            .map((item) => CostBreakdownModel.fromJson(item))
            .toList();

        print('Found ${breakdowns.length} cost breakdowns');
        return breakdowns;
      } else {
        throw ServerException('Failed to load cost breakdown');
      }
    } catch (e) {
      print('Error fetching cost breakdown: $e');
      throw ServerException('Failed to load cost breakdown: $e');
    }
  }

  @override
  Future<List<AnnualCostSummaryModel>> getAnnualCostSummary() async {
    try {
      final response = await FarmDataService.getAnnualCostSummary();
      print('Annual Cost Summary API Response Status: ${response.statusCode}');
      print('Annual Cost Summary API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'];

        final List<AnnualCostSummaryModel> summaries = items
            .map((item) => AnnualCostSummaryModel.fromJson(item))
            .toList();

        print('Found ${summaries.length} annual cost summaries');
        return summaries;
      } else {
        throw ServerException('Failed to load annual cost summary');
      }
    } catch (e) {
      print('Error fetching annual cost summary: $e');
      throw ServerException('Failed to load annual cost summary: $e');
    }
  }
}
