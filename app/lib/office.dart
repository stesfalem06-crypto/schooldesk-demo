import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/dashboard'));
      data = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final finance = (data?['finance'] as Map?) ?? {};
    final head = (data?['head'] as Map?) ?? {};
    return SchoolScaffold(
      title: 'School',
      school: context.watch<AppModel>().school,
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh, size: 28))],
      body: data == null
          ? (error == null ? const Center(child: CircularProgressIndicator()) : ErrorNote(error!, load))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _stat('Students', '${head['students'] ?? 0}', 'Boys ${head['male'] ?? 0}  Girls ${head['female'] ?? 0}'),
                _stat('Fees paid', '${finance['fees_collected'] ?? 0}', 'Still to pay ${finance['fees_remaining'] ?? 0}', color: passGreen),
                _stat('Balance', '${finance['balance'] ?? 0}', 'Income ${finance['total_income'] ?? 0}  Spent ${finance['total_expense'] ?? 0}'),
              ],
            ),
    );
  }

  Widget _stat(String title, String value, String sub, {Color color = leaf}) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(sub),
        trailing: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});
  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  Map<String, dynamic>? finance;
  String kind = 'incomes';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/finance'));
    finance = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    if (context.mounted) setState(() {});
  }

  Future<void> add() async {
    final model = context.read<AppModel>();
    if (!model.isAdmin) return;
    final amount = await askNumber(context, 'Amount');
    if (amount == null || !context.mounted) return;
    final reason = TextEditingController();
    final extra = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What was it for?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Short reason')),
          if (kind == 'expenses') TextField(controller: extra, decoration: const InputDecoration(labelText: 'Receipt number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (kind == 'incomes') {
        await model.ask((api) => api.post('/api/v1/incomes', {'amount': amount, 'source': reason.text, 'received_on': _today(), 'note': ''}));
      } else if (kind == 'expenses') {
        await model.ask((api) => api.post('/api/v1/expenses', {'amount': amount, 'reason': reason.text, 'spent_on': _today(), 'receipt_number': extra.text, 'cheque_number': ''}));
      } else if (kind == 'workshops') {
        await model.ask((api) => api.post('/api/v1/workshops', {'amount': amount, 'description': reason.text, 'attended_on': _today(), 'days': 1}));
      } else {
        await model.ask((api) => api.post('/api/v1/sports', {'amount': amount, 'reason': reason.text, 'spent_on': _today()}));
      }
      await load();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = finance ?? {};
    final admin = context.watch<AppModel>().isAdmin;
    return SchoolScaffold(
      title: 'Money',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('In ${f['total_income'] ?? '…'}    Out ${f['total_expense'] ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Balance ${f['balance'] ?? '…'}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ((f['balance'] as num?) ?? 0) >= 0 ? passGreen : failRed)),
          Text('Fees ${f['fees_collected'] ?? 0} paid, ${f['fees_remaining'] ?? 0} left. Workshops ${f['workshops'] ?? 0}. Sports ${f['sports'] ?? 0}. Utility ${f['utility_fee'] ?? 0}.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final item in [('incomes', 'In'), ('expenses', 'Out'), ('workshops', 'Workshops'), ('sports', 'Sports')])
              ChoiceChip(label: Text(item.$2), selected: kind == item.$1, onSelected: (_) => setState(() => kind = item.$1)),
          ]),
          if (admin) Padding(padding: const EdgeInsets.only(top: 8), child: FilledButton(onPressed: add, child: const Text('Add'))),
        ],
      ),
    );
  }
}

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? stats;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final model = context.read<AppModel>();
    people = asMaps(await model.ask((api) => api.get('/api/v1/staff')));
    final raw = await model.ask((api) => api.get('/api/v1/staff/stats'));
    stats = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = stats ?? {};
    return SchoolScaffold(
      title: 'Staff',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Teaching  boys ${s['teaching_male'] ?? 0}  girls ${s['teaching_female'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Other staff  boys ${s['non_teaching_male'] ?? 0}  girls ${s['non_teaching_female'] ?? 0}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          for (final p in people)
            Card(child: ListTile(
              leading: Icon(p['staff_type'] == 'teaching' ? Icons.school : Icons.badge, color: leaf, size: 32),
              title: Text(p['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text('${p['sex'] == 'M' ? 'Male' : 'Female'} · ${p['staff_type']} · ${p['qualification']}'),
            )),
        ],
      ),
    );
  }
}

