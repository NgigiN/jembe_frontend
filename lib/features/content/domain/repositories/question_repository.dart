import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';

abstract class QuestionRepository {
  Future<Either<Failure, Question>> submitQuestion(String questionText);
  Future<Either<Failure, List<Question>>> getQuestions();
}
