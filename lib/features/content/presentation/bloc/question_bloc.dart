import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/content/domain/repositories/question_repository.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class QuestionBloc extends Bloc<QuestionEvent, QuestionState> {
  QuestionBloc({required this.repository}) : super(QuestionInitial()) {
    on<GetQuestionsEvent>((event, emit) async {
      emit(QuestionLoading(questions: state.questions));
      final result = await repository.getQuestions();
      result.fold(
        (failure) => emit(
          QuestionError(
            resolveFailureMessage(failure, 'Failed to load questions'),
            questions: state.questions,
          ),
        ),
        (questions) => emit(QuestionLoaded(questions: questions)),
      );
    });

    on<SubmitQuestionEvent>((event, emit) async {
      final current = state.questions;
      emit(QuestionLoading(questions: current));
      final result = await repository.submitQuestion(event.questionText);
      result.fold(
        (failure) => emit(
          QuestionError(
            resolveFailureMessage(failure, 'Failed to submit question'),
            questions: current,
          ),
        ),
        (question) {
          final updated = [question, ...current];
          emit(QuestionLoaded(questions: updated, successMessage: 'Question submitted'));
        },
      );
    });
  }

  final QuestionRepository repository;
}
