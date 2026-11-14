import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('every role can open its work', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.main();
    await until(tester, find.text('Choose who you are'));
    await shot(tester, 'role-chooser');
    await tap(tester, 'School admin');
    await until(tester, find.textContaining('Hello, School admin', skipOffstage: false));
    await shot(tester, 'admin-home');
    await tap(tester, 'See fees');
    await until(tester, find.text('Grade 8'));
    await shot(tester, 'fees');
    await tap(tester, 'Grade 8');
    await until(tester, find.text('Grade 8A'));
    await tap(tester, 'Grade 8A');
    await until(tester, find.textContaining('Paid'));
    await back(tester);
    await tap(tester, 'See results');
    await until(tester, find.text('Grade 8'));
    await tap(tester, 'Make statistics PDFs');
    await until(tester, find.textContaining('Statistics saved'));
    await tap(tester, find.widgetWithText(ListTile, 'Grade 8'));
    await until(tester, find.widgetWithText(ListTile, 'Grade 8A'));
    await tap(tester, find.widgetWithText(ListTile, 'Grade 8A'));
    await until(tester, find.textContaining('Rank'));
    await shot(tester, 'results');
    await back(tester);
    await tap(tester, 'Who is away');
    await until(tester, find.text('Samuel Bekele'));
    await shot(tester, 'absence');
    await back(tester);
    await tap(tester, 'Plan week');
    await until(tester, find.text('Make the week'));
    await tap(tester, find.widgetWithText(FilledButton, 'Make the week'));
    await until(tester, find.textContaining('The week is ready', skipOffstage: false));
    await shot(tester, 'timetable');
    await back(tester);
    await tap(tester, 'Money book');
    await until(tester, find.text('Add'));
    await tap(tester, 'Add');
    await tap(tester, find.widgetWithText(FilledButton, '5'));
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    await until(tester, find.text('What was it for?'));
    await tester.enterText(find.byType(TextField).last, 'Books');
    await tap(tester, 'Save');
    await until(tester, find.textContaining('Books'));
    await back(tester);
    await tap(tester, 'Staff list');
    await until(tester, find.text('Add a person'));
    await tap(tester, 'Add a person');
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'New Clerk');
    await tap(tester, 'Save');
    await until(tester, find.text('New Clerk'));
    await back(tester);
    await tap(tester, 'Set up school');
    await until(tester, find.text('Grades and sections'));
    await back(tester);
    await tap(tester, 'Notices');
    await until(tester, find.text('Staff meeting Friday'));
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gate closes at 4');
    await tap(tester, 'Post notice');
    await until(tester, find.text('Gate closes at 4'));
    await back(tester);
    await tap(tester, 'Calendar');
    await until(tester, find.text('Mid exam'));
    await back(tester);
    await tap(tester, 'Defaulters');
    await until(tester, find.textContaining('Left'));
    await tester.tap(find.textContaining('Left').at(0), warnIfMissed: false);
    await tester.pump();
    await until(tester, find.text('Receipt saved'));
    await back(tester);
    await tap(tester, 'Subjects');
    await until(tester, find.textContaining('Mathematics'));
    await back(tester);
    await tap(tester, 'Promote');
    await until(tester, find.text('Grade 1A'));
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Promote').first).onPressed?.call();
    await tester.pump();
    await until(tester, find.textContaining('Moved'));
    await back(tester);
    await tap(tester, 'Switch role');
    await until(tester, find.text('Choose who you are'));
    await tap(tester, 'Director');
    await until(tester, find.textContaining('Hello, Director'));
    await shot(tester, 'director-home');
    await tap(tester, 'Make report');
    await until(tester, find.text('Save PDF'));
    await shot(tester, 'report');
    await tap(tester, 'Save PDF');
    await until(tester, find.textContaining('SchoolDesk-report.pdf'));
    await tap(tester, 'Save Word');
    await until(tester, find.textContaining('SchoolDesk-report.docx'));
    await tap(tester, 'Save PowerPoint');
    await until(tester, find.textContaining('SchoolDesk-report.pptx'));
    await back(tester);
    await tap(tester, 'Meetings');
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Parents evening');
    await tester.enterText(find.widgetWithText(TextField, 'Who came'), 'Grade 8 families');
    await tap(tester, 'Save meeting');
    await until(tester, find.text('Parents evening'));
    await back(tester);
    await tap(tester, 'Switch role');
    await tap(tester, 'Homeroom teacher');
    await until(tester, find.textContaining('Hello, Samuel'));
    await shot(tester, 'homeroom-home');
    await tap(tester, 'My class');
    await until(tester, find.text('Add a student'));
    await tap(tester, 'Add a student');
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'New Child');
    await tap(tester, 'Save');
    await until(tester, find.text('New Child'));
    await tap(tester, 'Left school');
    await tap(tester, 'Yes');
    await tap(tester, 'Save');
    await until(tester, find.textContaining('Left'));
    await back(tester);
    await tap(tester, 'Attendance');
    await until(tester, find.textContaining('%'));
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mark here').first).onPressed?.call();
    await tester.pump();
    await until(tester, find.text('Attendance saved'));
    await back(tester);
    await tap(tester, 'Report cards');
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Print class list').first).onPressed?.call();
    await tester.pump();
    await until(tester, find.text('Class list saved'));
    await back(tester);
    await tap(tester, 'Enter marks');
    await until(tester, find.textContaining('Mathematics'));
    await tap(tester, find.textContaining('Mathematics'));
    await until(tester, find.byType(TextFormField));
    await shot(tester, 'marks');
    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    await back(tester);
    await tap(tester, 'Take fees');
    await until(tester, find.textContaining('Paid'));
    await back(tester);
    await tap(tester, 'Switch role');
    await tap(tester, 'Subject teacher');
    await until(tester, find.textContaining('Hello, Meron'));
    await shot(tester, 'subject-home');
    await tap(tester, 'Enter marks');
    await until(tester, find.textContaining('English'));
    final english = find.ancestor(of: find.textContaining('English').first, matching: find.byType(ListTile));
    tester.widget<ListTile>(english.first).onTap?.call();
    await tester.pump();
    await until(tester, find.byType(TextFormField));
    expect(find.text('Unlock'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  debugDumpApp();
  fail('Did not find $finder');
}

Future<void> tap(WidgetTester tester, dynamic target) async {
  if (target is String) {
    final role = find.byKey(Key('role-$target'), skipOffstage: false);
    if (role.evaluate().isNotEmpty) {
      tester.widget<InkWell>(role).onTap?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
  }
  if (target == 'Switch role') {
    final button = find.widgetWithText(TextButton, 'Switch role');
    tester.widget<TextButton>(button.first).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return;
  }
  if (target is String) {
    final key = find.byKey(Key('action-$target'), skipOffstage: false);
    await tester.pump();
    if (key.evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 5));
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      while (nav.canPop()) {
        nav.pop();
      }
      await tester.pump();
      final inks = find.descendant(of: key, matching: find.byType(InkWell), skipOffstage: false);
      if (inks.evaluate().isNotEmpty) {
        tester.widget<InkWell>(inks.first).onTap?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        return;
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
  }
  final finder = target is Finder ? target : find.text(target as String);
  await until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> back(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (nav.canPop()) nav.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> shot(WidgetTester tester, String name) async {
  debugPrint('screen $name');
  await tester.pump();
}
