import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/content/data/datasources/content_local_data_source.dart';
import 'package:farm_tracker/features/content/data/models/content_item_model.dart';
import 'package:farm_tracker/features/content/data/repositories/content_repository_impl.dart';

class ThrowingDataSource implements ContentLocalDataSource {
  @override
  Future<List<ContentItemModel>> getAll() async {
    throw const FormatException('bad json');
  }
}

void main() {
  group('ContentRepositoryImpl', () {
    test(
      'a data-source failure degrades to an empty list, not a thrown error',
      () async {
        final repository = ContentRepositoryImpl(
          localDataSource: ThrowingDataSource(),
        );
        final result = await repository.getAll();
        expect(result, isEmpty);
      },
    );
  });
}
