import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system theme before any preference loads', () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = ThemeBloc();
    expect(bloc.state.themeMode, ThemeMode.system);
    await bloc.close();
  });

  test('loads system mode when no preference is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = ThemeBloc();
    await pumpEventQueue();
    expect(bloc.state.themeMode, ThemeMode.system);
    await bloc.close();
  });

  test('loads a previously stored light preference', () async {
    SharedPreferences.setMockInitialValues({themeModePrefsKey: 'light'});
    final bloc = ThemeBloc();
    await pumpEventQueue();
    expect(bloc.state.themeMode, ThemeMode.light);
    await bloc.close();
  });

  test('loads a previously stored dark preference', () async {
    SharedPreferences.setMockInitialValues({themeModePrefsKey: 'dark'});
    final bloc = ThemeBloc();
    await pumpEventQueue();
    expect(bloc.state.themeMode, ThemeMode.dark);
    await bloc.close();
  });

  test('SetThemeModeEvent updates state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = ThemeBloc();
    await pumpEventQueue();

    bloc.add(SetThemeModeEvent(ThemeMode.dark));
    await pumpEventQueue();

    expect(bloc.state.themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeModePrefsKey), 'dark');
    await bloc.close();
  });

  test('SetThemeModeEvent can switch back to system and persists it', () async {
    SharedPreferences.setMockInitialValues({themeModePrefsKey: 'dark'});
    final bloc = ThemeBloc();
    await pumpEventQueue();
    expect(bloc.state.themeMode, ThemeMode.dark);

    bloc.add(SetThemeModeEvent(ThemeMode.system));
    await pumpEventQueue();

    expect(bloc.state.themeMode, ThemeMode.system);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeModePrefsKey), 'system');
    await bloc.close();
  });
}
