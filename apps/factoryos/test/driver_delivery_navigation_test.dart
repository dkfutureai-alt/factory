import 'package:factoryos/features/home/driver_home_page.dart';
import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver home reaches assigned delivery workflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: ThemeData(useMaterial3: true), routes: FactoryOsTestRoutes.routes, home: const DriverHomePage()));

    await tester.ensureVisible(find.text('Deliveries'));
    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Detail'), findsOneWidget);
    expect(find.text('Proof of delivery'), findsOneWidget);
    expect(find.text('Complete delivery checklist'), findsOneWidget);
    expect(find.text('Report exception'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver delivery page must render without overflow.');
  });
}

class FactoryOsTestRoutes {
  static final routes = <String, WidgetBuilder>{
    '/delivery/driver': (_) => FactoryOsDeliveryRouteBuilder.driver(),
    '/delivery/exception': (_) => FactoryOsDeliveryRouteBuilder.exception(),
    '/fleet/trips': (_) => const SizedBox.shrink(),
    '/fleet/fuel': (_) => const SizedBox.shrink(),
  };
}

class FactoryOsDeliveryRouteBuilder {
  static Widget driver() {
    final app = FactoryOsApp();
    final material = app.build(_FakeBuildContext()) as MaterialApp;
    return material.routes!['/delivery/driver']!(_FakeBuildContext());
  }

  static Widget exception() {
    final app = FactoryOsApp();
    final material = app.build(_FakeBuildContext()) as MaterialApp;
    return material.routes!['/delivery/exception']!(_FakeBuildContext());
  }
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
