import 'package:flutter/material.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';

/// Navigator observer for GoRouter that logs all navigation events
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

/// GoRouter observer that logs navigation events
class LoggingGoRouterObserver extends NavigatorObserver {
  final AppLogger _logger = appLogger;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation('PUSH', previousRoute, route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation('POP', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logNavigation('REPLACE', oldRoute, newRoute);
  }

  void _logNavigation(String action, Route<dynamic>? from, Route<dynamic>? to) {
    final fromName = from?.settings.name ?? 'unknown';
    final toName = to?.settings.name ?? 'unknown';
    final args = to?.settings.arguments;
    final argsStr = args != null ? ' with args: $args' : '';

    _logger.info(
      LogCategory.navigation,
      'Navigation $action: $fromName -> $toName$argsStr',
    );
  }
}

/// Legacy MaterialApp wrapper - deprecated, use GoRouter instead
@Deprecated('Use GoRouter from app_router.dart instead')
class LoggingMaterialApp extends StatelessWidget {
  const LoggingMaterialApp({
    super.key,
    required this.title,
    this.theme,
    this.initialRoute,
    this.routes,
    this.home,
    this.navigatorObservers,
    this.debugShowCheckedModeBanner = true,
  });
  final String title;
  final ThemeData? theme;
  final String? initialRoute;
  final Map<String, WidgetBuilder>? routes;
  final Widget? home;
  final List<NavigatorObserver>? navigatorObservers;
  final bool debugShowCheckedModeBanner;

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
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }
}
