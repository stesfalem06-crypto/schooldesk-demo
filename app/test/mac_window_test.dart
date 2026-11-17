import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Mac window shows a filled admin home', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 800);
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('School admin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Students'), findsWidgets);
    expect(find.textContaining('Pass rate'), findsWidgets);
    expect(find.textContaining('Nfk'), findsWidgets);
    expect(find.textContaining('Developed by'), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Pass rate'), findsWidgets);
  });
}
