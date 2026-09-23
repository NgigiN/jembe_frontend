import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:flutter/material.dart';

/// How a feed entry is drawn: its icon, the colour family that icon takes,
/// and the word in the Type column.
typedef FeedEntryLook = ({IconData icon, EntryCategory category, String type});

/// Maps the feed's `entity_type` to its look.
///
/// The mockups vary the icon by what the entry is *about* — a droplet for
/// milking, a bag for feed. The feed endpoint sends only the entity type,
/// so this maps from what the server actually says rather than guessing at
/// the summary's wording. An unrecognised type gets a neutral note icon
/// rather than nothing, for the same reason [FarmRole.fromWire] falls back
/// instead of throwing: a future entity type must not blank out the table.
FeedEntryLook lookOf(String entityType) => switch (entityType) {
  'activity' => (
    icon: Icons.grass_outlined,
    category: EntryCategory.plant,
    type: 'Activity',
  ),
  'harvest' => (
    icon: Icons.agriculture_outlined,
    category: EntryCategory.plant,
    type: 'Harvest',
  ),
  'input' => (
    icon: Icons.inventory_2_outlined,
    category: EntryCategory.money,
    type: 'Input',
  ),
  'revenue' => (
    icon: Icons.sell_outlined,
    category: EntryCategory.money,
    type: 'Revenue',
  ),
  'herd_activity' => (
    icon: Icons.water_drop_outlined,
    category: EntryCategory.animal,
    type: 'Herd activity',
  ),
  _ => (
    icon: Icons.notes_outlined,
    category: EntryCategory.money,
    type: _titleCase(entityType),
  ),
};

/// "Former member" when the account that logged an entry is gone — the
/// entry itself survives, so the column must say something (DESIGN_SPEC §7).
String loggedByName(FeedEntry entry) {
  final first = entry.loggedByFirstName;
  if (first == null) return 'Former member';
  return '$first ${entry.loggedByLastName ?? ''}'.trim();
}

String _titleCase(String value) {
  final words = value.replaceAll('_', ' ').trim();
  if (words.isEmpty) return 'Entry';
  return words[0].toUpperCase() + words.substring(1);
}
