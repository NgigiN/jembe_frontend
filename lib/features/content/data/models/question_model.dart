import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.questionText,
    required super.status,
    required super.createdAt,
    super.answerText,
    super.answeredAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      questionText: (json['question_text'] ?? '').toString(),
      status: (json['status'] ?? 'unanswered').toString(),
      answerText: json['answer_text']?.toString(),
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'].toString())
          : null,
      createdAt: parseDate(dualKey(json, 'created_at')),
    );
  }
}
