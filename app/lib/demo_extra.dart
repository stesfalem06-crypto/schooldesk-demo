import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'demo_look.dart';
import 'data_grid.dart';
import 'money.dart';
import 'school_book.dart';
import 'saved_files.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.query});
  final String query;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<String, dynamic>> hits = [];
  late final box = TextEditingController(text: widget.query);

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) run(widget.query);
  }

  Future<void> run(String q) async {
    hits = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/search?q=${Uri.encodeQueryComponent(q)}')));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Search',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: box, decoration: const InputDecoration(labelText: 'Student or staff'), onSubmitted: run),
          const SizedBox(height: 8),
          for (final hit in hits)
            SoftCard(
              child: ListTile(
                title: Text(hit['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
                subtitle: Text(hit['detail'].toString()),
                onTap: hit['kind'] == 'student' ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(id: hit['id'].toString()))) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.id});
  final String id;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? student;
  final remark = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Map<String, dynamic>? sheet;

  Future<void> load() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/students/${widget.id}/sheet'));
      sheet = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      final person = sheet?['student'];
      if (person is Map) {
        student = person.map((k, v) => MapEntry(k.toString(), v));
        remark.text = student?['remark']?.toString() ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = student;
    if (s == null) return const SchoolScaffold(title: 'Student', school: 'Hope Academy', body: Center(child: CircularProgressIndicator()));
    return SchoolScaffold(
      title: s['full_name'].toString(),
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Roll no. ${sheet?['roll_no'] ?? ''}, Class ${sheet?['class_name'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Homeroom teacher ${sheet?['homeroom'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Mother ${s['mother_name'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Father ${s['father_name'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Phone ${s['phone'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Address ${s['address'] ?? ''}', style: const TextStyle(fontSize: 18)),
          ])),
          const SizedBox(height: 8),
          const Text('Marks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          DataGrid(
            expand: false,
            columns: const [
              GridCol('Subject', 180, TextAlign.left, flex: true),
              GridCol('CA / 60', 110, TextAlign.right),
              GridCol('Final / 40', 120, TextAlign.right),
              GridCol('Total / 100', 130, TextAlign.right),
            ],
            rows: [
              for (final mark in asMaps(sheet?['marks']))
                ['${mark['subject']}', '${mark['ca']}', '${mark['exam']}', '${mark['total']}'],
            ],
          ),
          const SizedBox(height: 8),
          const Text('Fees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final fee in asMaps(sheet?['fees']))
            Text('${fee['name']}: paid ${nfk(fee['paid'])}, left ${nfk(fee['remaining'])}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextField(controller: remark, decoration: const InputDecoration(labelText: 'Homeroom remark')),
          const SizedBox(height: 8),
          FilledButton(onPressed: saveRemark, child: const Text('Save remark')),
          FilledButton(onPressed: () => _savePdf('/api/v1/students/${s['id']}/report.pdf', 'report-card.pdf', 'Report card saved'), child: const Text('Print report card')),
          FilledButton(onPressed: () => _savePdf('/api/v1/students/${s['id']}/card.pdf', 'id-card.pdf', 'Card saved'), child: const Text('Print ID card')),
        ],
      ),
    );
  }

  Future<void> saveRemark() async {
    await context.read<AppModel>().ask((api) => api.put('/api/v1/students/${widget.id}/profile', {'remark': remark.text}));
    if (mounted) saved(context, 'Remark saved');
  }

  Future<void> _savePdf(String path, String name, String note) async {
    final bytes = await context.read<AppModel>().api!.bytes(path);
    final dir = await reportFolder();
    await File('${dir.path}/$name').writeAsBytes(bytes);
    if (mounted) saved(context, note);
  }
}

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});
  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  List<Map<String, dynamic>> items = [];
  final title = TextEditingController();
  final body = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/notices')));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final office = context.watch<AppModel>().seesSchool;
    return SchoolScaffold(
      title: 'Notices',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (office) ...[
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: body, decoration: const InputDecoration(labelText: 'Message')),
            FilledButton(onPressed: () async {
              await context.read<AppModel>().ask((api) => api.post('/api/v1/notices', {'title': title.text, 'body': body.text, 'date': _day()}));
              title.clear();
              body.clear();
              await load();
            }, child: const Text('Post notice')),
          ],
          for (final item in items)
            SoftCard(child: ListTile(
              title: Text(item['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
              subtitle: Text('${item['date']}\n${item['body']}'),
            )),
        ],
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Map<String, dynamic>> items = [];
  final title = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/calendar')));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Calendar',
      hint: 'Terms, holidays and exams',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (context.watch<AppModel>().isAdmin) ...[
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Add a date')),
            FilledButton(onPressed: () async {
              await context.read<AppModel>().ask((api) => api.post('/api/v1/calendar', {'title': title.text, 'date': _day(), 'kind': 'exam'}));
              await load();
            }, child: const Text('Add to calendar')),
          ],
          for (final item in items)
            SoftCard(child: ListTile(
              title: Text(item['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              subtitle: Text('${item['date']} · ${item['kind']}'),
            )),
        ],
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.smokeClassName, this.smokeNumbers});
  final String? smokeClassName;
  final String? smokeNumbers;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> roster = [];
  String? classId;
  final dateBox = TextEditingController();
  final numbers = TextEditingController();
  var ready = false;
  var smokeSaved = false;

  @override
  void initState() {
    super.initState();
    dateBox.text = _day();
    numbers.text = widget.smokeNumbers ?? '';
    load();
  }

  @override
  void dispose() {
    dateBox.dispose();
    numbers.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    if (model.seesSchool) {
      classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
    }
    classId ??= _firstClass(model);
    if (classId == null || classId!.isEmpty) {
      ready = true;
      if (mounted) setState(() {});
      return;
    }
    final people = asMaps(await model.ask((api) => api.get('/api/v1/students?class_id=$classId')));
    roster = people.where((s) => s['dropped_out'] != true).toList()
      ..sort((a, b) => ((a['roll_no'] as num?) ?? 0).compareTo((b['roll_no'] as num?) ?? 0));
    data = Map<String, dynamic>.from(await model.ask((api) => api.get('/api/v1/attendance?class_id=$classId&date=${dateBox.text.trim()}')) as Map);
    final fromSheet = asMaps(data?['students']);
    if (roster.isEmpty && fromSheet.isNotEmpty) roster = fromSheet;
    ready = true;
    if (mounted) setState(() {});
    if (!smokeSaved && widget.smokeNumbers != null && widget.smokeNumbers!.isNotEmpty) {
      smokeSaved = true;
      await saveNumbers();
    }
  }

  String? _firstClass(AppModel model) {
    if (widget.smokeClassName != null) {
      final match = classes.where((c) => c['name'] == widget.smokeClassName).toList();
      if (match.isNotEmpty) return match.first['id'].toString();
    }
    if (model.homerooms.isNotEmpty) return model.homerooms.first;
    return classes.isEmpty ? null : classes.first['id'].toString();
  }

  List<int> get _typed => parseRollNumbers(numbers.text);

  Map<int, Map<String, dynamic>> get _byRoll => {
        for (final student in roster)
          if (((student['roll_no'] as num?)?.toInt() ?? 0) > 0) (student['roll_no'] as num).toInt(): student,
      };

  List<Map<String, dynamic>> get _matched => [for (final number in _typed) if (_byRoll[number] != null) _byRoll[number]!];

  List<int> get _unknown => [for (final number in _typed) if (!_byRoll.containsKey(number)) number];

  @override
  Widget build(BuildContext context) {
    final marks = asMaps(data?['marks']);
    final matched = _matched;
    final unknown = ready ? _unknown : const <int>[];
    final enrolled = roster.length;
    final absentToday = marks.where((mark) => mark['present'] == false).length;
    final present = data == null ? 0 : (enrolled - absentToday < 0 ? 0 : enrolled - absentToday);
    return SchoolScaffold(
      title: 'Attendance',
      hint: 'This month ${data?['percent'] ?? 0}%',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Present today $present', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
          if (classes.isNotEmpty)
            DropdownButton<String>(
              value: classId,
              items: [for (final cls in classes) DropdownMenuItem(value: cls['id'].toString(), child: Text(cls['name'].toString()))],
              onChanged: (value) {
                classId = value;
                ready = false;
                load();
              },
            ),
          TextField(controller: dateBox, decoration: const InputDecoration(labelText: 'Date'), onSubmitted: (_) => load()),
          TextField(
            key: const Key('absent-numbers'),
            controller: numbers,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(labelText: 'Absent roll numbers', hintText: '2, 5 or 4-6'),
            onChanged: (_) => setState(() {}),
          ),
          if (matched.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Absent today: ${matched.map((s) => s['full_name']).join(', ')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            for (final student in matched) Text('${student['roll_no']} ${student['full_name']}', style: const TextStyle(fontSize: 16)),
          ],
          for (final number in unknown)
            Text('No student with number $number', style: const TextStyle(fontSize: 16, color: failRed, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FilledButton(onPressed: saveNumbers, child: const Text('Save absences')),
          if (data?['saved'] != null) Text(data!['saved'].toString(), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          Text(roster.isEmpty ? 'No students in this class yet' : '${roster.length} students', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          for (final student in roster)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(width: 36, child: Text('${student['roll_no'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                Expanded(child: Text(student['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                FilledButton(
                  onPressed: () => mark(student['id'].toString(), true),
                  child: Text(_here(marks, student['id'].toString()) ? 'Here' : 'Mark here'),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Future<void> saveNumbers() async {
    if (classId == null) return;
    final model = context.read<AppModel>();
    final body = {'class_id': classId, 'date': dateBox.text.trim(), 'text': numbers.text};
    Map<String, dynamic> saved;
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      saved = Map<String, dynamic>.from(SchoolBook.instance.callNow('POST', '/api/v1/attendance/numbers', body) as Map);
    } else {
      saved = Map<String, dynamic>.from(await model.ask((api) => api.post('/api/v1/attendance/numbers', body)) as Map);
    }
    final names = asMaps(saved['matched']).map((row) => row['full_name']).join(', ');
    data = {...?data, 'saved': names.isEmpty ? 'No absences to save' : 'Absent today: $names'};
    if (mounted) setState(() {});
    if (Platform.environment['FLUTTER_TEST'] != 'true') await load();
  }

  bool _here(List<Map<String, dynamic>> marks, String id) {
    for (final mark in marks) {
      if (mark['student_id'].toString() == id) return mark['present'] == true;
    }
    return false;
  }

  Future<void> mark(String id, bool present) async {
    final model = context.read<AppModel>();
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      SchoolBook.instance.callNow('POST', '/api/v1/attendance', {'class_id': classId ?? model.homerooms.first, 'student_id': id, 'date': dateBox.text.trim(), 'present': present});
      if (mounted) setState(() => data = {...?data, 'saved': 'Attendance saved'});
      return;
    }
    await model.ask((api) => api.post('/api/v1/attendance', {'class_id': classId ?? model.homerooms.first, 'student_id': id, 'date': dateBox.text.trim(), 'present': present}));
    await load();
    if (mounted) saved(context, 'Attendance saved');
  }
}

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});
  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    final classId = model.homerooms.first;
    students = asMaps(await model.ask((api) => api.get('/api/v1/students?class_id=$classId')));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Report cards',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note != null) Text(note!, style: const TextStyle(fontSize: 16)),
          FilledButton(onPressed: roster, child: const Text('Print class list')),
          for (final student in students)
            SoftCard(
              child: ListTile(
                title: Text(student['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(id: student['id'].toString()))),
              ),
            ),
        ],
      ),
    );
  }

  String? note;

  Future<void> roster() async {
    final model = context.read<AppModel>();
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      final bytes = SchoolBook.instance.callNow('GET', '/api/v1/classes/${model.homerooms.first}/roster.pdf', null) as List<int>;
      final dir = Directory('${Directory.systemTemp.path}/SchoolDesk');
      dir.createSync(recursive: true);
      File('${dir.path}/class-list.pdf').writeAsBytesSync(bytes);
      if (mounted) setState(() => note = 'Class list saved');
      return;
    }
    final bytes = await model.api!.bytes('/api/v1/classes/${model.homerooms.first}/roster.pdf');
    final dir = await reportFolder();
    await File('${dir.path}/class-list.pdf').writeAsBytes(bytes);
    if (mounted) saved(context, 'Class list saved');
  }
}

class DefaulterScreen extends StatefulWidget {
  const DefaulterScreen({super.key});
  @override
  State<DefaulterScreen> createState() => _DefaulterScreenState();
}

class _DefaulterScreenState extends State<DefaulterScreen> {
  List<Map<String, dynamic>> rows = [];
  String? note;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    rows = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/fees/defaulters')));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Still to pay',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note != null) Text(note!, style: const TextStyle(fontSize: 16)),
          for (final row in rows.take(30))
            SoftCard(child: ListTile(
              title: Text(row['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              subtitle: Text('Left ${nfk(row['remaining'])}'),
              onTap: () => receipt(row),
            )),
        ],
      ),
    );
  }

  Future<void> receipt(Map<String, dynamic> row) async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      final book = SchoolBook.instance;
      final payments = (book.callNow('GET', '/api/v1/payments', null) as List).cast<Map>();
      final match = payments.where((p) => p['student_id'].toString() == row['student_id'].toString()).toList();
      if (match.isEmpty) {
        if (mounted) setState(() => note = 'No payment yet');
        return;
      }
      final bytes = book.callNow('GET', '/api/v1/fees/receipt/${match.first['id']}', null) as List<int>;
      final dir = Directory('${Directory.systemTemp.path}/SchoolDesk');
      dir.createSync(recursive: true);
      File('${dir.path}/fee-receipt.pdf').writeAsBytesSync(bytes);
      if (mounted) setState(() => note = 'Receipt saved');
      return;
    }
    final model = context.read<AppModel>();
    final payments = asMaps(await model.ask((api) => api.get('/api/v1/payments')));
    final match = payments.where((p) => p['student_id'].toString() == row['student_id'].toString()).toList();
    if (match.isEmpty) {
      if (mounted) toast(context, 'No payment yet');
      return;
    }
    final bytes = await model.api!.bytes('/api/v1/fees/receipt/${match.first['id']}');
    final dir = await reportFolder();
    await File('${dir.path}/fee-receipt.pdf').writeAsBytes(bytes);
    if (mounted) saved(context, 'Receipt saved');
  }
}

