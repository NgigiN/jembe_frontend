import 'package:farm_tracker/core/support/support_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uri build() => supportMailtoUri(
    version: '2.1.0',
    buildNumber: '10',
    platform: 'android',
  );

  test('addresses the pinned support mailbox', () {
    final uri = build();
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@shambaplus.samtama.lol');
    expect(uri.path, supportEmailAddress);
  });

  test(
    'carries the build number in the subject AND the body - the subject so it '
    'is readable in an inbox list without opening the mail, the body so it '
    'survives a reply chain that rewrites the subject',
    () {
      final q = Uri.decodeComponent(build().query);
      expect(q, contains('2.1.0'));
      expect(q, contains('10'));

      final uri = build();
      final subject = Uri.decodeComponent(
        RegExp('subject=([^&]*)').firstMatch(uri.query)!.group(1)!,
      );
      final body = Uri.decodeComponent(
        RegExp('body=([^&]*)').firstMatch(uri.query)!.group(1)!,
      );
      expect(subject, contains('(10)'));
      expect(body, contains('build 10'));
      expect(body, contains('android'));
    },
  );

  test('percent-encodes spaces as %20 and never as "+" - Uri.queryParameters '
      'spells a space "+", which mail clients render as a literal plus and so '
      'hands support a body full of pluses instead of words', () {
    final query = build().query;
    expect(query, contains('%20'));
    expect(
      query.contains('+') && !query.contains('%2B'),
      isFalse,
      reason: 'a bare "+" in the query is the form-encoding bug',
    );
  });

  test('the plus in "Shamba+" is escaped to %2B, so it cannot be decoded back '
      'as a space and turn the product name into "Shamba "', () {
    final uri = build();
    expect(uri.query, contains('%2B'));
    final subject = Uri.decodeComponent(
      RegExp('subject=([^&]*)').firstMatch(uri.query)!.group(1)!,
    );
    expect(subject, startsWith('Shamba+ support'));
  });
}
