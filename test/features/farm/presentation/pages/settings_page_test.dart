import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/settings_page.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockThemeBloc extends MockBloc<ThemeEvent, ThemeState>
    implements ThemeBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(FetchProfileEvent());
    registerFallbackValue(ToggleThemeEvent());
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
        fiscalYearStartMonth: 1,
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
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Farm Year card sits below Profile Information; scroll to it.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
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
        fiscalYearStartMonth: 1,
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
    'toggling Dark Mode fires a selection haptic and dispatches ToggleThemeEvent',
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
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find.widgetWithText(ListTile, 'Dark Mode'),
        matching: find.byType(Switch),
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      verify(() => themeBloc.add(any(that: isA<ToggleThemeEvent>()))).called(1);
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
}
