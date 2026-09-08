import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:flutter/material.dart';

/// THE filter control for analytics and revenue (RULES §8: replaces the old
/// `EnterprisePicker` sheet). Two tiers, both rendered from [scope]:
///
///   tier 1  All · Plants · Animals
///   tier 2  (conditional) lands under Plants, herds under Animals — active
///           herds first, then an `Ended (n)` chip revealing ended herds.
///
/// Stateless with respect to selection: every tap calls [onChanged] with the
/// next [AnalyticsScope]; the owner (a bloc or page) is the source of truth.
/// Reads no blocs itself — pages pass [lands]/[herds] in — so it tests in
/// isolation.
class ScopeChips extends StatefulWidget {
  const ScopeChips({
    required this.scope,
    required this.onChanged,
    required this.lands,
    required this.herds,
    super.key,
  });

  final AnalyticsScope scope;
  final ValueChanged<AnalyticsScope> onChanged;
  final List<Land> lands;
  final List<Herd> herds;

  @override
  State<ScopeChips> createState() => _ScopeChipsState();
}

class _ScopeChipsState extends State<ScopeChips> {
  bool _showEnded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tierOne(context),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: widget.scope.isFarmWide
              ? const SizedBox.shrink()
              : _tierTwo(context),
        ),
      ],
    );
  }

  Widget _tierOne(BuildContext context) {
    final s = widget.scope;
    return Row(
      children: [
        _chip(
          context,
          'All',
          selected: s.isFarmWide,
          onTap: () => widget.onChanged(const AnalyticsScope.all()),
        ),
        const SizedBox(width: 8),
        _chip(
          context,
          'Plants',
          icon: Icons.grass,
          color: AppColors.plantCategory,
          selected: s.source == ScopeSource.plant,
          onTap: () =>
              widget.onChanged(const AnalyticsScope.source(ScopeSource.plant)),
        ),
        const SizedBox(width: 8),
        _chip(
          context,
          'Animals',
          icon: Icons.pets,
          color: AppColors.animalCategory,
          selected: s.source == ScopeSource.animal,
          onTap: () =>
              widget.onChanged(const AnalyticsScope.source(ScopeSource.animal)),
        ),
      ],
    );
  }

  Widget _tierTwo(BuildContext context) {
    final s = widget.scope;
    final List<Widget> chips;
    if (s.source == ScopeSource.plant) {
      final lands = [...widget.lands]..sort((a, b) => a.name.compareTo(b.name));
      if (lands.isEmpty) return _hint(context, 'No lands registered yet');
      chips = [
        for (final land in lands)
          _chip(
            context,
            land.name,
            color: AppColors.plantCategory,
            selected: s.landId == land.id,
            onTap: () => widget.onChanged(
              s.landId == land.id
                  ? const AnalyticsScope.source(ScopeSource.plant)
                  : AnalyticsScope.land(land.id),
            ),
          ),
      ];
    } else {
      final now = DateTime.now();
      bool active(Herd h) => h.endDate == null || h.endDate!.isAfter(now);
      final activeHerds = widget.herds.where(active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final ended = widget.herds.where((h) => !active(h)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (activeHerds.isEmpty && ended.isEmpty) {
        return _hint(context, 'No herds registered yet');
      }
      Widget herdChip(Herd h) => _chip(
        context,
        h.name,
        color: AppColors.animalCategory,
        selected: s.herdId == h.id,
        onTap: () => widget.onChanged(
          s.herdId == h.id
              ? const AnalyticsScope.source(ScopeSource.animal)
              : AnalyticsScope.herd(h.id),
        ),
      );
      chips = [
        ...activeHerds.map(herdChip),
        if (ended.isNotEmpty)
          ActionChip(
            avatar: Icon(
              _showEnded ? Icons.expand_less : Icons.history,
              size: 18,
            ),
            label: Text('Ended (${ended.length})'),
            onPressed: () => setState(() => _showEnded = !_showEnded),
          ),
        if (_showEnded) ...ended.map(herdChip),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _chip(
    BuildContext context,
    String label, {
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected ? accent : scheme.onSurfaceVariant,
            ),
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: accent.withValues(alpha: 0.2),
      checkmarkColor: accent,
      labelStyle: TextStyle(
        color: selected ? accent : scheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
