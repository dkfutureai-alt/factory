import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic version comparison is numeric, including build revision', () {
    final v = FactoryAppVersion.tryParse('1.10.0+2')!;
    expect(v.compareTo(FactoryAppVersion.tryParse('1.9.99+999')!), greaterThan(0));
    expect(FactoryAppVersion.tryParse('2.0.0')!.compareTo(v), greaterThan(0));
    expect(FactoryAppVersion.tryParse('01.0.0'), isNull);
    expect(FactoryAppVersion.tryParse('unknown'), isNull);
    expect(FactoryAppVersion.tryParse('1.0.0-beta'), isNull);
  });

  test('force, optional, maintenance and current are distinct', () {
    final base = <String, dynamic>{
      'minimum_version': '2.0.0',
      'latest_version': '2.5.0',
      'download_url': 'https://example.org/factoryos',
      'release_notes': 'Improved cylinder scanning',
      'enabled': true,
      'maintenance_mode': false,
    };
    final policy = FactoryReleasePolicy.fromMap(base);
    expect(policy.evaluate(FactoryAppVersion.tryParse('1.9.9')!), FactoryReleaseAction.forceUpdate);
    expect(policy.evaluate(FactoryAppVersion.tryParse('2.2.0')!), FactoryReleaseAction.optionalUpdate);
    expect(policy.evaluate(FactoryAppVersion.tryParse('2.5.0')!), FactoryReleaseAction.current);
    expect(policy.evaluate(FactoryAppVersion.tryParse('3.0.0')!), FactoryReleaseAction.current);
    expect(FactoryReleasePolicy.fromMap({...base, 'maintenance_mode': true})
        .evaluate(FactoryAppVersion.tryParse('2.5.0')!), FactoryReleaseAction.maintenance);
    expect(FactoryReleasePolicy.fromMap({...base, 'enabled': false})
        .evaluate(FactoryAppVersion.tryParse('1.0.0')!), FactoryReleaseAction.current);
  });

  test('rejects malformed policies and insecure URLs', () {
    expect(
      () => FactoryReleasePolicy.fromMap({
        'minimum_version': '3.0.0',
        'latest_version': '2.0.0',
      }),
      throwsFormatException,
    );
    expect(
      () => FactoryReleasePolicy.fromMap({
        'minimum_version': '1.0.0',
        'latest_version': '2.0.0',
        'download_url': 'http://insecure.example/file.apk',
      }),
      throwsFormatException,
    );
  });
}
