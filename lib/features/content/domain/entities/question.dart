import 'package:equatable/equatable.dart';

class Question extends Equatable {
  const Question({
    required this.id,
    required this.questionText,
    required this.status,
    required this.createdAt,
    this.answerText,
    this.answeredAt,
  });

  final String id;
  final String questionText;
  final String status;
  final DateTime createdAt;
  final String? answerText;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  @override
  List<Object?> get props => [
    id,
    questionText,
    status,
    createdAt,
    answerText,
    answeredAt,
  ];
}
