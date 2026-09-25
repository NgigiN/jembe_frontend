import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';

/// A [FarmBloc] that never leaves [FarmInitial].
///
/// Every top-level page's app bar renders `FarmSwitcherTitle`, which reads
/// [FarmBloc] out of the widget tree. A page test that cares only about the
/// page's own content still has to satisfy that lookup, and this is the
/// least it can provide: in [FarmInitial] the title falls back to the page's
/// own name and offers no switcher, so the app bar under test is exactly the
/// one that existed before the switcher was added.
class StubFarmBloc extends MockBloc<FarmEvent, FarmState> implements FarmBloc {}

/// Builds a [StubFarmBloc] parked on [FarmInitial].
StubFarmBloc stubFarmBloc() {
  final bloc = StubFarmBloc();
  whenListen(
    bloc,
    const Stream<FarmState>.empty(),
    initialState: FarmInitial(),
  );
  return bloc;
}
