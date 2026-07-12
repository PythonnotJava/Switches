import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:switches/providers/app_provider.dart';
import 'package:switches/app.dart';

void main() {
  testWidgets('App loads and shows dashboard', (WidgetTester tester) async {
    final appProvider = AppProvider();
    // Skip Hive init for tests - just test UI renders
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: const MaterialApp(home: SwitchesApp()),
      ),
    );
    await tester.pump();
    expect(find.text('仪表盘'), findsOneWidget);
  });
}