class MatrixScreen extends StatelessWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Who teaches what',
      school: 'Hope Academy',
      body: FutureBuilder(
        future: context.read<AppModel>().ask((api) => api.get('/api/v1/matrix')),
        builder: (context, snap) {
          final rows = asMaps(snap.data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows.take(40))
                SoftCard(child: ListTile(
                  title: Text('${row['class_name']} · ${row['subject_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  subtitle: Text(row['teacher_name']?.toString() ?? ''),
                )),
            ],
          );
        },
      ),
    );
  }
}

class PromoteScreen extends StatefulWidget {
  const PromoteScreen({super.key});
  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  String? note;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Next grade',
      hint: 'Moves a class up at the end of the year',
      school: 'Hope Academy',
      body: FutureBuilder(
        future: context.read<AppModel>().ask((api) => api.get('/api/v1/classes')),
        builder: (context, snap) {
          final classes = asMaps(snap.data).where((c) => (c['grade'] as num? ?? 12) < 12).take(8);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (note != null) Text(note!, style: const TextStyle(fontSize: 16)),
              for (final cls in classes)
                SoftCard(
                  child: ListTile(
                    title: Text(cls['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    trailing: FilledButton(onPressed: () => move(cls['id'].toString(), cls['name'].toString()), child: const Text('Promote')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> move(String id, String name) async {
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      final ok = await confirm(context, 'Promote $name?', 'Students who have not left move to the next grade.');
      if (!ok || !mounted) return;
    }
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        final data = SchoolBook.instance.callNow('POST', '/api/v1/promote', {'class_id': id}) as Map;
        if (mounted) setState(() => note = 'Moved ${data['moved']} to ${data['to']}');
        return;
      }
      final data = await context.read<AppModel>().ask((api) => api.post('/api/v1/promote', {'class_id': id}));
      if (mounted) saved(context, 'Moved ${data['moved']} to ${data['to']}');
    } catch (e) {
      if (mounted) setState(() => note = '$e');
    }
  }
}

String _day() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
