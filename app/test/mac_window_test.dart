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
    tester.view.physicalSize = const Size(1280, 800);
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('School admin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Classes'), findsWidgets);
    expect(find.text('My class'), findsNothing);
    expect(find.textContaining('Pass rate'), findsWidgets);
    expect(find.textContaining('Nfk'), findsWidgets);
    expect(find.textContaining('Developed by'), findsWidgets);
    expectPlain(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('nav-Timetable')));
    for (var i = 0; i < 20 && classChips(tester).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Make the week'), findsWidgets);
    final chips = classChips(tester);
    expect(chips, isNotEmpty);
    expect(chips, orderedClasses(chips));
    expectPlain(tester);
    await tester.tap(find.byKey(const Key('nav-Dashboard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    tester.view.physicalSize = const Size(800, 600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Pass rate'), findsWidgets);
    expectPlain(tester);
  });
}

void expectPlain(WidgetTester tester) {
  const yellow = Color(0xFFFFFF00);
  for (final element in find.byType(Text).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final span = render.text;
    if (span is TextSpan && span.style?.decorationColor == yellow) {
      fail('yellow underline on ${span.toPlainText()}');
    }
  }
}

List<String> classChips(WidgetTester tester) {
  final names = <String>[];
  for (final element in find.byType(ChoiceChip).evaluate()) {
    final label = (element.widget as ChoiceChip).label;
    if (label is Text && RegExp(r'\d').hasMatch(label.data ?? '')) names.add(label.data ?? '');
  }
  return names;
}

List<String> orderedClasses(List<String> names) {
  int rank(String name) {
    final hyphen = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(name);
    if (hyphen != null) return int.parse(hyphen.group(1)!) * 100 + int.parse(hyphen.group(2)!);
    final number = RegExp(r'(\d+)').firstMatch(name);
    if (number == null) return 100000;
    return int.parse(number.group(1)!) * 100;
  }
  return [...names]..sort((a, b) => rank(a).compareTo(rank(b)));
}
