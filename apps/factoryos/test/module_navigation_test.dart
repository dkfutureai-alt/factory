import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _login(WidgetTester tester) async {
  final fields=find.byType(TextFormField);
  await tester.enterText(fields.at(0),'manager@example.test');
  await tester.enterText(fields.at(1),'preview123');
  final signIn=find.widgetWithText(FilledButton,'Sign in');
  await tester.ensureVisible(signIn);await tester.tap(signIn);await tester.pumpAndSettle();
}

void main(){
  testWidgets('admin reaches production order warehouse dispatch and item details',(tester)async{
    await tester.binding.setSurfaceSize(const Size(1440,1024));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const FactoryOsApp());await _login(tester);
    await tester.tap(find.text('Production').first);await tester.pumpAndSettle();
    expect(find.text('Active production orders'),findsOneWidget);
    await tester.tap(find.text('PRD-2026-01038').first);await tester.pumpAndSettle();
    expect(find.text('Material requirement'),findsOneWidget);expect(find.text('Batch & QC'),findsOneWidget);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory').first);await tester.pumpAndSettle();
    await tester.tap(find.textContaining('RM-STL-304-02').first);await tester.pumpAndSettle();
    expect(find.text('Recent stock movements'),findsOneWidget);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();await tester.pumpAndSettle();
    await tester.tap(find.text('Warehouse').first);await tester.pumpAndSettle();expect(find.text('Operational tasks'),findsOneWidget);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();await tester.pumpAndSettle();
    await tester.tap(find.text('Dispatch').first);await tester.pumpAndSettle();expect(find.text('Dispatch queue'),findsOneWidget);expect(find.text('Documents & checks'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
