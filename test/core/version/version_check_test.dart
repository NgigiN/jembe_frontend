import 'package:farm_tracker/core/version/version_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareSemver', () {
    test('orders correctly', () {
      expect(compareSemver('1.0.0', '1.0.0'), 0);
      expect(compareSemver('1.0.0', '1.0.1'), -1);
      expect(compareSemver('1.2.0', '1.1.9'), 1);
    });

    test('compares major/minor/patch precedence', () {
      expect(compareSemver('2.0.0', '1.9.9'), 1);
      expect(compareSemver('1.0.0', '2.0.0'), -1);
      expect(compareSemver('1.10.0', '1.9.0'), 1);
    });

    test('ignores build metadata after +', () {
      expect(compareSemver('1.0.0+6', '1.0.0'), 0);
      expect(compareSemver('1.0.0+6', '1.0.0+99'), 0);
      expect(compareSemver('1.0.1+1', '1.0.0+9'), 1);
    });

    test('treats missing parts as zero', () {
      expect(compareSemver('1.0', '1.0.0'), 0);
      expect(compareSemver('1', '1.0.1'), -1);
    });

    test('treats non-numeric parts as zero', () {
      expect(compareSemver('1.x.0', '1.0.0'), 0);
    });
  });

  group('isBelow', () {
    test('flags a client under the minimum', () {
      expect(isBelow('1.0.0', '1.1.0'), isTrue);
      expect(isBelow('1.1.0', '1.0.0'), isFalse);
      expect(isBelow('1.0.0', '1.0.0'), isFalse);
    });

    test('ignores build metadata when deciding', () {
      expect(isBelow('1.0.0+6', '1.0.0'), isFalse);
      expect(isBelow('1.0.0+6', '1.1.0'), isTrue);
    });
  });

  group('decideUpgrade', () {
    test('forced when below the minimum supported version', () {
      final meta = {'min_supported_version': '1.1.0', 'latest_version': '1.2.0'};
      expect(decideUpgrade(meta, '1.0.0'), UpgradeRequirement.forced);
    });

    test('optional when at the minimum but below latest', () {
      final meta = {'min_supported_version': '1.0.0', 'latest_version': '1.2.0'};
      expect(decideUpgrade(meta, '1.0.0'), UpgradeRequirement.optional);
    });

    test('none when current with min and latest', () {
      final meta = {'min_supported_version': '1.0.0', 'latest_version': '1.0.0'};
      expect(decideUpgrade(meta, '1.0.0'), UpgradeRequirement.none);
      // The real prod payload today: app 1.0.0, min 1.0.0, latest 1.0.0.
      expect(decideUpgrade(meta, '1.0.0+6'), UpgradeRequirement.none);
    });

    test('none for malformed or missing payloads', () {
      expect(decideUpgrade(null, '1.0.0'), UpgradeRequirement.none);
      expect(decideUpgrade('garbage', '1.0.0'), UpgradeRequirement.none);
      expect(decideUpgrade(<String, dynamic>{}, '1.0.0'), UpgradeRequirement.none);
      expect(
        decideUpgrade({'latest_version': ''}, '1.0.0'),
        UpgradeRequirement.none,
      );
    });

    test('forced takes precedence over optional', () {
      final meta = {'min_supported_version': '2.0.0', 'latest_version': '2.0.0'};
      expect(decideUpgrade(meta, '1.0.0'), UpgradeRequirement.forced);
    });
  });
}
