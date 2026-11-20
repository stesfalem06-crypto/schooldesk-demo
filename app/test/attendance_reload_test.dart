import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:schooldesk/app_state.dart';
import 'package:schooldesk/demo_extra.dart';
import 'package:schooldesk/edition.dart';
import 'package:schooldesk/roll_entry.dart';
import 'package:schooldesk/school_book.dart';
import 'package:schooldesk/vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reloaded school still lists class 1-1 and marks 2, 5 absent', () async {
    final dir = Directory.systemTemp.createTempSync('sd-att-reload');
    final book = await SchoolBook.open(directory: dir.path);
    book.loadNow();
    book.setActor('admin');

    final day = _today();
    final first = _sheet(book, day);
    expect(first.names, containsAll(['Amanuel Araya', 'Biniam Haile', 'Genet Weldemichael']));
    expect(first.rolls['Amanuel Araya'], 1);
    expect(first.rolls['Biniam Haile'], 2);
    expect(first.rolls['Genet Weldemichael'], 5);
    expect(first.enrolled, 10);
    expect(first.percent, greaterThan(0));

    final saved = book.callNow('POST', '/api/v1/attendance/numbers', {
      'class_id': first.classId,
      'date': day,
      'text': '2, 5',
    }) as Map;
    expect((saved['matched'] as List).map((row) => (row as Map)['full_name']).toList(), ['Biniam Haile', 'Genet Weldemichael']);
    expect(saved['unknown'], isEmpty);

    book.loadNow();
    book.setActor('admin');
    final again = _sheet(book, day);
    expect(again.classId, first.classId);
    expect(again.names, containsAll(['Amanuel Araya', 'Biniam Haile', 'Genet Weldemichael']));
    expect(again.rolls['Biniam Haile'], 2);
    expect(again.rolls['Genet Weldemichael'], 5);
    expect(again.enrolled, 10);
    final absent = (again.sheet['marks'] as List).cast<Map>().where((row) => row['present'] == false).map((row) => row['roll_number']).toList();
    expect(absent, containsAll([2, 5]));

    final lessons = (book.callNow('GET', '/api/v1/class-subjects', null) as List).cast<Map>().where((l) => l['class_id'].toString() == again.classId).toList();
    expect(lessons, isNotEmpty);
    final marks = book.callNow('GET', '/api/v1/assessments?class_subject_id=${lessons.first['id']}', null) as List;
    expect(marks, isNotEmpty);
  });

  testWidgets('attendance and marks by number keep class 1-1 after reload', (tester) async {
    if (!demoEdition) return;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('sd-att-reload-ui');
    await SchoolBook.open(directory: dir.path);
    SchoolBook.instance.loadNow();
    final model = AppModel(Vault());
    model.enterRole('admin');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: model,
      child: const MaterialApp(home: AttendanceScreen(smokeClassName: '1-1', smokeNumbers: '2, 5')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Amanuel Araya'), findsWidgets);
    expect(find.textContaining('Biniam Haile'), findsWidgets);
    expect(find.textContaining('Genet Weldemichael'), findsWidgets);
    expect(find.textContaining('Absent today: Biniam Haile, Genet Weldemichael'), findsWidgets);
    expect(find.text('No students in this class yet'), findsNothing);
    expect(find.textContaining('No student with number'), findsNothing);
    expect(find.textContaining('Present today 0'), findsNothing);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: model,
      child: const MaterialApp(home: RollMarkScreen(smokeClassName: '1-1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Amanuel Araya'), findsOneWidget);
    expect(find.text('Score'), findsWidgets);
  });
}

class _ClassSheet {
  _ClassSheet(this.classId, this.sheet, this.names, this.rolls);
  final String classId;
  final Map sheet;
  final List<String> names;
  final Map<String, int> rolls;
  int get enrolled => (sheet['enrolled'] as num).toInt();
  num get percent => sheet['percent'] as num;
}

_ClassSheet _sheet(SchoolBook book, String day) {
  final classes = (book.callNow('GET', '/api/v1/classes', null) as List).cast<Map>();
  final cls = classes.firstWhere((c) => c['name'] == '1-1');
  final classId = cls['id'].toString();
  final people = (book.callNow('GET', '/api/v1/students?class_id=$classId', null) as List).cast<Map>();
  final active = people.where((s) => s['dropped_out'] != true).toList();
  final sheet = book.callNow('GET', '/api/v1/attendance?class_id=$classId&date=$day', null) as Map;
  expect((sheet['students'] as List).length, active.length);
  return _ClassSheet(
    classId,
    sheet,
    [for (final student in active) student['full_name'].toString()],
    {for (final student in active) student['full_name'].toString(): (student['roll_no'] as num).toInt()},
  );
}

String _today() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
