import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'demo_look.dart';
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

  Future<void> load() async {
    final all = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/students')));
    final found = all.where((s) => s['id'].toString() == widget.id).toList();
    if (found.isNotEmpty) {
      student = found.first;
      remark.text = student?['remark']?.toString() ?? '';
    }
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
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mother ${s['mother_name'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Father ${s['father_name'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Phone ${s['phone'] ?? ''}', style: const TextStyle(fontSize: 18)),
            Text('Address ${s['address'] ?? ''}', style: const TextStyle(fontSize: 18)),
          ])),
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
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    final classId = model.homerooms.isEmpty ? '' : model.homerooms.first;
    data = Map<String, dynamic>.from(await model.ask((api) => api.get('/api/v1/attendance?class_id=$classId&date=${_day()}')) as Map);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final students = asMaps(data?['students']);
    final marks = asMaps(data?['marks']);
    return SchoolScaffold(
      title: 'Attendance',
      hint: 'This month ${data?['percent'] ?? 0}%',
      school: 'Hope Academy',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Present today ${data?['present'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
          for (final student in students)
            SoftCard(
              child: Row(children: [
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

  bool _here(List<Map<String, dynamic>> marks, String id) {
    for (final mark in marks) {
      if (mark['student_id'].toString() == id) return mark['present'] == true;
    }
    return false;
  }

  Future<void> mark(String id, bool present) async {
    final model = context.read<AppModel>();
    await model.ask((api) => api.post('/api/v1/attendance', {'class_id': model.homerooms.first, 'student_id': id, 'date': _day(), 'present': present}));
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

  Future<void> roster() async {
    final model = context.read<AppModel>();
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
          for (final row in rows.take(30))
            SoftCard(child: ListTile(
              title: Text(row['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              subtitle: Text('Left ${row['remaining']}'),
              onTap: () => receipt(row),
            )),
        ],
      ),
    );
  }

  Future<void> receipt(Map<String, dynamic> row) async {
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

class PromoteScreen extends StatelessWidget {
  const PromoteScreen({super.key});

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
              for (final cls in classes)
                SoftCard(
                  child: ListTile(
                    title: Text(cls['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    trailing: FilledButton(onPressed: () => move(context, cls['id'].toString(), cls['name'].toString()), child: const Text('Promote')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> move(BuildContext context, String id, String name) async {
    final ok = await confirm(context, 'Promote $name?', 'Students who have not left move to the next grade.');
    if (!ok || !context.mounted) return;
    try {
      final data = await context.read<AppModel>().ask((api) => api.post('/api/v1/promote', {'class_id': id}));
      if (context.mounted) saved(context, 'Moved ${data['moved']} to ${data['to']}');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }
}

String _day() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
