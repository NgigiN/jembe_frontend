import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/trash_item_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';

/// Maps a trash-response entity key to the REST path segment its restore
/// endpoint actually lives at (Phase 8 A3, `routes.go`). Most entities
/// pluralize (`land` -> `lands`); `animal_type` and `cost_category` also
/// hyphenate (`animal-types`, `cost-categories`); `infrastructure` and
/// `revenue` are unchanged. Kept alongside [trashEntities] (the response's
/// group keys) rather than reusing them directly, since the two sets
/// diverge for exactly these entities.
const _restorePathSegments = {
  'land': 'lands',
  'plant': 'plants',
  'season': 'seasons',
  'activity': 'activities',
  'input': 'inputs',
  'harvest': 'harvests',
  'animal_type': 'animal-types',
  'herd': 'herds',
  'animal': 'animals',
  'infrastructure': 'infrastructure',
  'cost_category': 'cost-categories',
  'revenue': 'revenue',
};

abstract class TrashRemoteDataSource {
  Future<List<TrashItem>> getTrash();
  Future<void> restore({required String entity, required String id});
}

/// Online-only (Phase 8 B2): the "Recently deleted" restore utility talks
/// straight to `GET /api/v1/trash` (A2) and a per-entity
/// `POST /api/v1/<path>/:id/restore` (A3) — there is no offline mirror or
/// local cache for either (see `TrashRepositoryImpl`'s class docs; restore
/// stays online-only because `DeletionsDataSource` hard-deletes the local
/// mirror row on a tombstone, so there is nothing local to un-delete).
class TrashRemoteDataSourceImpl implements TrashRemoteDataSource {
  TrashRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<TrashItem>> getTrash() async {
    try {
      appLogger.info(LogCategory.farm, 'Fetching trash');
      final response = await dio.get<dynamic>('/api/v1/trash');

      if (response.statusCode == 200) {
        final items = parseTrashResponse(
          response.data as Map<String, dynamic>,
        );
        appLogger.info(
          LogCategory.farm,
          'Fetched ${items.length} trash item(s)',
        );
        return items;
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in getTrash', e);
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('getTrash', e);
      throw const ServerException();
    }
  }

  @override
  Future<void> restore({required String entity, required String id}) async {
    final segment = _restorePathSegments[entity] ?? entity;
    final path = '/api/v1/$segment/$id/restore';
    try {
      appLogger.info(LogCategory.farm, 'Restoring $entity #$id');
      final response = await dio.post<dynamic>(path);

      if (response.statusCode == 200) {
        appLogger.info(LogCategory.farm, 'Restored $entity #$id');
        return;
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in restore', e);
      // 409 (a still-tombstoned parent, or a cost_category name collision —
      // A3) is a distinct, user-actionable outcome from every other error:
      // surfaced as ConflictException so the repository can keep the item
      // in the caller's trash list instead of dropping it. Every other
      // status (404 included) falls through to the shared mapDioException,
      // same as any other datasource.
      if (e.response?.statusCode == 409) {
        final msg = extractServerErrorMessage(e.response?.data);
        throw ConflictException(msg.isNotEmpty ? msg : null);
      }
      throw mapDioException(e);
    } on ServerException {
      rethrow;
    } catch (e) {
      appLogger.logError('restore', e);
      throw const ServerException();
    }
  }
}
