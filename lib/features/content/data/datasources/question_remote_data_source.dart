import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/content/data/models/question_model.dart';

abstract class QuestionRemoteDataSource {
  Future<QuestionModel> submitQuestion(String questionText);
  Future<List<QuestionModel>> getQuestions();
}

class QuestionRemoteDataSourceImpl implements QuestionRemoteDataSource {
  QuestionRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<QuestionModel> submitQuestion(String questionText) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/questions',
        data: {'question_text': questionText},
      );
      if (response.statusCode == 201) {
        return QuestionModel.fromJson(response.data as Map<String, dynamic>);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<List<QuestionModel>> getQuestions() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/questions');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map(
                (json) => QuestionModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
        return [];
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }
}
