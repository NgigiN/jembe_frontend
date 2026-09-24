import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_text.dart';
import 'package:flutter/material.dart';

/// One sidebar destination.
class ConsoleNavItem {
  const ConsoleNavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.staffOnly = false,
  });

  final String route;
  final String label;
  final IconData icon;

  /// The filled variant. Only the active item is filled (DESIGN_SPEC §1).
  final IconData activeIcon;

  /// Hidden entirely from workers — §5 is explicit that restricted items
  /// are absent, not greyed.
  final bool staffOnly;
}

/// The console's navigation (DESIGN_SPEC §2).
///
/// Two groups: the four working destinations, then a "FARM" group for the
/// things you visit occasionally. The grouping is why this isn't an
/// `adaptive_scaffold_plus` destination list — that's a flat set, and
/// flattening these seven would lose the distinction at exactly the widths
/// where there's still room to show it.
abstract final class ConsoleNav {
  static const List<ConsoleNavItem> main = [
    ConsoleNavItem(
      route: WebRoutePath.dashboard,
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard,
      staffOnly: true,
    ),
    ConsoleNavItem(
      route: WebRoutePath.feed,
      label: 'Feed',
      icon: Icons.dynamic_feed_outlined,
      activeIcon: Icons.dynamic_feed,
    ),
    ConsoleNavItem(
      route: WebRoutePath.reports,
      label: 'Reports',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      staffOnly: true,
    ),
    ConsoleNavItem(
      route: WebRoutePath.members,
      label: 'Members',
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
    ),
  ];

  static const List<ConsoleNavItem> farm = [
    ConsoleNavItem(
      route: WebRoutePath.farmsList,
      label: 'Farms',
      icon: Icons.holiday_village_outlined,
      activeIcon: Icons.holiday_village,
    ),
    ConsoleNavItem(
      route: WebRoutePath.trash,
      label: 'Trash',
      icon: Icons.delete_outline,
      activeIcon: Icons.delete,
      staffOnly: true,
    ),
    ConsoleNavItem(
      route: WebRoutePath.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  /// Filters a group for [role]. A null role (farms still loading) is
  /// treated as staff so the nav doesn't visibly shrink once the role
  /// arrives; the router's own staff-only redirect is the real gate.
  static List<ConsoleNavItem> visible(
    List<ConsoleNavItem> items,
    FarmRole? role,
  ) {
    if (role == null || role.isStaff) return items;
    return items.where((item) => !item.staffOnly).toList();
  }

  /// The route whose item should read as active for [location]. Longest
  /// match wins, so `/farms/create` lights up Farms rather than nothing.
  static String? activeRoute(String location) {
    String? best;
    for (final item in [...main, ...farm]) {
      if (location.startsWith(item.route) &&
          (best == null || item.route.length > best.length)) {
        best = item.route;
      }
    }
    return best;
  }
}

/// The 232px sidebar (DESIGN_SPEC §2). Passing `compact: true` gives the
/// 72px icons-only form of the same thing.
class ConsoleSidebar extends StatelessWidget {
  const ConsoleSidebar({
    required this.location,
    required this.role,
    required this.farmName,
    required this.userName,
    required this.userEmail,
    required this.onNavigate,
    required this.onSignOut,
    required this.onSwitchFarm,
    this.compact = false,
    super.key,
  });

  final String location;
  final FarmRole? role;
  final String? farmName;
  final String userName;
  final String userEmail;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;
  final VoidCallback onSwitchFarm;

  /// Icons only, 72px wide — the medium breakpoint.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final active = ConsoleNav.activeRoute(location);
    final main = ConsoleNav.visible(ConsoleNav.main, role);
    final farm = ConsoleNav.visible(ConsoleNav.farm, role);

    return Container(
      width: compact ? 72 : ConsoleMetrics.sidebarWidth,
      decoration: BoxDecoration(
        color: console.ground,
        border: Border(right: BorderSide(color: console.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 18, 16, 0),
            child: _Brand(compact: compact),
          ),
          const SizedBox(height: 16),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _FarmSwitcher(
                farmName: farmName,
                userName: userName,
                role: role,
                onTap: onSwitchFarm,
              ),
            ),
          if (!compact) const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in main)
                    _NavTile(
                      item: item,
                      active: item.route == active,
                      compact: compact,
                      onTap: () => onNavigate(item.route),
                    ),
                  if (farm.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    if (compact)
                      Divider(color: console.outline, height: 1)
                    else
                      const Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 8),
                        child: ConsoleKicker('Farm'),
                      ),
                    if (compact) const SizedBox(height: 10),
                    for (final item in farm)
                      _NavTile(
                        item: item,
                        active: item.route == active,
                        compact: compact,
                        onTap: () => onNavigate(item.route),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: console.outline)),
            ),
            padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 12, 10, 14),
            child: _Footer(
              name: userName,
              email: userEmail,
              compact: compact,
              onSignOut: onSignOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.eco, size: 18, color: scheme.onPrimary),
    );

    if (compact) return Center(child: mark);

    return Row(
      children: [
        mark,
        const SizedBox(width: 10),
        // The "+" carries the brand colour on its own — the wordmark is
        // one word, not two styled halves.
        Text.rich(
          TextSpan(
            style: AppTypography.wordmark.copyWith(color: scheme.onSurface),
            children: [
              const TextSpan(text: 'Shamba'),
              TextSpan(text: '+', style: TextStyle(color: scheme.primary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FarmSwitcher extends StatelessWidget {
  const _FarmSwitcher({
    required this.farmName,
    required this.userName,
    required this.role,
    required this.onTap,
  });

  final String? farmName;
  final String userName;
  final FarmRole? role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (userName.isNotEmpty) userName,
      if (role != null) role!.label,
    ].join(' · ');

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
            border: Border.all(color: console.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.agriculture_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Never blank: the farm context has to be readable
                      // at all times (DESIGN_SPEC §2).
                      farmName ?? 'No farm selected',
                      style: AppTypography.navItem.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTypography.tag.copyWith(
                          fontWeight: FontWeight.w400,
                          color: console.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, size: 16, color: console.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final ConsoleNavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;
    final foreground = active ? scheme.onPrimaryContainer : console.onSurface2;

    final content = compact
        ? Center(child: Icon(active ? item.activeIcon : item.icon, size: 20, color: foreground))
        : Row(
            children: [
              const SizedBox(width: 12),
              Icon(active ? item.activeIcon : item.icon, size: 20, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTypography.navItem.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ConsoleMetrics.radiusControl),
          child: SizedBox(height: ConsoleMetrics.navItemHeight, child: content),
        ),
      ),
    );

    return compact ? Tooltip(message: item.label, child: tile) : tile;
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.name,
    required this.email,
    required this.compact,
    required this.onSignOut,
  });

  final String name;
  final String email;
  final bool compact;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final signOut = IconButton(
      onPressed: onSignOut,
      icon: const Icon(Icons.logout, size: 18),
      tooltip: 'Sign out',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
    );

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(name.isEmpty ? '?' : name, size: 30),
          const SizedBox(height: 6),
          signOut,
        ],
      );
    }

    return Row(
      children: [
        InitialsAvatar(name.isEmpty ? '?' : name, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'Signed in' : name,
                style: AppTypography.bodyDense.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: AppTypography.tag.copyWith(
                    fontWeight: FontWeight.w400,
                    color: console.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        signOut,
      ],
    );
  }
}
