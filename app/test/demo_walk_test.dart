import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('every role can open its work', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.main();
    await until(tester, t('Choose who you are'));
    await shot(tester, 'role-chooser');
    await tap(tester, 'School admin');
    await until(tester, t('Dashboard'));
    await shot(tester, 'admin-home');
    await visitAll(tester);
    await tap(tester, 'Fees');
    await until(tester, t('Grade 8'));
    await shot(tester, 'fees');
    await tap(tester, 'Grade 8');
    await until(tester, t('Grade 8A'));
    await tap(tester, 'Grade 8A');
    await until(tester, find.textContaining('Paid'));
    await back(tester);
    await tap(tester, 'Marks & Results');
    await until(tester, t('Grade 8'));
    await tap(tester, 'Make statistics PDFs');
    await until(tester, find.textContaining('Statistics saved'));
    await tap(tester, 'Grade 8');
    await until(tester, t('Grade 8A'));
    await tap(tester, 'Grade 8A');
    await until(tester, find.textContaining('Rank'));
    await shot(tester, 'results');
    await back(tester);
    await tap(tester, 'Attendance');
    await until(tester, t('Samuel Bekele'));
    await shot(tester, 'absence');
    await back(tester);
    await tap(tester, 'Timetable');
    await until(tester, t('Make the week'));
    await tap(tester, find.widgetWithText(FilledButton, 'Make the week'));
    await until(tester, find.textContaining('The week is ready', skipOffstage: false));
    await shot(tester, 'timetable');
    await back(tester);
    await tap(tester, 'Money book');
    await until(tester, t('Add'));
    await tap(tester, 'Add');
    await tap(tester, find.widgetWithText(FilledButton, '5'));
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    await until(tester, t('What was it for?'));
    await tester.enterText(find.byType(TextField).last, 'Books');
    await tap(tester, 'Save');
    await until(tester, find.textContaining('Books'));
    await back(tester);
    await tap(tester, 'Staff');
    await until(tester, t('Add a person'));
    await tap(tester, 'Add a person');
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'New Clerk');
    await tap(tester, 'Save');
    await until(tester, t('New Clerk'));
    await back(tester);
    await tap(tester, 'Settings');
    await until(tester, t('Set up school'));
    await tap(tester, 'Set up school');
    await until(tester, t('Grades and sections'));
    await back(tester);
    await tap(tester, 'Notices');
    await until(tester, t('Staff meeting Friday'));
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Gate closes at 4');
    await tap(tester, 'Post notice');
    await until(tester, t('Gate closes at 4'));
    await back(tester);
    await tap(tester, 'Calendar');
    await until(tester, t('Mid exam'));
    await back(tester);
    await tap(tester, 'Defaulters');
    await until(tester, find.textContaining('Left'));
    await tester.tap(find.textContaining('Left').at(0), warnIfMissed: false);
    await tester.pump();
    await until(tester, t('Receipt saved'));
    await back(tester);
    await tap(tester, 'Subjects');
    await until(tester, find.textContaining('Mathematics'));
    await back(tester);
    await tap(tester, 'Promote');
    await until(tester, t('Grade 1A'));
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Promote').first).onPressed?.call();
    await tester.pump();
    await until(tester, find.textContaining('Moved'));
    await back(tester);
    await tap(tester, 'Switch role');
    await until(tester, t('Choose who you are'));
    await tap(tester, 'Director');
    await until(tester, t('Dashboard'));
    await shot(tester, 'director-home');
    await visitAll(tester);
    await tap(tester, 'Reports');
    await until(tester, t('Save PDF'));
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
    await until(tester, t('Parents evening'));
    await back(tester);
    await tap(tester, 'Switch role');
    await tap(tester, 'Homeroom teacher');
    await until(tester, t('Dashboard'));
    await shot(tester, 'homeroom-home');
    await visitAll(tester);
    await tap(tester, 'Students');
    await until(tester, t('Add a student'));
    await tap(tester, 'Add a student');
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'New Child');
    await tap(tester, 'Save');
    await until(tester, t('New Child'));
    final leave = find.widgetWithText(TextButton, 'Left school');
    tester.widget<TextButton>(leave.last).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final yes = find.widgetWithText(FilledButton, 'Yes');
    expect(yes, findsWidgets);
    tester.widget<FilledButton>(yes.last).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tap(tester, 'Save');
    await until(tester, find.textContaining('Left'));
    await back(tester);
    await tap(tester, 'Attendance');
    await until(tester, find.textContaining('%'));
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mark here').first).onPressed?.call();
    await tester.pump();
    await until(tester, t('Attendance saved'));
    await back(tester);
    await tap(tester, 'Reports');
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Print class list').first).onPressed?.call();
    await tester.pump();
    await until(tester, t('Class list saved'));
    await back(tester);
    await tap(tester, 'Marks & Results');
    await until(tester, find.textContaining('Mathematics'));
    await tap(tester, find.textContaining('Mathematics'));
    await until(tester, find.byType(TextFormField));
    await shot(tester, 'marks');
    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    await back(tester);
    await tap(tester, 'Fees');
    await until(tester, find.textContaining('Paid'));
    await back(tester);
    await tap(tester, 'Switch role');
    await tap(tester, 'Subject teacher');
    await until(tester, t('Dashboard'));
    await shot(tester, 'subject-home');
    await visitAll(tester);
    await tap(tester, 'Marks & Results');
    await until(tester, find.textContaining('English'));
    final english = find.ancestor(of: find.textContaining('English').first, matching: find.byType(ListTile));
    tester.widget<ListTile>(english.first).onTap?.call();
    await tester.pump();
    await until(tester, find.byType(TextFormField));
    expect(t('Unlock'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Finder t(String text) => find.text(text, skipOffstage: false);

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80; i++) {
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
    final row = find.byKey(Key('row-$target'));
    if (row.evaluate().isNotEmpty) {
      tester.widget<ListTile>(row.last).onTap?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
    final navItem = find.byKey(Key('nav-$target'));
    if (navItem.evaluate().isNotEmpty) {
      await tester.ensureVisible(navItem.first);
      await tester.tap(navItem.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
    final key = find.byKey(Key('action-$target'), skipOffstage: false);
    await tester.pump();
    if (key.evaluate().isNotEmpty) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
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
  final finder = target is Finder ? target : t(target as String);
  await until(tester, finder);
  final which = finder.at(finder.evaluate().length - 1);
  final matched = tester.widget(which);
  if (matched is FilledButton) {
    matched.onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return;
  }
  await tester.ensureVisible(which);
  final filled = find.ancestor(of: which, matching: find.byType(FilledButton));
  if (filled.evaluate().isNotEmpty) {
    tester.widget<FilledButton>(filled.last).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return;
  }
  final textButton = find.ancestor(of: which, matching: find.byType(TextButton));
  if (textButton.evaluate().isNotEmpty) {
    tester.widget<TextButton>(textButton.last).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return;
  }
  final tile = find.ancestor(of: which, matching: find.byType(ListTile));
  if (tile.evaluate().isNotEmpty && tester.widget<ListTile>(tile.last).onTap != null) {
    tester.widget<ListTile>(tile.last).onTap!.call();
  } else {
    await tester.tap(which, warnIfMissed: false);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> visitAll(WidgetTester tester) async {
  final labels = <String>[];
  for (final element in find.byType(InkWell).evaluate()) {
    final key = element.widget.key;
    if (key is ValueKey && '${key.value}'.startsWith('nav-')) labels.add('${key.value}'.substring(4));
  }
  for (final label in labels) {
    await tap(tester, label);
    await tester.pump(const Duration(milliseconds: 80));
    final problem = tester.takeException();
    if (problem != null) fail('$label: $problem');
    expect(find.byType(Scrollable), findsWidgets, reason: '$label was blank');
  }
  await tap(tester, 'Dashboard');
}

Future<void> back(WidgetTester tester) async {
  NavigatorState? target;
  for (final element in find.byType(Navigator).evaluate()) {
    final state = tester.state<NavigatorState>(find.byWidget(element.widget));
    if (state.canPop()) target = state;
  }
  target?.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> shot(WidgetTester tester, String name) async {
  debugPrint('screen $name');
  await tester.pump();
}
