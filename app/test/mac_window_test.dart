import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Mac window shows a filled admin home', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 600);
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('School admin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expectFilled(tester, const Size(800, 600));

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expectFilled(tester, const Size(1280, 800));
  });
}

void expectFilled(WidgetTester tester, Size window) {
  final hello = find.textContaining('Hello, School admin');
  expect(hello, findsOneWidget, reason: 'admin home was blank at $window');
  final box = tester.renderObject<RenderBox>(hello);
  expect(box.size.height, greaterThan(10), reason: 'Hello has no height at $window');
  final top = box.localToGlobal(Offset.zero).dy;
  expect(top, greaterThanOrEqualTo(0));
  expect(top + box.size.height, lessThan(window.height), reason: 'Hello is outside the window at $window');
  expect(find.textContaining('A calm day'), findsOneWidget, reason: 'the hero did not paint at $window');
  expect(find.textContaining('Developed by'), findsWidgets);
  expect(find.text('See fees'), findsWidgets);
}
