/// Pure release decisions; the server controls policies but never installs apps.
/// Version decisions never authorize inventory or financial transactions.
class FactoryAppVersion implements Comparable<FactoryAppVersion> {
  const FactoryAppVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static FactoryAppVersion? tryParse(String text) {
    final match = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\+(0|[1-9][0-9]*))?$')
        .firstMatch(text.trim());
    if (match == null) return null;
    final values = [
      for (var i = 1; i <= 4; i++)
        int.tryParse(match.group(i) ?? '0'),
    ];
    if (values.any((value) => value == null)) return null;
    return FactoryAppVersion(values[0]!, values[1]!, values[2]!, values[3]!);
  }

  @override
  int compareTo(FactoryAppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
      (build, other.build),
    ]) {
      final diff = a.compareTo(b);
      if (diff != 0) return diff;
    }
    return 0;
  }
}

enum FactoryReleaseAction { current, optionalUpdate, forceUpdate, maintenance }

/// Database fields deliberately exclude tenant/customer metadata. Mobile
/// packages are independently identified by their installed package ID.
class FactoryReleasePolicy {
  const FactoryReleasePolicy({
    required this.minimum,
    required this.latest,
    required this.maintenance,
    required this.enabled,
    required this.downloadUrl,
    required this.notes,
  });

  final FactoryAppVersion minimum;
  final FactoryAppVersion latest;
  final bool maintenance;
  final bool enabled;
  final Uri? downloadUrl;
  final String notes;

  static FactoryReleasePolicy fromMap(Map<String, dynamic> source) {
    final min = FactoryAppVersion.tryParse(
      source['minimum_version'] as String? ?? '',
    );
    final latest = FactoryAppVersion.tryParse(
      source['latest_version'] as String? ?? '',
    );
    if (min == null || latest == null || min.compareTo(latest) > 0) {
      throw const FormatException('Invalid application release versions.');
    }
    final urlValue = source['download_url'] as String?;
    final uri = urlValue == null || urlValue.isEmpty
        ? null
        : Uri.tryParse(urlValue);
    if (uri != null &&
        (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
      throw const FormatException('Update address must be HTTPS.');
    }
    return FactoryReleasePolicy(
      minimum: min,
      latest: latest,
      maintenance: source['maintenance_mode'] == true,
      enabled: source['enabled'] != false,
      downloadUrl: uri,
      notes: (source['release_notes'] as String? ?? '').trim(),
    );
  }

  FactoryReleaseAction evaluate(FactoryAppVersion installed) {
    if (!enabled) return FactoryReleaseAction.current;
    if (maintenance) return FactoryReleaseAction.maintenance;
    if (installed.compareTo(minimum) < 0) {
      return FactoryReleaseAction.forceUpdate;
    }
    if (installed.compareTo(latest) < 0) {
      return FactoryReleaseAction.optionalUpdate;
    }
    return FactoryReleaseAction.current;
  }
}
