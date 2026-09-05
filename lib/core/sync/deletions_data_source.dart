import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';

/// Applies P1's `/api/v1/sync/deletions` tombstone feed to the local mirror.
///
/// The server returns every hard-deletion across ALL offline-mirrored
/// entities as `[{entity, id, client_uuid, deleted_at}]`. This phase of the
/// pilot only knows how to apply `land` tombstones (`landLocal.hardDelete`);
/// tombstones for every other entity are ignored — their local mirrors land
/// in later phases. [applyDeletions] is idempotent: re-applying an
/// already-gone row's tombstone is a no-op (`hardDelete` is a DELETE...WHERE,
/// safe when nothing matches).
class DeletionsDataSource implements DeletionsApplier {
  DeletionsDataSource({required this.dio, required this.landLocal});

  final Dio dio;
  final LandLocalDataSource landLocal;

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
    if (entity != 'land') return; // other entities' phases come later.

    final clientUuid = (tombstone['client_uuid'] ?? '').toString();
    if (clientUuid.isNotEmpty) {
      await landLocal.hardDelete(clientUuid);
      return;
    }

    // The tombstone carried no client_uuid — fall back to matching the
    // local row by its server id.
    final serverId = (tombstone['id'] ?? '').toString();
    if (serverId.isEmpty) return; // nothing to key on.

    final local = await landLocal.getByServerId(serverId);
    if (local != null) {
      await landLocal.hardDelete(local.clientUuid);
    }
  }
}
