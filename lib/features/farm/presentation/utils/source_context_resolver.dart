import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

String seasonName(List<Season> seasons, String seasonId) {
  for (final season in seasons) {
    if (season.id == seasonId) return season.name;
  }
  return 'Unknown season';
}

String landName(List<Land> lands, String landId) {
  for (final land in lands) {
    if (land.id == landId) {
      final location = land.location ?? '';
      return location.isNotEmpty ? '${land.name} ($location)' : land.name;
    }
  }
  return 'Unknown land';
}

String landNameForSeason(List<Season> seasons, List<Land> lands, String seasonId) {
  for (final season in seasons) {
    if (season.id == seasonId) {
      return landName(lands, season.landId);
    }
  }
  return 'Unknown land';
}

String seasonDropdownLabel(Season season, List<Land> lands) {
  return '${season.name} — ${landName(lands, season.landId)}';
}

String herdName(List<Herd> herds, String herdId) {
  for (final herd in herds) {
    if (herd.id == herdId) {
      return '${herd.name} (${herd.location})';
    }
  }
  return 'Unknown herd';
}