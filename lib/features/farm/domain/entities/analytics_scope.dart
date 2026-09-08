import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

enum ScopeSource { plant, animal }

/// What an analytics view or the revenue list is narrowed to. Mirrors the
/// backend `validation.Scope` contract exactly (spec 2026-09-08 §3.1):
///   all      → no params
///   source   → ?source=plant|animal
///   land     → ?source=plant&land_id=N   (every season on that land)
///   herd     → ?source=animal&herd_id=N
class AnalyticsScope extends Equatable {
  const AnalyticsScope._({this.source, this.landId, this.herdId});
  const AnalyticsScope.all() : this._();
  const AnalyticsScope.source(ScopeSource source) : this._(source: source);
  const AnalyticsScope.land(String landId)
    : this._(source: ScopeSource.plant, landId: landId);
  const AnalyticsScope.herd(String herdId)
    : this._(source: ScopeSource.animal, herdId: herdId);

  final ScopeSource? source;
  final String? landId;
  final String? herdId;

  bool get isFarmWide => source == null;
  bool get hasEnterprise => landId != null || herdId != null;

  String? get sourceParam => switch (source) {
    null => null,
    ScopeSource.plant => 'plant',
    ScopeSource.animal => 'animal',
  };

  Map<String, String> toQueryParams() => {
    if (sourceParam != null) 'source': sourceParam!,
    if (landId != null) 'land_id': landId!,
    if (herdId != null) 'herd_id': herdId!,
  };

  /// In-memory equivalent of the server predicate, used only by the dark
  /// offline revenue path. A land scope cannot be resolved from a revenue
  /// row alone (rows carry the season id), so the caller supplies the
  /// season ids on that land; an empty set matches nothing, never everything.
  bool matchesRevenue(Revenue r, {Set<String> seasonIdsOnLand = const {}}) {
    if (sourceParam != null && r.source != sourceParam) return false;
    if (herdId != null && r.sourceId != herdId) return false;
    if (landId != null && !seasonIdsOnLand.contains(r.sourceId)) return false;
    return true;
  }

  @override
  List<Object?> get props => [source, landId, herdId];
}
