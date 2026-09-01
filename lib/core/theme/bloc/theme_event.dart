import 'package:flutter/material.dart';

abstract class ThemeEvent {}

/// Loads the persisted theme preference, if any. Dispatched once from
/// ThemeBloc's constructor so the app's initial system default is replaced
/// by whatever the user last chose.
class LoadThemeEvent extends ThemeEvent {}

class SetThemeModeEvent extends ThemeEvent {
  SetThemeModeEvent(this.mode);
  final ThemeMode mode;
}
