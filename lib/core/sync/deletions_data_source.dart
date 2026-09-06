import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';

/// Applies P1's `/api/v1/sync/deletions` tombstone feed to the local mirror.
///
/// The server returns every hard-deletion across ALL offline-mirrored
/// entities as `[{entity, id, client_uuid, deleted_at}]`. [applyDeletions]
/// applies a tombstone for every entity registered in [stores]; tombstones
/// for an entity with no registered store are ignored — that entity's local
/// mirror lands in a later rollout task. [applyDeletions] is idempotent:
/// re-applying an already-gone row's tombstone is a no-op (`hardDelete` is a
/// DELETE...WHERE, safe when nothing matches).
class DeletionsDataSource implements DeletionsApplier {
  DeletionsDataSource({required this.dio, required this.stores});

  final Dio dio;

  /// The local mirror for each offline-mirrored entity, keyed by the same
  /// `entity` tag used in the outbox/tombstone feed (e.g. `'land'`).
  final Map<String, LocalSyncStore<SyncableModel>> stores;

  @override
  Future<void> applyDeletions(DateTime? since) async {
    try {
      final queryParams = since != null
          ? {'updated_since': since.toUtc().toIso8601String()}
          : null;

      final response = await dio.get<dynamic>(
        '/api/v1/sync/deletions',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }

      final data = response.data;
      if (data is! List) return;

      for (final raw in data) {
        if (raw is Map<String, dynamic>) {
          await _applyTombstone(raw);
        }
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  Future<void> _applyTombstone(Map<String, dynamic> tombstone) async {
    final entity = (tombstone['entity'] ?? '').toString();
    final store = stores[entity];
    if (store == null) return; // no local mirror registered for this entity yet.

    final clientUuid = (tombstone['client_uuid'] ?? '').toString();
    if (clientUuid.isNotEmpty) {
      await store.hardDelete(clientUuid);
      return;
    }

    // The tombstone carried no client_uuid — fall back to matching the
    // local row by its server id.
    final serverId = (tombstone['id'] ?? '').toString();
    if (serverId.isEmpty) return; // nothing to key on.

    final local = await store.getByServerId(serverId);
    if (local != null) await store.hardDelete(local.syncClientUuid);
  }
}
