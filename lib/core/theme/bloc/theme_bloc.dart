import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModePrefsKey = 'theme_mode';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(ThemeState.initial()) {
    on<LoadThemeEvent>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(themeModePrefsKey);
      final mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => ThemeMode.system,
      );
      emit(ThemeState(themeMode: mode));
    });

    on<SetThemeModeEvent>((event, emit) async {
      emit(ThemeState(themeMode: event.mode));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModePrefsKey, event.mode.name);
    });

    add(LoadThemeEvent());
  }
}
