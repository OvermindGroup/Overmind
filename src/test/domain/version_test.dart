import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/domain/version.dart';

void main() {
  group('AppVersion.parse', () {
    test('reads a plain version', () {
      expect(AppVersion.parse('1.0.4'), const AppVersion(1, 0, 4));
    });

    test('reads a GitHub tag', () {
      expect(AppVersion.parse('v2.3.7'), const AppVersion(2, 3, 7));
    });

    test('ignores a build suffix', () {
      expect(AppVersion.parse('1.2.3+build14'), const AppVersion(1, 2, 3));
    });

    test('fills missing components with zero', () {
      expect(AppVersion.parse('3'), const AppVersion(3, 0, 0));
      expect(AppVersion.parse('3.1'), const AppVersion(3, 1, 0));
    });

    test('rejects anything that is not a version', () {
      expect(AppVersion.parse('nightly'), isNull);
      expect(AppVersion.parse(''), isNull);
    });
  });

  // Regression: versions were compared as strings, so 1.10.0 read as older
  // than 1.9.0 and the update prompt never appeared.
  test('compares numerically, not lexically', () {
    expect(AppVersion.parse('1.10.0')!.isNewerThan(AppVersion.parse('1.9.0')!),
        isTrue);
    expect(AppVersion.parse('1.2.0')!.isNewerThan(AppVersion.parse('1.2.1')!),
        isFalse);
  });

  test('equal versions are not newer than each other', () {
    final version = AppVersion.parse('1.0.4')!;
    expect(version.isNewerThan(version), isFalse);
    expect(AppVersion.parse('v1.0.4'), version);
  });
}
