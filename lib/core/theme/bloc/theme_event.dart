abstract class ThemeEvent {}

class ToggleThemeEvent extends ThemeEvent {}

class SetThemeEvent extends ThemeEvent {
  SetThemeEvent(this.isDark);
  final bool isDark;
}