class AbsenceScreen extends StatefulWidget {
  const AbsenceScreen({super.key});
  @override
  State<AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends State<AbsenceScreen> {
  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? report;
  String? staffId;

  @override
  void initState() { super.initState(); loadPeople(); }

  Future<void> loadPeople() async {
    people = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/staff')));
    people = people.where((p) => p['staff_type'] == 'teaching').toList();
    if (people.isNotEmpty) {
      staffId = people.first['id'].toString();
      await loadReport();
    }
    if (context.mounted) setState(() {});
  }

  Future<void> loadReport() async {
    if (staffId == null) return;
    final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/staff/$staffId/absence'));
    report = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = report ?? {};
    final admin = context.watch<AppModel>().isAdmin;
    return SchoolScaffold(
      title: 'Absence',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButton<String>(
            isExpanded: true,
            value: staffId,
            items: [for (final p in people) DropdownMenuItem(value: p['id'].toString(), child: Text(p['full_name'].toString(), style: const TextStyle(fontSize: 18)))],
            onChanged: (v) async { staffId = v; await loadReport(); },
          ),
          const SizedBox(height: 8),
          Text('Days away ${r['absent_days'] ?? '—'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Per week ${r['absenteeism_per_week'] ?? '—'}'),
          Text('Periods lost ${r['lost_periods'] ?? '—'}   per week ${r['lost_per_week'] ?? '—'}'),
          Text('Make-up classes ${r['makeup_classes'] ?? '—'}'),
          Text('${r['percent_lost'] ?? '—'}% of periods lost', style: const TextStyle(fontSize: 20, color: failRed, fontWeight: FontWeight.w800)),
          if (admin) ...[
            const SizedBox(height: 8),
            FilledButton(onPressed: () => mark(false), child: const Text('Mark away today')),
            FilledButton(onPressed: () => mark(true), child: const Text('Add a make-up class')),
          ],
        ],
      ),
    );
  }

  Future<void> mark(bool makeup) async {
    if (staffId == null) return;
    final model = context.read<AppModel>();
    try {
      if (makeup) {
        final n = await askNumber(context, 'How many periods?');
        if (n == null) return;
        await model.ask((api) => api.post('/api/v1/makeups', {'staff_id': staffId, 'date': _today(), 'periods': n.round(), 'note': ''}));
      } else {
        await model.ask((api) => api.post('/api/v1/absences', {'staff_id': staffId, 'date': _today(), 'note': ''}));
      }
      await loadReport();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> form = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/settings'));
    form = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    if (context.mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    try {
      await context.read<AppModel>().ask((api) => api.put('/api/v1/settings', form));
      if (context.mounted) toast(context, 'Saved');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return SchoolScaffold(title: 'Settings', school: context.watch<AppModel>().school, body: const Center(child: CircularProgressIndicator()));
    final weights = (form['weights'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    final limits = (form['fail_limits'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    return SchoolScaffold(
      title: 'Settings',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _num('Yearly fee', form['yearly_fee'], (v) => form['yearly_fee'] = v),
          _num('Utility fee', form['utility_fee'], (v) => form['utility_fee'] = v),
          Text('Failed subjects that fail a student', style: const TextStyle(fontWeight: FontWeight.w800)),
          _num('Elementary', limits['elementary'], (v) => _limit(limits, 'elementary', v)),
          _num('Junior', limits['junior'], (v) => _limit(limits, 'junior', v)),
          _num('High school', limits['high'], (v) => _limit(limits, 'high', v)),
          SwitchListTile(title: const Text('School sets the 60% parts'), value: form['ca_locked'] == true, onChanged: (v) => setState(() => form['ca_locked'] = v)),
          for (final key in ['classwork', 'quizzes', 'tests', 'assignments', 'participation', 'homework'])
            _num(key, weights[key], (v) { weights[key] = v; form['weights'] = weights; }),
          TextFormField(
            initialValue: form['backup_dir']?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'Backup folder on the school computer'),
            onChanged: (v) => form['backup_dir'] = v,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: save, child: const Text('Save')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final ok = await confirm(context, 'Remove the sample?', 'Students, marks and money from the sample will be removed. The admin login stays.', danger: true);
              if (!ok || !context.mounted) return;
              await context.read<AppModel>().ask((api) => api.post('/api/v1/sample/clear', {}));
              if (context.mounted) toast(context, 'Sample removed');
            },
            child: const Text('Remove sample data'),
          ),
        ],
      ),
    );
  }

  void _limit(Map<String, dynamic> limits, String key, double v) {
    limits[key] = v.round();
    form['fail_limits'] = limits;
  }

  Widget _num(String label, dynamic value, void Function(double) onChanged) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 18)),
      trailing: Text('${value ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      onTap: () async {
        final n = await askNumber(context, label, initial: '${value ?? ''}');
        if (n == null) return;
        setState(() => onChanged(n));
      },
    );
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> files = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    files = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/backups')));
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Backup',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(onPressed: () async {
            await context.read<AppModel>().ask((api) => api.post('/api/v1/backup', {}));
            await load();
            if (context.mounted) toast(context, 'Backup saved on the school computer');
          }, icon: const Icon(Icons.save), label: const Text('Backup now')),
          const SizedBox(height: 8),
          if (files.isEmpty) const Text('No backups yet.', style: TextStyle(fontSize: 18)),
          for (final f in files.reversed)
            Card(child: ListTile(
              title: Text(f['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Tap to put these records back'),
              onTap: () async {
                final ok = await confirm(context, 'Put this backup back?', 'The current school records will be replaced.', danger: true);
                if (!ok || !context.mounted) return;
                await context.read<AppModel>().ask((api) => api.post('/api/v1/backups/restore', {'name': f['name']}));
                if (context.mounted) toast(context, 'Restored');
              },
            )),
        ],
      ),
    );
  }
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<Map<String, dynamic>> slots = [];
  int days = 5;
  int periods = 6;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/timetable'));
      final data = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      final bell = (data['bell'] as Map?) ?? {};
      days = (bell['days'] as num?)?.toInt() ?? 5;
      periods = (bell['periods_per_day'] as num?)?.toInt() ?? 6;
      slots = asMaps(data['slots']);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppModel>().isAdmin;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SchoolScaffold(
      title: 'Timetable',
      school: context.watch<AppModel>().school,
      body: error != null
          ? ErrorNote(error!, load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (admin)
                  FilledButton(onPressed: () async {
                    try {
                      await context.read<AppModel>().ask((api) => api.post('/api/v1/timetable/generate', {}));
                      await load();
                    } on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  }, child: const Text('Make the timetable')),
                const SizedBox(height: 8),
                if (slots.isEmpty) const EmptyNote('No timetable yet.'),
                for (var d = 0; d < days; d++) ...[
                  Text(names[d], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: leaf)),
                  for (final s in slots.where((s) => s['day'] == d))
                    _slotTile(s),
                ],
              ],
            ),
    );
  }

  Widget _slotTile(Map<String, dynamic> s) {
    final tile = ListTile(
      title: Text('${s['class_name']} · ${s['subject_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('Period ${((s['period'] as num?)?.toInt() ?? 0) + 1} · ${s['teacher_name'] ?? ''}'),
    );
    if (!context.read<AppModel>().isAdmin) return Card(child: tile);
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) async {
        final from = details.data;
        try {
          await context.read<AppModel>().ask((api) => api.post('/api/v1/timetable/move', {
                'class_id': from['class_id'],
                'from_day': from['day'],
                'from_period': from['period'],
                'to_day': s['day'],
                'to_period': s['period'],
              }));
          await load();
        } on ApiException catch (e) {
          if (context.mounted) toast(context, e.message);
        }
      },
      builder: (context, candidate, rejected) => Card(
        color: candidate.isEmpty ? card : const Color(0xFFFFE8E8),
        child: Draggable<Map<String, dynamic>>(
          data: s,
          feedback: Material(child: Text(s['subject_name'].toString(), style: const TextStyle(fontSize: 18))),
          child: tile,
        ),
      ),
    );
  }
}

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  List<Map<String, dynamic>> items = [];
  final title = TextEditingController();
  final people = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    items = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/meetings')));
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Meetings',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: people, decoration: const InputDecoration(labelText: 'Who came')),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () async {
            await context.read<AppModel>().ask((api) => api.post('/api/v1/meetings', {'meeting_date': _today(), 'title': title.text, 'attendees': people.text, 'notes': notes.text}));
            title.clear(); people.clear(); notes.clear();
            await load();
          }, child: const Text('Save meeting')),
          for (final m in items)
            Card(child: ListTile(title: Text(m['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${m['meeting_date']} · ${m['attendees']}'))),
        ],
      ),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final chosen = {'overview', 'results', 'fees', 'finance', 'staff', 'absence', 'meetings'};
  String? message;

  @override
  Widget build(BuildContext context) {
    const labels = {'overview': 'School', 'results': 'Results', 'fees': 'Fees', 'finance': 'Money', 'staff': 'Staff', 'absence': 'Absence', 'meetings': 'Meetings'};
    return SchoolScaffold(
      title: 'Report',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose what to include', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final e in labels.entries)
            CheckboxListTile(
              value: chosen.contains(e.key),
              title: Text(e.value, style: const TextStyle(fontSize: 18)),
              onChanged: (v) => setState(() {
                if (v == true) {
                  chosen.add(e.key);
                } else {
                  chosen.remove(e.key);
                }
              }),
            ),
          FilledButton(onPressed: () => save('pdf'), child: const Text('Save PDF')),
          FilledButton(onPressed: () => save('docx'), child: const Text('Save Word')),
          FilledButton(onPressed: () => save('pptx'), child: const Text('Save PowerPoint')),
          if (message != null) Text(message!, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> save(String format) async {
    setState(() => message = 'Making the ${format.toUpperCase()}…');
    try {
      final file = await context.read<AppModel>().api!.postBytes('/api/v1/reports/export', {'format': format, 'sections': chosen.toList()});
      setState(() => message = 'Report ready (${file.length} bytes). On the school computer it downloads as school-report.$format');
    } on ApiException catch (e) {
      setState(() => message = e.message);
    }
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> users = [];
  final name = TextEditingController();
  final pass = TextEditingController();
  String role = 'teacher';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    users = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/users')));
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Logins',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name to sign in')),
          TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password')),
          DropdownButton<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'director', child: Text('Director')),
            ],
            onChanged: (v) => setState(() => role = v ?? 'teacher'),
          ),
          FilledButton(onPressed: () async {
            try {
              await context.read<AppModel>().ask((api) => api.post('/api/v1/users', {'username': name.text, 'password': pass.text, 'role': role, 'display_name': name.text, 'staff_id': ''}));
              name.clear(); pass.clear();
              await load();
            } on ApiException catch (e) {
              if (context.mounted) toast(context, e.message);
            }
          }, child: const Text('Add login')),
          for (final u in users) ListTile(title: Text(u['display_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), subtitle: Text('${u['username']} · ${u['role']}')),
        ],
      ),
    );
  }
}

String _today() {
  final n = DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}-$m-$d';
}
