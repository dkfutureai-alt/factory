import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared light/dark themes use Material 3 and allow a scoped palette', () {
    const palette = FactoryBrandPalette(primaryColor: Color(0xFF7E297E));
    final light = FactoryTheme.light(brand: palette);
    final dark = FactoryTheme.dark(brand: palette);

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      light.colorScheme.primary,
      isNot(FactoryTheme.light().colorScheme.primary),
    );
    expect(dark.colorScheme.onSurface, isNot(dark.colorScheme.surface));
  });

  testWidgets('responsive columns protect 320dp and 200-percent text', (
    tester,
  ) async {
    int? phoneColumns;
    int? largeTypeColumns;
    int? desktopColumns;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            phoneColumns = FactoryLayout.metricColumns(context, 320);
            desktopColumns = FactoryLayout.metricColumns(context, 1280);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: Builder(
                builder: (context) {
                  largeTypeColumns = FactoryLayout.metricColumns(context, 900);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(phoneColumns, 1);
    expect(largeTypeColumns, 1);
    expect(desktopColumns, 4);
  });

  testWidgets('reduced motion is immediate without suppressing content', (
    tester,
  ) async {
    Duration? motion;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              motion = FactoryMotion.effective(context, FactoryMotion.standard);
              return const Text('Production ready to view');
            },
          ),
        ),
      ),
    );
    expect(motion, Duration.zero);
    expect(find.text('Production ready to view'), findsOneWidget);
  });

  testWidgets('metric card shows supplied values and no invented metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: const Scaffold(
          body: FactoryMetricCard(
            label: 'Filled cylinders',
            value: '124',
            icon: Icons.inventory_2_outlined,
            detail: 'Current authorized report',
          ),
        ),
      ),
    );

    expect(find.text('Filled cylinders'), findsOneWidget);
    expect(find.text('124'), findsOneWidget);
    expect(find.text('Current authorized report'), findsOneWidget);
  });

  testWidgets('error state has a usable retry action', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FactoryStatePanel(
            state: FactoryViewState.error,
            message: 'Report is unavailable',
            onRetry: () => attempts++,
          ),
        ),
      ),
    );

    expect(find.text('Report is unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(attempts, 1);
  });

  testWidgets('safety status always has text and an icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FactoryStatusLabel(
            label: 'Inspection hold',
            tone: FactoryNoticeTone.warning,
          ),
        ),
      ),
    );

    expect(find.text('Inspection hold'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
