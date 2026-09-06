import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coalesce', () {
    test('create then update collapses to a single create with latest '
        'payload', () {
      const pending = [
        OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"old"}',
        ),
      ];
      const incoming = OutboxIntent(
        op: OutboxOp.update,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{"name":"new"}',
      );

      final out = coalesce(pending, incoming);

      expect(out, [
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"new"}',
        ),
      ]);
    });

    test('create then delete annihilates (empty for that clientUuid)', () {
      const pending = [
        OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{}',
        ),
      ];
      const incoming = OutboxIntent(
        op: OutboxOp.delete,
        clientUuid: 'a',
        entity: 'farm',
      );

      final out = coalesce(pending, incoming);

      expect(out.where((e) => e.clientUuid == 'a'), isEmpty);
      expect(out, isEmpty);
    });

    test('update then update collapses to a single update with latest '
        'payload', () {
      const pending = [
        OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"first-edit"}',
        ),
      ];
      const incoming = OutboxIntent(
        op: OutboxOp.update,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{"name":"second-edit"}',
      );

      final out = coalesce(pending, incoming);

      expect(out, [
        const OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"second-edit"}',
        ),
      ]);
    });

    test('update then delete collapses to a single delete', () {
      const pending = [
        OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"edited"}',
        ),
      ];
      const incoming = OutboxIntent(
        op: OutboxOp.delete,
        clientUuid: 'a',
        entity: 'farm',
      );

      final out = coalesce(pending, incoming);

      expect(out, [
        const OutboxIntent(
          op: OutboxOp.delete,
          clientUuid: 'a',
          entity: 'farm',
        ),
      ]);
    });

    test('operations on a different clientUuid are left untouched, order '
        'preserved', () {
      const pending = [
        OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'b',
          entity: 'farm',
          payload: '{"name":"other-row"}',
        ),
      ];
      const incoming = OutboxIntent(
        op: OutboxOp.update,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{"name":"new"}',
      );

      final out = coalesce(pending, incoming);

      // The other clientUuid's entry survives untouched...
      expect(out, contains(pending.first));
      // ...and the incoming op for the new clientUuid is simply appended.
      expect(out, [
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'b',
          entity: 'farm',
          payload: '{"name":"other-row"}',
        ),
        const OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"new"}',
        ),
      ]);
    });

    test('no existing entry for the clientUuid appends the incoming intent',
        () {
      const incoming = OutboxIntent(
        op: OutboxOp.create,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{"name":"brand-new"}',
      );

      final out = coalesce(const [], incoming);

      expect(out, [incoming]);
    });

    test(
      'existing delete is terminal: incoming ops for the same clientUuid '
      'do not crash and the delete is preserved defensively',
      () {
        const pending = [
          OutboxIntent(
            op: OutboxOp.delete,
            clientUuid: 'a',
            entity: 'farm',
          ),
        ];
        const incoming = OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"too-late"}',
        );

        final out = coalesce(pending, incoming);

        expect(
          out,
          [
            const OutboxIntent(
              op: OutboxOp.delete,
              clientUuid: 'a',
              entity: 'farm',
            ),
          ],
        );
      },
    );

    test('OutboxIntent equality is value-based', () {
      const a = OutboxIntent(
        op: OutboxOp.create,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{}',
      );
      const b = OutboxIntent(
        op: OutboxOp.create,
        clientUuid: 'a',
        entity: 'farm',
        payload: '{}',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
