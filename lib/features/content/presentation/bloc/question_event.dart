import 'package:equatable/equatable.dart';

abstract class QuestionEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetQuestionsEvent extends QuestionEvent {}

class SubmitQuestionEvent extends QuestionEvent {
  SubmitQuestionEvent(this.questionText);
  final String questionText;

  @override
  List<Object> get props => [questionText];
}
