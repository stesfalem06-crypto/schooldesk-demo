import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/shamm_ui.dart';
import 'package:schooldesk/theme.dart';

void main() {
  testWidgets('sign-in by name and PIN', (tester) async {
    await _shot(tester, 'sign-in', const PinLogin(names: ['Hanna Berhe', 'Samuel Ghebremeskel', 'Meron Tesfalem', 'Dawit Okubay']));
  });

  testWidgets('messages', (tester) async {
    await _shot(
      tester,
      'chat',
      const ChatScreen(previewPeople: ['Samuel Ghebremeskel', 'Meron Tesfalem'], previewMessages: ['Staff meeting at the hall']),
    );
  });

  testWidgets('call', (tester) async {
    await _shot(tester, 'call', const CallBoard(name: 'Samuel Ghebremeskel', status: 'Connected'));
  });

  testWidgets('timetable', (tester) async {
    await _shot(
      tester,
      'timetable',
      const TimetableBoard(rows: [
        {'day': 'Monday', 'period': '1', 'class': '1-1', 'subject': 'English', 'teacher': 'Hanna Gebre'},
        {'day': 'Monday', 'period': '2', 'class': '11-1 (Science)', 'subject': 'Mathematics', 'teacher': 'Abel Kifle'},
      ]),
    );
  });

  testWidgets('update', (tester) async {
    await _shot(tester, 'update', const UpdatePrompt());
  });
}

Future<void> _shot(WidgetTester tester, String name, Widget child) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: schoolTheme(), home: child));
  await tester.pump();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/shamm-$name.png'));
}
