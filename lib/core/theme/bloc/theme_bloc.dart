import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    on<ToggleThemeEvent>((event, emit) {
      final newMode = state.themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
      emit(ThemeState(themeMode: newMode));
    });

    on<SetThemeEvent>((event, emit) {
      final newMode = event.isDark ? ThemeMode.dark : ThemeMode.light;
      emit(ThemeState(themeMode: newMode));
    });
  }
}
