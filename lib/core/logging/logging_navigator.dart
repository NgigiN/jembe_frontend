import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

class LoggingNavigatorObserver extends NavigatorObserver {
  final AppLogger _logger = appLogger;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange(
      'PUSH',
      previousRoute?.settings.name,
      route.settings.name,
      route.settings.arguments,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange(
      'POP',
      route.settings.name,
      previousRoute?.settings.name,
      route.settings.arguments,
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRouteChange(
      'REPLACE',
      oldRoute?.settings.name,
      newRoute?.settings.name,
      newRoute?.settings.arguments,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRouteChange(
      'REMOVE',
      route.settings.name,
      previousRoute?.settings.name,
      route.settings.arguments,
    );
  }

  void _logRouteChange(
    String action,
    String? from,
    String? to,
    dynamic arguments,
  ) {
    final fromStr = from ?? 'unknown';
    final toStr = to ?? 'unknown';
    final argsStr = arguments != null ? ' with args: $arguments' : '';

    _logger.info(
      LogCategory.navigation,
      'Navigation $action: $fromStr -> $toStr$argsStr',
    );
  }
}

class LoggingMaterialApp extends StatelessWidget {
  final String title;
  final ThemeData? theme;
  final String? initialRoute;
  final Map<String, WidgetBuilder>? routes;
  final Widget? home;
  final List<NavigatorObserver>? navigatorObservers;

  const LoggingMaterialApp({
    super.key,
    required this.title,
    this.theme,
    this.initialRoute,
    this.routes,
    this.home,
    this.navigatorObservers,
  });

  @override
  Widget build(BuildContext context) {
    final observers = <NavigatorObserver>[
      LoggingNavigatorObserver(),
      ...?navigatorObservers,
    ];

    return MaterialApp(
      title: title,
      theme: theme,
      initialRoute: initialRoute,
      routes: routes ?? {},
      home: home,
      navigatorObservers: observers,
    );
  }
}
