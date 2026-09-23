import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// The surface/text tokens the web console needs beyond M3's own roles
/// (DESIGN_SPEC §1). Registered as a [ThemeExtension] for the same reason
/// [StatusColors] is: the values flip with brightness, so reading them off
/// the theme is what makes dark mode fall out of the light-mode code
/// instead of being a second implementation.
@immutable
class ConsoleColors extends ThemeExtension<ConsoleColors> {
  const ConsoleColors({
    required this.ground,
    required this.surfaceLow,
    required this.container,
    required this.onSurface2,
    required this.muted,
    required this.outline,
    required this.negativeContainer,
    required this.deep,
    required this.plant,
    required this.plantContainer,
    required this.animal,
    required this.animalContainer,
  });

  /// The light-theme token set, straight from DESIGN_SPEC §1.
  const ConsoleColors.light()
    : ground = AppColors.groundLight,
      surfaceLow = AppColors.surfaceLowLight,
      container = AppColors.surfaceContainerLight,
      onSurface2 = AppColors.onSurface2Light,
      muted = AppColors.mutedLight,
      outline = AppColors.outlineLight,
      negativeContainer = AppColors.negativeContainerLight,
      deep = AppColors.deep,
      plant = AppColors.plantCategory,
      plantContainer = AppColors.plantCategoryLight,
      animal = AppColors.animalCategory,
      animalContainer = AppColors.animalCategoryLight;

  /// The dark-theme token set (DESIGN_SPEC §1, "Color — dark").
  const ConsoleColors.dark()
    : ground = AppColors.groundDark,
      surfaceLow = AppColors.surfaceLowDark,
      container = AppColors.surfaceContainerDark,
      onSurface2 = AppColors.onSurface2Dark,
      muted = AppColors.mutedDark,
      outline = AppColors.outlineDark,
      negativeContainer = AppColors.negativeContainerDark,
      deep = AppColors.deep,
      plant = AppColors.plantCategoryDark,
      plantContainer = AppColors.plantCategoryDarkContainer,
      animal = AppColors.animalCategoryDark,
      animalContainer = AppColors.animalCategoryDarkContainer;

  /// Page and sidebar floor — the ground a [ColorScheme.surface] card sits on.
  final Color ground;

  /// Tinted rows (pending invite, current farm), quick-log tiles, banners.
  final Color surfaceLow;

  /// Progress-bar track, neutral avatar background, Manager tag background.
  final Color container;

  /// Secondary text; chart "costs" bars at 55% opacity.
  final Color onSurface2;

  /// Labels, table headers, meta text.
  final Color muted;

  /// 1px card / table / input borders.
  final Color outline;

  /// The tile behind the error state's `cloud_off` icon.
  final Color negativeContainer;

  /// Sign-in brand panel only.
  final Color deep;

  final Color plant;
  final Color plantContainer;
  final Color animal;
  final Color animalContainer;

  @override
  ConsoleColors copyWith({
    Color? ground,
    Color? surfaceLow,
    Color? container,
    Color? onSurface2,
    Color? muted,
    Color? outline,
    Color? negativeContainer,
    Color? deep,
    Color? plant,
    Color? plantContainer,
    Color? animal,
    Color? animalContainer,
  }) {
    return ConsoleColors(
      ground: ground ?? this.ground,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      container: container ?? this.container,
      onSurface2: onSurface2 ?? this.onSurface2,
      muted: muted ?? this.muted,
      outline: outline ?? this.outline,
      negativeContainer: negativeContainer ?? this.negativeContainer,
      deep: deep ?? this.deep,
      plant: plant ?? this.plant,
      plantContainer: plantContainer ?? this.plantContainer,
      animal: animal ?? this.animal,
      animalContainer: animalContainer ?? this.animalContainer,
    );
  }

  @override
  ConsoleColors lerp(ThemeExtension<ConsoleColors>? other, double t) {
    if (other is! ConsoleColors) return this;
    return ConsoleColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      container: Color.lerp(container, other.container, t)!,
      onSurface2: Color.lerp(onSurface2, other.onSurface2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      negativeContainer: Color.lerp(
        negativeContainer,
        other.negativeContainer,
        t,
      )!,
      deep: Color.lerp(deep, other.deep, t)!,
      plant: Color.lerp(plant, other.plant, t)!,
      plantContainer: Color.lerp(plantContainer, other.plantContainer, t)!,
      animal: Color.lerp(animal, other.animal, t)!,
      animalContainer: Color.lerp(animalContainer, other.animalContainer, t)!,
    );
  }
}

extension ConsoleColorsX on BuildContext {
  /// Falls back to the brightness-appropriate default when no
  /// [ConsoleColors] is registered — same reasoning as [StatusColors]'
  /// own fallback: widget tests routinely build a bare MaterialApp with
  /// no theme, and a console widget must render there rather than crash.
  ConsoleColors get console {
    final theme = Theme.of(this);
    return theme.extension<ConsoleColors>() ??
        (theme.brightness == Brightness.dark
            ? const ConsoleColors.dark()
            : const ConsoleColors.light());
  }
}
