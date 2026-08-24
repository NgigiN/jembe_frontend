import 'package:farm_tracker/features/content/domain/repositories/content_repository.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ContentBloc extends Bloc<ContentEvent, ContentState> {
  ContentBloc({required this.repository}) : super(ContentInitial()) {
    on<GetAllContentEvent>((event, emit) async {
      emit(const ContentLoading());
      final items = await repository.getAll();
      emit(ContentLoaded(items: items));
    });
  }

  final ContentRepository repository;
}
