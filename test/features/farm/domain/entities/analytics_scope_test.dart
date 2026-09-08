import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:flutter_test/flutter_test.dart';

Revenue _rev({required String source, required String sourceId}) => Revenue(
  id: 'r',
  userId: 'u',
  source: source,
  sourceId: sourceId,
  type: 't',
  quantity: 1,
  unitPrice: 1,
  total: 1,
  date: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('AnalyticsScope.toQueryParams', () {
    test('all → {}', () {
      expect(const AnalyticsScope.all().toQueryParams(), isEmpty);
      expect(const AnalyticsScope.all().isFarmWide, isTrue);
    });
    test('source → {source}', () {
      expect(const AnalyticsScope.source(ScopeSource.animal).toQueryParams(), {
        'source': 'animal',
      });
    });
    test('land → {source: plant, land_id}', () {
      const s = AnalyticsScope.land('7');
      expect(s.toQueryParams(), {'source': 'plant', 'land_id': '7'});
      expect(s.source, ScopeSource.plant);
      expect(s.hasEnterprise, isTrue);
    });
    test('herd → {source: animal, herd_id}', () {
      expect(const AnalyticsScope.herd('3').toQueryParams(), {
        'source': 'animal',
        'herd_id': '3',
      });
    });
    test('equatable by value', () {
      expect(const AnalyticsScope.land('1'), const AnalyticsScope.land('1'));
      expect(
        const AnalyticsScope.land('1'),
        isNot(const AnalyticsScope.herd('1')),
      );
    });
  });

  group('AnalyticsScope.matchesRevenue (offline in-memory filter)', () {
    final plant = _rev(source: 'plant', sourceId: 's1');
    final animal = _rev(source: 'animal', sourceId: 'h1');
    test('all matches everything', () {
      expect(const AnalyticsScope.all().matchesRevenue(plant), isTrue);
      expect(const AnalyticsScope.all().matchesRevenue(animal), isTrue);
    });
    test('source filters by revenue.source', () {
      const s = AnalyticsScope.source(ScopeSource.plant);
      expect(s.matchesRevenue(plant), isTrue);
      expect(s.matchesRevenue(animal), isFalse);
    });
    test('herd matches sourceId directly', () {
      expect(const AnalyticsScope.herd('h1').matchesRevenue(animal), isTrue);
      expect(const AnalyticsScope.herd('h2').matchesRevenue(animal), isFalse);
      expect(
        const AnalyticsScope.herd('s1').matchesRevenue(plant),
        isFalse,
        reason: 'herd scope never matches a plant revenue',
      );
    });
    test('land matches through the resolved season id set', () {
      const s = AnalyticsScope.land('l1');
      expect(s.matchesRevenue(plant, seasonIdsOnLand: {'s1', 's9'}), isTrue);
      expect(s.matchesRevenue(plant, seasonIdsOnLand: {'s9'}), isFalse);
      expect(
        s.matchesRevenue(plant),
        isFalse,
        reason: 'no resolved seasons → nothing matches, never everything',
      );
    });
  });
}
