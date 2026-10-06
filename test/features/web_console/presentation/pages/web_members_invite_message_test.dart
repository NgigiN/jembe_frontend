import 'package:farm_tracker/features/web_console/presentation/pages/web_members_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// The console used to announce 'Invitation sent to <email>.' unconditionally,
/// while the backend had no email code at all — so for the whole life of the
/// feature that sentence was false and the person inviting had no way to know
/// their invitee would never hear anything.
void main() {
  group('invitationCreatedMessage', () {
    test('claims an email only when one actually went out', () {
      final sent = invitationCreatedMessage('w@example.com', emailed: true);
      expect(sent, contains('w@example.com'));
      expect(sent.toLowerCase(), contains('emailed'));
    });

    test('tells the inviter to pass it on when no email was sent', () {
      final notSent = invitationCreatedMessage('w@example.com', emailed: false);
      expect(notSent, contains('w@example.com'));
      // Must not imply delivery.
      expect(notSent.toLowerCase(), contains('no email was sent'));
      // Must say what to do instead, since the invite is claimed by signing in
      // with that address rather than from a link in the mail.
      expect(notSent.toLowerCase(), contains('sign in'));
    });
  });

  group('invitationResentMessage', () {
    test('says it emailed again only when it did', () {
      expect(
        invitationResentMessage('w@example.com', emailed: true).toLowerCase(),
        contains('emailed'),
      );
    });

    test('reports the renewal honestly when nothing was emailed', () {
      final notSent = invitationResentMessage('w@example.com', emailed: false);
      expect(notSent.toLowerCase(), contains('renewed'));
      expect(notSent.toLowerCase(), contains('no email was sent'));
    });
  });
}
