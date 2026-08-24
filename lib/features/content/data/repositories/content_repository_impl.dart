import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/content/data/datasources/content_local_data_source.dart';
import 'package:farm_tracker/features/content/domain/entities/content_item.dart';
import 'package:farm_tracker/features/content/domain/repositories/content_repository.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({required this.localDataSource});

  final ContentLocalDataSource localDataSource;

  @override
  Future<List<ContentItem>> getAll() async {
    try {
      return await localDataSource.getAll();
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Failed to load bundled content - showing none instead of crashing',
        e,
      );
      return [];
    }
  }
}
