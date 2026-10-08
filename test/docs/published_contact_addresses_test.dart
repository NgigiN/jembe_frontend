import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The site under `docs/` is served publicly by GitHub Pages, so every address
/// on it is published to anyone and to every crawler that reaches it.
///
/// Until 8 Oct 2026 all four legal pages carried the maintainer's personal
/// Gmail: the privacy policy named it as the data-controller contact, the
/// deletion page made it the button you press to delete your account, and the
/// landing page put it in the footer and the early-access link. That is a
/// personal inbox doing the job of a company one, and nothing in review would
/// have caught it coming back.
///
/// Role addresses only. A personal address is a regression, not a style
/// preference.
void main() {
  test('no personal address is published on the site', () {
    final site = Directory('docs');
    if (!site.existsSync()) {
      fail('docs/ is missing; the published site should be in this repo');
    }

    // Only the served pages. Markdown handoff notes under docs/ carry
    // fictional personas (achieng.m@gmail.com and friends) that are sample
    // data, not contacts, and are not served as pages.
    final pages = site
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.html'))
        .toList();

    expect(
      pages,
      isNotEmpty,
      reason:
          'found no HTML pages to check — the guard would pass '
          'vacuously if the site moved',
    );

    final offenders = <String>[];
    final personal = RegExp(
      '[A-Za-z0-9._%+-]+@(?:gmail|yahoo|hotmail|'
      r'outlook|icloud|proton(?:mail)?)\.[A-Za-z.]+',
    );

    for (final page in pages) {
      for (final match in personal.allMatches(page.readAsStringSync())) {
        offenders.add('${page.path}: ${match.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'published pages must use a role address '
          '(support@ / privacy@shambaplus.samtama.lol), never a personal '
          'inbox:\n  ${offenders.join('\n  ')}',
    );
  });

  test('the legal pages actually carry a contact address - the guard above '
      'passes just as happily on a page that lists none at all', () {
    const legal = [
      'docs/support/legal/privacy-policy.html',
      'docs/support/legal/terms-of-service.html',
      'docs/support/legal/delete-account.html',
    ];

    for (final path in legal) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      expect(
        file.readAsStringSync(),
        contains('@shambaplus.samtama.lol'),
        reason: '$path must name a way to reach us',
      );
    }
  });
}
