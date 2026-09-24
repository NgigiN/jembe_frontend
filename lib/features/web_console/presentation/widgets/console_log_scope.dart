import 'package:farm_tracker/features/web_console/data/console_log_service.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

/// Makes the console's write path reachable from any page without every
/// page taking it as a parameter — the same reason [Theme] is inherited
/// rather than threaded.
///
/// Deliberately optional: [of] returns null when no scope is installed,
/// and a log button falls back to explaining that logging lives in the
/// Android app. That is what keeps the pure page views renderable in the
/// preview harness and in widget tests, neither of which has a server.
class ConsoleLogScope extends InheritedWidget {
  const ConsoleLogScope({
    required this.service,
    required this.onLogged,
    required super.child,
    super.key,
  });

  final LogWriter service;

  /// Called after something is created, so the page you are looking at
  /// picks the new row up without a reload.
  final VoidCallback onLogged;

  static ConsoleLogScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ConsoleLogScope>();
  }

  @override
  bool updateShouldNotify(ConsoleLogScope oldWidget) =>
      service != oldWidget.service || onLogged != oldWidget.onLogged;
}
