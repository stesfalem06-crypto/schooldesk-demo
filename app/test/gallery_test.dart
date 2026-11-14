import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:schooldesk/app_state.dart';
import 'package:schooldesk/screens.dart';
import 'package:schooldesk/shell.dart';
import 'package:schooldesk/theme.dart';
import 'package:schooldesk/vault.dart';

void main() {
  testWidgets('gallery of the main screens', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _shot(tester, '01-admin-home', _home('admin', 'Admin'));
    await _shot(tester, '02-director-home', _home('director', 'Director'));
    await _shot(tester, '03-homeroom-home', _home('teacher', 'Samuel', homeroom: true));
    await _shot(tester, '04-subject-home', _home('teacher', 'Meron'));
    await _shot(tester, '05-fees-by-grade', _page('Fees', _fees()));
    await _shot(tester, '06-marks-grid', _page('Mathematics', _marks(), hint: 'Type a mark and move to the next box. It saves itself.'));
    await _shot(tester, '07-absence-calendar', _page('Absence', _calendar(), hint: 'Tap a day to mark someone away or present.'));
    await _shot(tester, '08-timetable', _page('Week', _week(), hint: 'Drag a lesson into an empty box.'));
    await _shot(tester, '09-setup', _page('Set up school', _setup(), hint: 'Tick these off before the first real day.'));
  });
}

AppModel _model(String role, String name, {bool homeroom = false}) {
  final model = AppModel(Vault());
  model.user = {
    'role': role,
    'display_name': name,
    'homeroom_class_ids': homeroom ? ['c1'] : <String>[],
  };
  model.school = 'Hope Academy';
  model.base = 'http://127.0.0.1:9';
  model.licensed = true;
  model.token = 'token';
  return model;
}

Widget _home(String role, String name, {bool homeroom = false}) {
  final model = _model(role, name, homeroom: homeroom);
  return ChangeNotifierProvider.value(
    value: model,
    child: MaterialApp(theme: schoolTheme(), home: DeskHost(home: const HomeScreen(), pages: rolePages)),
  );
}

Widget _page(String title, Widget body, {String? hint}) {
  final model = _model('admin', 'Admin');
  return ChangeNotifierProvider.value(
    value: model,
    child: MaterialApp(
      theme: schoolTheme(),
      home: SchoolScaffold(title: title, hint: hint, school: 'Hope Academy', body: body),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

Widget _fees() {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      _Info('Whole school', 'Collected 3600 · Left 18900 · 15 students'),
      _Info('Grade 3', 'Collected 1500 · Left 4500 · 4 students'),
      _Info('Grade 8', 'Collected 2100 · Left 2400 · 4 students'),
      _Info('Grade 11', 'Collected 0 · Left 6000 · 4 students'),
    ],
  );
}

Widget _marks() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 64,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 96,
      columns: const [
        DataColumn(label: Text('Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        DataColumn(label: Text('Classwork', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        DataColumn(label: Text('Exam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        DataColumn(label: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      ],
      rows: const [
        DataRow(cells: [
          DataCell(Text('Abel Tesfay', style: TextStyle(fontSize: 16))),
          DataCell(Text('8', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          DataCell(Text('32', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: passGreen))),
          DataCell(Text('80', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: passGreen))),
        ]),
        DataRow(cells: [
          DataCell(Text('Dawit Okbay', style: TextStyle(fontSize: 16))),
          DataCell(Text('4', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          DataCell(Text('12', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: failRed))),
          DataCell(Text('34', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: failRed))),
        ]),
      ],
    ),
  );
}

Widget _calendar() {
  return GridView.count(
    crossAxisCount: 7,
    childAspectRatio: 1.4,
    padding: const EdgeInsets.all(16),
    children: [
      for (final name in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
        Center(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
      for (var d = 1; d <= 28; d++)
        Container(
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: d == 2 || d == 3 || d == 6 ? failRed : card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$d', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: d == 2 || d == 3 || d == 6 ? Colors.white : ink)),
        ),
    ],
  );
}

Widget _week() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      const Text('Step 3 of 3', style: TextStyle(fontSize: 16, color: leaf, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(children: const [
        Expanded(child: _Day('Mon', 'Math\nSamuel')),
        SizedBox(width: 8),
        Expanded(child: _Day('Tue', 'English\nMeron')),
        SizedBox(width: 8),
        Expanded(child: _Day('Wed', '')),
        SizedBox(width: 8),
        Expanded(child: _Day('Thu', 'Science\nSara')),
        SizedBox(width: 8),
        Expanded(child: _Day('Fri', 'Tigrinya\nHanna')),
      ]),
    ]),
  );
}

Widget _setup() {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      ListTile(leading: Icon(Icons.check_circle, color: passGreen, size: 32), title: Text('Grades and sections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      ListTile(leading: Icon(Icons.check_circle, color: passGreen, size: 32), title: Text('Subjects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      ListTile(leading: Icon(Icons.check_circle, color: passGreen, size: 32), title: Text('Teachers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      ListTile(leading: Icon(Icons.radio_button_unchecked, size: 32), title: Text('Yearly fee', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info(this.title, this.sub);
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), subtitle: Text(sub, style: const TextStyle(fontSize: 16))));
  }
}

class _Day extends StatelessWidget {
  const _Day(this.day, this.lesson);
  final String day;
  final String lesson;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: lesson.isEmpty ? const Color(0xFFF7F4EE) : card, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(day, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(lesson, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
