import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter/material.dart';

/// A circular initials avatar (DESIGN_SPEC §3): 22px in table rows, 28px
/// in the Members table, 30px in the sidebar footer.
///
/// The owner's avatar is the one that carries `primaryContainer`; everyone
/// else gets the neutral `container` — which is how the Members table says
/// who the owner is without a second badge.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.name, {
    this.size = 22,
    this.emphasised = false,
    super.key,
  });

  final String name;
  final double size;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emphasised ? scheme.primaryContainer : console.container,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: AppTypography.tag.copyWith(
          fontSize: size * 0.38,
          color: emphasised ? scheme.onPrimaryContainer : console.onSurface2,
        ),
      ),
    );
  }
}

/// "Kamau Owner" → "KO"; "Wanjiku" → "WA". Two letters, always — a single
/// initial in a circle reads as a typo.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final only = parts.first;
    return (only.length == 1 ? only : only.substring(0, 2)).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// The role pill (DESIGN_SPEC §4, Members): Owner reads as the brand,
/// Manager as neutral, Worker as the quietest of the three.
class RoleTag extends StatelessWidget {
  const RoleTag(this.role, {this.trailing, super.key});

  final FarmRole role;

  /// The `expand_more` affordance the Members table puts on editable
  /// (non-owner) roles.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;
    final (background, foreground) = switch (role) {
      FarmRole.owner => (scheme.primaryContainer, scheme.onPrimaryContainer),
      FarmRole.manager => (console.container, console.onSurface2),
      FarmRole.worker => (console.surfaceLow, console.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTag),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible so a narrow Role column clips the word rather than
          // overflowing the row it sits in.
          Flexible(
            child: Text(
              role.label,
              style: AppTypography.tag.copyWith(color: foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            IconTheme(
              data: IconThemeData(color: foreground, size: 14),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

extension FarmRoleLabel on FarmRole {
  /// Sentence case, the way the console writes every label (DESIGN_SPEC §7).
  String get label => switch (this) {
    FarmRole.owner => 'Owner',
    FarmRole.manager => 'Manager',
    FarmRole.worker => 'Worker',
  };

  /// The one-phrase permission summary under the Members table's legend.
  String get permissionSummary => switch (this) {
    FarmRole.owner => 'Full control, including ownership transfer',
    FarmRole.manager => 'Sees reports, invites and manages members',
    FarmRole.worker => 'Logs work only, no amounts',
  };
}
