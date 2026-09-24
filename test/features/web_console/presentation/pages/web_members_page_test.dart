import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_members_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: WebConsoleTheme.light(), home: Scaffold(body: view)),
  );
  await tester.pump();
}

FarmMember _member(String first, FarmRole role) => FarmMember(
  userId: role.index + 1,
  firstName: first,
  lastName: 'Njeri',
  email: '${first.toLowerCase()}@gmail.com',
  role: role,
  joinedAt: DateTime(2026, 3, 18),
);

final _members = [
  _member('Kamau', FarmRole.owner),
  _member('Wanjiku', FarmRole.manager),
];

final _invitations = [
  FarmInvitation(
    id: 9,
    email: 'achieng.m@gmail.com',
    role: FarmRole.worker,
    invitedBy: 1,
    expiresAt: DateTime.now().add(const Duration(days: 5)),
    createdAt: DateTime.now(),
  ),
];

void main() {
  testWidgets('a pending invitation is a row in the members table', (
    tester,
  ) async {
    await _pump(
      tester,
      MembersView(
        farmName: 'Keringet',
        members: _members,
        invitations: _invitations,
        role: FarmRole.owner,
        seats: 10,
      ),
    );

    expect(find.text('Invitation sent'), findsOneWidget);
    expect(find.text('achieng.m@gmail.com'), findsOneWidget);
    expect(find.textContaining('Expires in'), findsOneWidget);
    expect(find.text('Resend'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
    expect(find.text('2 active · 1 pending · 10 seats'), findsOneWidget);
  });

  testWidgets('a worker sees the list without the invite panel', (
    tester,
  ) async {
    await _pump(
      tester,
      MembersView(
        farmName: 'Keringet',
        members: _members,
        invitations: _invitations,
        role: FarmRole.worker,
      ),
    );

    expect(find.text('Kamau Njeri'), findsOneWidget);
    // Read-only for a worker (DESIGN_SPEC §5).
    expect(find.text('Invite member'), findsNothing);
    expect(find.text('INVITE BY EMAIL'), findsNothing);
    // Pending invitations are staff-only too.
    expect(find.text('Invitation sent'), findsNothing);
  });

  testWidgets('only the owner is offered ownership transfer', (tester) async {
    await _pump(
      tester,
      MembersView(
        farmName: 'Keringet',
        members: _members,
        role: FarmRole.manager,
      ),
    );

    expect(find.text('Nominate successor'), findsNothing);
  });

  testWidgets('the owner gets the ownership bar', (tester) async {
    await _pump(
      tester,
      MembersView(
        farmName: 'Keringet',
        members: _members,
        role: FarmRole.owner,
      ),
    );

    expect(find.text('Ownership · Kamau Njeri'), findsOneWidget);
    expect(find.text('Nominate successor'), findsOneWidget);
  });
}
