import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('every role can open its work', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    app.main();
    await until(tester, find.text('Choose who you are'));
    await shot(binding, 'role-chooser');
    await tap(tester, 'School admin');
    await until(tester, find.textContaining('Hello, School admin'));
    await shot(binding, 'admin-home');
    await tap(tester, 'See fees');
    await until(tester, find.text('Grade 8'));
    await shot(binding, 'fees');
    await tap(tester, 'Grade 8');
    await until(tester, find.text('Grade 8A'));
    await tap(tester, 'Grade 8A');
    await until(tester, find.textContaining('Paid'));
    await back(tester);
    await tap(tester, 'See results');
    await until(tester, find.text('Grade 8'));
    await tap(tester, 'Grade 8');
    await tap(tester, 'Grade 8A');
    await until(tester, find.textContaining('Rank'));
    await shot(binding, 'results');
    await tap(tester, 'Make statistics PDFs');
    await until(tester, find.text('Statistics saved'));
    await back(tester);
    await tap(tester, 'Who is away');
    await until(tester, find.text('Samuel Bekele'));
    await shot(binding, 'absence');
    await back(tester);
    await tap(tester, 'Plan week');
    await until(tester, find.text('Make the week'));
    await tap(tester, 'Make the week');
    await until(tester, find.text('The week is ready'));
    await shot(binding, 'timetable');
    await back(tester);
    await tap(tester, 'Money book');
    await until(tester, find.text('Add'));
    await tap(tester, 'Add');
    await tap(tester, '5');
    await tap(tester, 'Save');
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
    await tester.tap(find.textContaining('Left').at(0));
    await tester.pump();
    await until(tester, find.text('Receipt saved'));
    await back(tester);
    await tap(tester, 'Subjects');
    await until(tester, find.textContaining('Mathematics'));
    await back(tester);
    await tap(tester, 'Promote');
    await until(tester, find.text('Grade 1A'));
    await tester.tap(find.widgetWithText(FilledButton, 'Promote').at(0));
    await tester.pump();
    await tap(tester, 'Yes');
    await until(tester, find.textContaining('Moved'));
    await back(tester);
    await tap(tester, 'Switch role');
    await until(tester, find.text('Choose who you are'));
    await tap(tester, 'Director');
    await until(tester, find.textContaining('Hello, Director'));
    await shot(binding, 'director-home');
    await tap(tester, 'Make report');
    await until(tester, find.text('Save PDF'));
    await shot(binding, 'report');
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
    await shot(binding, 'homeroom-home');
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
    await tap(tester, 'Mark here');
    await until(tester, find.text('Attendance saved'));
    await back(tester);
    await tap(tester, 'Report cards');
    await tap(tester, 'Print class list');
    await until(tester, find.text('Class list saved'));
    await back(tester);
    await tap(tester, 'Enter marks');
    await until(tester, find.textContaining('Mathematics'));
    await tap(tester, find.textContaining('Mathematics'));
    await until(tester, find.byType(TextFormField));
    await shot(binding, 'marks');
    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    await back(tester);
    await tap(tester, 'Take fees');
    await until(tester, find.textContaining('Paid'));
    await tester.tap(find.textContaining('Paid').at(0));
    await tester.pump();
    await tap(tester, '1');
    await tap(tester, '0');
    await tap(tester, '0');
    await tap(tester, 'Save');
    await until(tester, find.text('Payment saved'));
    await back(tester);
    await tap(tester, 'Switch role');
    await tap(tester, 'Subject teacher');
    await until(tester, find.textContaining('Hello, Meron'));
    await shot(binding, 'subject-home');
    await tap(tester, 'Enter marks');
    await until(tester, find.textContaining('English'));
    await tester.tap(find.textContaining('English').at(0));
    await until(tester, find.byType(TextFormField));
    expect(find.text('Unlock'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Did not find $finder');
}

Future<void> tap(WidgetTester tester, dynamic target) async {
  final finder = target is Finder ? target : find.text(target as String);
  await until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> back(WidgetTester tester) async {
  final button = find.byTooltip('Back');
  if (button.evaluate().isEmpty) {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
  } else {
    await tester.tap(button.first);
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> shot(IntegrationTestWidgetsFlutterBinding binding, String name) async {
  final bytes = await binding.takeScreenshot(name);
  final dir = Directory(Platform.environment['SCHOOLDESK_SHOTS'] ?? 'build/demo-shots');
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(bytes);
}
