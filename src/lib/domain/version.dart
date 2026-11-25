/// A `major.minor.patch` version, as pubspec `version:` and GitHub release
/// tags produce them.
///
/// Comparing version strings with `compareTo` is wrong: `"1.10.0"` sorts before
/// `"1.9.0"`, so an update would never be offered. Numeric comparison instead.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  static const AppVersion zero = AppVersion(0, 0, 0);

  final int major;
  final int minor;
  final int patch;

  /// Returns null for anything that is not a version, so callers can skip
  /// rather than guess. Accepts a leading `v` and ignores build suffixes.
  static AppVersion? parse(String text) {
    final parts = text.trim().replaceFirst(RegExp(r'^v'), '').split('.');
    final major = parts.isEmpty ? null : int.tryParse(parts[0]);
    if (major == null) return null;
    return AppVersion(
      major,
      parts.length > 1 ? _number(parts[1]) : 0,
      parts.length > 2 ? _number(parts[2]) : 0,
    );
  }

  static int _number(String part) {
    final leading = RegExp(r'^\d+').matchAsPrefix(part);
    return leading == null ? 0 : int.parse(leading.group(0)!);
  }

  @override
  int compareTo(AppVersion other) {
    final byMajor = major.compareTo(other.major);
    if (byMajor != 0) return byMajor;
    final byMinor = minor.compareTo(other.minor);
    if (byMinor != 0) return byMinor;
    return patch.compareTo(other.patch);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
