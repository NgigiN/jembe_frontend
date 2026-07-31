import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
}
