import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late OutboxDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = OutboxDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('OutboxDao.enqueue', () {
    test('create then update for the same clientUuid collapses to one row '
        '(op create, latest payload)', () async {
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"old"}',
        ),
      );
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.update,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"new"}',
        ),
      );

      final rows = await dao.peekAll();

      expect(rows, hasLength(1));
      expect(rows.single.op, 'create');
      expect(rows.single.clientUuid, 'a');
      expect(rows.single.payload, '{"name":"new"}');
    });

    test('create then delete annihilates: the table ends up empty', () async {
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{"name":"scratch"}',
        ),
      );
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.delete,
          clientUuid: 'a',
          entity: 'farm',
        ),
      );

      final rows = await dao.peekAll();

      expect(rows, isEmpty);
    });

    test(
      'FIFO order across different clientUuids is preserved by peekAll',
      () async {
        await dao.enqueue(
          const OutboxIntent(
            op: OutboxOp.create,
            clientUuid: 'first',
            entity: 'farm',
            payload: '{"name":"first"}',
          ),
        );
        await dao.enqueue(
          const OutboxIntent(
            op: OutboxOp.create,
            clientUuid: 'second',
            entity: 'farm',
            payload: '{"name":"second"}',
          ),
        );

        final rows = await dao.peekAll();

        expect(rows, hasLength(2));
        expect(rows[0].clientUuid, 'first');
        expect(rows[1].clientUuid, 'second');
        expect(rows[0].seq, lessThan(rows[1].seq));
      },
    );
  });

  group('OutboxDao.ack', () {
    test('removes the row by seq', () async {
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{}',
        ),
      );
      final seq = (await dao.peekAll()).single.seq;

      await dao.ack(seq);

      expect(await dao.peekAll(), isEmpty);
    });
  });

  group('OutboxDao.pendingCount', () {
    test('counts only rows with state pending', () async {
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{}',
        ),
      );
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'b',
          entity: 'farm',
          payload: '{}',
        ),
      );
      expect(await dao.pendingCount(), 2);

      final seq = (await dao.peekAll()).first.seq;
      await dao.markFailed(seq);

      expect(await dao.pendingCount(), 1);
    });
  });

  group('OutboxDao.markFailed', () {
    test('flips state to failed and increments attempts', () async {
      await dao.enqueue(
        const OutboxIntent(
          op: OutboxOp.create,
          clientUuid: 'a',
          entity: 'farm',
          payload: '{}',
        ),
      );
      final seq = (await dao.peekAll()).single.seq;

      await dao.markFailed(seq);

      final row = (await dao.peekAll()).single;
      expect(row.state, 'failed');
      expect(row.attempts, 1);
    });
  });
}
