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
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue is String) return DateTime.parse(dateValue);
    return DateTime.now();
  }
}
