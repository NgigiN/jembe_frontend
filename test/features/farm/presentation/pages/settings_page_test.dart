import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/settings_page.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockThemeBloc extends MockBloc<ThemeEvent, ThemeState>
    implements ThemeBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
}

Farm _farm(FarmRole role) => Farm(
  id: 1, name: 'Farm', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 1, isDefault: true,
);

BlocProvider<FarmBloc> _farmBlocProvider([FarmRole role = FarmRole.owner]) =>
    BlocProvider<FarmBloc>.value(
      value: _FakeFarmBloc(
        FarmLoaded(farms: [_farm(role)], currentFarmId: 1, currentRole: role),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(FetchProfileEvent());
    registerFallbackValue(SetThemeModeEvent(ThemeMode.system));
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'shows the Farm Year dropdown pre-selected to the loaded profile and dispatches an update on change',
    (tester) async {
      final profileBloc = MockProfileBloc();
      final themeBloc = MockThemeBloc();
      final authBloc = MockAuthBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );
      whenListen(
        themeBloc,
        Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
        initialState: const ThemeState(themeMode: ThemeMode.light),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ThemeBloc>.value(value: themeBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              _farmBlocProvider(),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Farm Year card sits below Profile Information; scroll to it.
      await tester.dragUntilVisible(
        find.text('January'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('January'), findsOneWidget);

      await tester.tap(find.text('January'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('July').last);
      await tester.pumpAndSettle();

      final captured = verify(
        () => profileBloc.add(captureAny(that: isA<UpdateProfileEvent>())),
      ).captured;
      final event = captured.last as UpdateProfileEvent;
      expect(event.fiscalYearStartMonth, 7);
    },
  );

  testWidgets(
    'Delete Account requires typing DELETE before dispatching DeleteAccountEvent',
    (tester) async {
      final profileBloc = MockProfileBloc();
      final themeBloc = MockThemeBloc();
      final authBloc = MockAuthBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );
      whenListen(
        themeBloc,
        Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
        initialState: const ThemeState(themeMode: ThemeMode.light),
      );

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ThemeBloc>.value(value: themeBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              _farmBlocProvider(),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Delete Account'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      final deleteButtonFinder = find.widgetWithText(TextButton, 'Delete');
      expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

      final dialogTextFieldFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextFieldFinder, 'DELETE');
      await tester.pump();

      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle();

      verify(
        () => profileBloc.add(any(that: isA<DeleteAccountEvent>())),
      ).called(1);
      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, hasLength(1));
      expect(
        hapticCalls.single.arguments,
        'HapticFeedbackType.mediumImpact',
      );
    },
  );

  testWidgets(
    'selecting Dark in the Theme picker fires a selection haptic and dispatches SetThemeModeEvent',
    (tester) async {
      final profileBloc = MockProfileBloc();
      final themeBloc = MockThemeBloc();
      final authBloc = MockAuthBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );
      whenListen(
        themeBloc,
        Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.system)),
        initialState: const ThemeState(themeMode: ThemeMode.system),
      );

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ThemeBloc>.value(value: themeBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              _farmBlocProvider(),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      verify(
        () => themeBloc.add(
          any(
            that: isA<SetThemeModeEvent>().having(
              (e) => e.mode,
              'mode',
              ThemeMode.dark,
            ),
          ),
        ),
      ).called(1);
      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.single.arguments, 'HapticFeedbackType.selectionClick');
    },
  );

  testWidgets(
    'Sound Effects toggle defaults on, persists the change, and fires a selection haptic',
    (tester) async {
      final profileBloc = MockProfileBloc();
      final themeBloc = MockThemeBloc();
      final authBloc = MockAuthBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );
      whenListen(
        themeBloc,
        Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
        initialState: const ThemeState(themeMode: ThemeMode.light),
      );

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ThemeBloc>.value(value: themeBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              _farmBlocProvider(),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find.widgetWithText(ListTile, 'Sound Effects'),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      final hapticCalls =
          calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.single.arguments, 'HapticFeedbackType.selectionClick');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(soundEffectsPrefsKey), isFalse);
    },
  );

  testWidgets('shows a "Your Farms" entry that opens the farm switcher',
      (tester) async {
    final profileBloc = MockProfileBloc();
    final themeBloc = MockThemeBloc();
    final authBloc = MockAuthBloc();

    const user = User(
      id: '1',
      email: 'a@example.com',
      firstName: 'A',
      lastName: 'B',
      farmName: 'Green Acres',
      location: 'Nakuru',
      pictureUrl: '',
    );

    whenListen(
      profileBloc,
      Stream<ProfileState>.value(const ProfileLoaded(user: user)),
      initialState: const ProfileLoaded(user: user),
    );
    whenListen(
      themeBloc,
      Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
      initialState: const ThemeState(themeMode: ThemeMode.light),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProfileBloc>.value(value: profileBloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
            _farmBlocProvider(),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Switch farms, invite members, manage roles'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Switch farms, invite members, manage roles'), findsOneWidget);
  });

  testWidgets('a worker does not see Farm Year or Recently Deleted',
      (tester) async {
    // Tall surface so the whole ListView mounts at once — findsNothing on a
    // virtualized ListView is only meaningful if the section would have
    // been mounted were it present.
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profileBloc = MockProfileBloc();
    final themeBloc = MockThemeBloc();
    final authBloc = MockAuthBloc();

    const user = User(
      id: '1',
      email: 'a@example.com',
      firstName: 'A',
      lastName: 'B',
      farmName: 'Green Acres',
      location: 'Nakuru',
      pictureUrl: '',
    );

    whenListen(
      profileBloc,
      Stream<ProfileState>.value(const ProfileLoaded(user: user)),
      initialState: const ProfileLoaded(user: user),
    );
    whenListen(
      themeBloc,
      Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
      initialState: const ThemeState(themeMode: ThemeMode.light),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProfileBloc>.value(value: profileBloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
            _farmBlocProvider(FarmRole.worker),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Farm Year'), findsNothing);
    expect(find.text('Recently Deleted'), findsNothing);
    expect(find.text('Browse Farming Tips'), findsOneWidget);
  });

  testWidgets('an owner still sees Farm Year and Recently Deleted',
      (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profileBloc = MockProfileBloc();
    final themeBloc = MockThemeBloc();
    final authBloc = MockAuthBloc();

    const user = User(
      id: '1',
      email: 'a@example.com',
      firstName: 'A',
      lastName: 'B',
      farmName: 'Green Acres',
      location: 'Nakuru',
      pictureUrl: '',
    );

    whenListen(
      profileBloc,
      Stream<ProfileState>.value(const ProfileLoaded(user: user)),
      initialState: const ProfileLoaded(user: user),
    );
    whenListen(
      themeBloc,
      Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
      initialState: const ThemeState(themeMode: ThemeMode.light),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProfileBloc>.value(value: profileBloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
            _farmBlocProvider(FarmRole.owner),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Farm Year'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Farm Year'), findsOneWidget);
    expect(find.text('Recently Deleted'), findsOneWidget);
  });
}
