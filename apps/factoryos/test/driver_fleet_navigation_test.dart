import 'package:factoryos/features/fleet/data/fleet_repository.dart';
import 'package:factoryos/features/fleet/presentation/fuel_management_page.dart';
import 'package:factoryos/features/fleet/presentation/trip_management_page.dart';
import 'package:factoryos/features/home/driver_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver home reaches assigned trip and fuel workflows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: const DriverHomePage(),
      routes: {
        '/fleet/trips': (_) => const TripManagementPage(repository: PreviewFleetRepository()),
        '/fleet/fuel': (_) => const FuelManagementPage(repository: PreviewFleetRepository()),
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('Driver home'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver home must render without overflow.');

    await tester.tap(find.text('TRIP-2026-00814'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Management'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver trip route must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fuel entry'));
    await tester.tap(find.text('Fuel entry'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel Management'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver fuel route must render without overflow.');
  });
}
