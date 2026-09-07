import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCostCategoryRepository extends Mock
    implements CostCategoryRepository {}

/// `CostCategoryBloc` itself never branches on `OfflineConfig` — the
/// flag-on/off behavior lives entirely under the mocked repository (see
/// `cost_category_repository_impl_test.dart`). This test exists to confirm
/// the bloc's own event→state contract
/// (`CostCategoryAdded`/`CostCategoryDeleted`, distinct states preserved —
/// see the P3 offline rollout recipe's outlier note) is unaffected by
/// toggling the flag around it either way.
void main() {
  const category = CostCategory(
    id: 'cc-1',
    name: 'Seeds',
    type: 'plant',
    category: 'input',
    isDefault: false,
  );

  late MockCostCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCostCategoryRepository();
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  CostCategoryBloc buildBloc() =>
      CostCategoryBloc(repository: mockRepository);

  for (final offlineFlag in [false, true]) {
    group(
      offlineFlag
          ? 'flag ON (OfflineConfig.enabled = true — bloc contract '
                'unaffected)'
          : "flag OFF (today's behavior)",
      () {
        setUp(() => OfflineConfig.enabled = offlineFlag);

        blocTest<CostCategoryBloc, CostCategoryState>(
          'GetCostCategoriesEvent emits [Loading, Loaded]',
          build: () {
            when(
              () => mockRepository.getCostCategories(
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            ).thenAnswer((_) async => const Right([category]));
            return buildBloc();
          },
          act: (bloc) =>
              bloc.add(const GetCostCategoriesEvent(category: 'input')),
          expect: () => [
            const CostCategoryLoading(),
            const CostCategoryLoaded([category]),
          ],
          verify: (_) {
            verify(
              () => mockRepository.getCostCategories(
                category: 'input',
              ),
            ).called(1);
          },
        );

        blocTest<CostCategoryBloc, CostCategoryState>(
          'AddCostCategoryEvent success emits CostCategoryAdded, then '
          'reloads via GetCostCategoriesEvent',
          build: () {
            when(
              () => mockRepository.addCostCategory(
                name: any(named: 'name'),
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            ).thenAnswer((_) async => const Right(true));
            when(
              () => mockRepository.getCostCategories(
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            ).thenAnswer((_) async => const Right([category]));
            return buildBloc();
          },
          act: (bloc) => bloc.add(
            const AddCostCategoryEvent(
              name: 'Seeds',
              type: 'plant',
              category: 'input',
            ),
          ),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            isA<CostCategoryLoading>(),
            isA<CostCategoryAdded>(),
            isA<CostCategoryLoading>(),
            isA<CostCategoryLoaded>(),
          ],
          verify: (_) {
            verify(
              () => mockRepository.addCostCategory(
                name: 'Seeds',
                type: 'plant',
                category: 'input',
              ),
            ).called(1);
          },
        );

        blocTest<CostCategoryBloc, CostCategoryState>(
          'AddCostCategoryEvent failure emits CostCategoryError (no reload)',
          build: () {
            when(
              () => mockRepository.addCostCategory(
                name: any(named: 'name'),
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            ).thenAnswer(
              (_) async => const Left(ServerFailure('boom')),
            );
            return buildBloc();
          },
          act: (bloc) => bloc.add(
            const AddCostCategoryEvent(
              name: 'Seeds',
              type: 'plant',
              category: 'input',
            ),
          ),
          expect: () => [
            isA<CostCategoryLoading>(),
            isA<CostCategoryError>(),
          ],
          verify: (_) {
            verifyNever(
              () => mockRepository.getCostCategories(
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            );
          },
        );

        blocTest<CostCategoryBloc, CostCategoryState>(
          'DeleteCostCategoryEvent success emits CostCategoryDeleted, then '
          'reloads via GetCostCategoriesEvent',
          build: () {
            when(
              () => mockRepository.deleteCostCategory(any()),
            ).thenAnswer((_) async => const Right(null));
            when(
              () => mockRepository.getCostCategories(
                type: any(named: 'type'),
                category: any(named: 'category'),
              ),
            ).thenAnswer((_) async => const Right(<CostCategory>[]));
            return buildBloc();
          },
          act: (bloc) => bloc.add(
            DeleteCostCategoryEvent(id: 'cc-1', category: 'input'),
          ),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            isA<CostCategoryLoading>(),
            isA<CostCategoryDeleted>(),
            isA<CostCategoryLoading>(),
            isA<CostCategoryLoaded>(),
          ],
        );
      },
    );
  }
}
