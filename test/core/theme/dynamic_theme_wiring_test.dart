import 'package:dynamic_color/dynamic_color.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'falls back to AppColors schemes when the OS has no dynamic color to offer',
    (tester) async {
      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp(
              theme: AppTheme.getLightTheme(
                lightDynamic ?? AppColors.lightColorScheme,
              ),
              darkTheme: AppTheme.getDarkTheme(
                darkDynamic ?? AppColors.darkColorScheme,
              ),
              home: const Scaffold(body: SizedBox()),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(materialApp.theme!.colorScheme, AppColors.lightColorScheme);
      expect(materialApp.darkTheme!.colorScheme, AppColors.darkColorScheme);
    },
  );
}
