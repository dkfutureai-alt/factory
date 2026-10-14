import 'package:factoryos/features/delivery/data/delivery_repository.dart';
import 'package:factoryos/features/delivery/presentation/delivery_detail_page.dart';
import 'package:factoryos/features/delivery/presentation/delivery_exception_page.dart';
import 'package:factoryos/features/home/driver_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver home reaches assigned delivery workflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      routes: {
        '/delivery/driver': (_) => const DeliveryDetailPage(repository: PreviewDeliveryRepository(), deliveryNumber: 'DEL-2026-00681', driverMode: true),
        '/delivery/exception': (_) => const DeliveryExceptionPage(repository: PreviewDeliveryRepository(), deliveryNumber: 'DEL-2026-00678'),
        '/fleet/trips': (_) => const Scaffold(body: Center(child: Text('Trips'))),
        '/fleet/fuel': (_) => const Scaffold(body: Center(child: Text('Fuel'))),
      },
      home: const DriverHomePage(),
    ));

    await tester.ensureVisible(find.text('Deliveries'));
    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Detail'), findsOneWidget);
    expect(find.text('Proof of delivery'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver delivery header and POD section must render without overflow.');

    await tester.fling(find.byType(ListView).last, const Offset(0, -1800), 2500);
    await tester.pumpAndSettle();

    expect(find.text('Complete delivery checklist'), findsOneWidget);
    expect(find.text('Report exception'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver delivery actions must render without overflow.');
  });
}
