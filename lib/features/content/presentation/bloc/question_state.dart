import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';

abstract class QuestionState extends Equatable {
  const QuestionState({this.questions = const []});
  final List<Question> questions;

  @override
  List<Object?> get props => [questions];
}

class QuestionInitial extends QuestionState {}

class QuestionLoading extends QuestionState {
  const QuestionLoading({super.questions});
}

class QuestionLoaded extends QuestionState {
  const QuestionLoaded({required super.questions, this.successMessage});
  final String? successMessage;

  @override
  List<Object?> get props => [questions, successMessage];
}

class QuestionError extends QuestionState {
  const QuestionError(this.message, {super.questions});
  final String message;

  @override
  List<Object> get props => [message, questions];
}
