import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/di/service_locator.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/web_injection_container.dart' as web_di;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition-level smoke test for the web console's DI container
/// (final whole-branch review, finding I9): every route wired into
/// `lib/main_web.dart` reads its bloc from `webSl`, but until this test no
/// automated check actually called `initWebDependencies()` and resolved
/// them — each registration was only ever proven correct by a real
/// `flutter build web` compiling successfully, which says nothing about
/// whether a registration is missing or throws at resolve time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  tearDown(() {
    web_di.webSl.reset();
    sl.reset();
  });

  test(
    'initWebDependencies() resolves every bloc lib/main_web.dart provides, '
    'without throwing',
    () async {
      AppConfig.initialize();
      await web_di.initWebDependencies();

      expect(web_di.webSl<AuthBloc>(), isA<AuthBloc>());
      expect(web_di.webSl<DashboardBloc>(), isA<DashboardBloc>());
      expect(web_di.webSl<AnalysisBloc>(), isA<AnalysisBloc>());
      expect(web_di.webSl<FarmBloc>(), isA<FarmBloc>());
      expect(web_di.webSl<FeedBloc>(), isA<FeedBloc>());
      expect(web_di.webSl<ThemeBloc>(), isA<ThemeBloc>());
      expect(
        web_di.webSl<SessionExpiryNotifier>(),
        isA<SessionExpiryNotifier>(),
      );
    },
  );

  test(
    'initWebDependencies() also populates the shared sl (GetIt.instance) '
    'FarmRemoteDataSource that FarmManagePage/CreateFarmPage read directly '
    '(web-console Task 15.6)',
    () async {
      AppConfig.initialize();
      await web_di.initWebDependencies();

      expect(sl<FarmRemoteDataSource>(), isA<FarmRemoteDataSource>());
    },
  );
}
