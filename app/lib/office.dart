import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'saved_files.dart';
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
  List<Map<String, dynamic>> rows = [];
  String kind = 'incomes';
  String query = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final model = context.read<AppModel>();
    final raw = await model.ask((api) => api.get('/api/v1/finance'));
    finance = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    rows = asMaps(await model.ask((api) => api.get('/api/v1/$kind')));
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
      if (context.mounted) saved(context, 'Saved');
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
              ChoiceChip(label: Text(item.$2), selected: kind == item.$1, onSelected: (_) async { kind = item.$1; await load(); }),
          ]),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(labelText: 'Search'), onChanged: (v) => setState(() => query = v)),
          if (admin) Padding(padding: const EdgeInsets.only(top: 8), child: FilledButton(onPressed: add, child: const Text('Add'))),
          for (final row in rows.where((r) => query.isEmpty || '${r['source'] ?? ''} ${r['reason'] ?? ''} ${r['description'] ?? ''}'.toLowerCase().contains(query.toLowerCase())))
            Card(child: ListTile(
              title: Text('${row['amount']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              subtitle: Text('${row['source'] ?? row['reason'] ?? row['description'] ?? ''} · ${row['received_on'] ?? row['spent_on'] ?? row['attended_on'] ?? ''}', style: const TextStyle(fontSize: 16)),
            )),
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

  Future<void> addPerson() async {
    final name = TextEditingController();
    final number = TextEditingController();
    var sex = 'F';
    var kind = 'teaching';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New person'),
        content: StatefulBuilder(builder: (context, setLocal) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: number, decoration: const InputDecoration(labelText: 'Staff number')),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Woman'), selected: sex == 'F', onSelected: (_) => setLocal(() => sex = 'F')),
              ChoiceChip(label: const Text('Man'), selected: sex == 'M', onSelected: (_) => setLocal(() => sex = 'M')),
              ChoiceChip(label: const Text('Teacher'), selected: kind == 'teaching', onSelected: (_) => setLocal(() => kind = 'teaching')),
              ChoiceChip(label: const Text('Office'), selected: kind == 'non-teaching', onSelected: (_) => setLocal(() => kind = 'non-teaching')),
            ]),
          ]);
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      toast(context, 'Type the name');
      return;
    }
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/staff', {
            'full_name': name.text.trim(),
            'sex': sex,
            'staff_type': kind,
            'employee_id': number.text.trim(),
            'qualification': 'diploma',
          }));
      if (mounted) saved(context, 'Person added');
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
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
          if (context.watch<AppModel>().isAdmin) FilledButton(onPressed: addPerson, child: const Text('Add a person')),
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
  List<Map<String, dynamic>> marks = [];
  Map<String, dynamic>? report;
  String? staffId;
  String query = '';
  String filter = 'all';
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() { super.initState(); loadPeople(); }

  Future<void> loadPeople() async {
    people = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/staff')));
    if (staffId == null && people.isNotEmpty) staffId = people.first['id'].toString();
    await loadMonth();
  }

  Future<void> loadMonth() async {
    final model = context.read<AppModel>();
    marks = asMaps(await model.ask((api) => api.get('/api/v1/absences?year=${month.year}&month=${month.month}')));
    if (staffId != null) {
      final raw = await model.ask((api) => api.get('/api/v1/staff/$staffId/absence?year=${month.year}&month=${month.month}'));
      report = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    }
    if (context.mounted) setState(() {});
  }

  List<Map<String, dynamic>> get visible {
    final q = query.trim().toLowerCase();
    return people.where((p) {
      if (filter == 'teaching' && p['staff_type'] != 'teaching') return false;
      if (filter == 'office' && p['staff_type'] == 'teaching') return false;
      if (q.isEmpty) return true;
      final name = p['full_name'].toString().toLowerCase();
      final id = p['employee_id'].toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = report ?? {};
    final admin = context.watch<AppModel>().isAdmin;
    final selected = people.where((p) => p['id'].toString() == staffId).toList();
    return SchoolScaffold(
      title: 'Absence',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Search name or staff number'),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('All'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
            ChoiceChip(label: const Text('Teachers'), selected: filter == 'teaching', onSelected: (_) => setState(() => filter = 'teaching')),
            ChoiceChip(label: const Text('Office'), selected: filter == 'office', onSelected: (_) => setState(() => filter = 'office')),
          ]),
          const SizedBox(height: 8),
          for (final p in visible)
            Card(
              color: p['id'].toString() == staffId ? const Color(0xFFD9E8E4) : card,
              child: ListTile(
                title: Text(p['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                subtitle: Text('${p['employee_id'] ?? ''} · ${p['staff_type'] == 'teaching' ? 'Teacher' : 'Office'} · ${_count(p['id'].toString())} days away'),
                onTap: () async { staffId = p['id'].toString(); await loadMonth(); },
              ),
            ),
          if (visible.isEmpty) const EmptyNote('No one matches that search.'),
          const SizedBox(height: 12),
          Text(selected.isEmpty ? 'Choose a person' : selected.first['full_name'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Row(children: [
            IconButton(onPressed: () async { month = DateTime(month.year, month.month - 1); await loadMonth(); }, icon: const Icon(Icons.chevron_left, size: 36)),
            Expanded(child: Text(_monthLabel(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            IconButton(onPressed: () async { month = DateTime(month.year, month.month + 1); await loadMonth(); }, icon: const Icon(Icons.chevron_right, size: 36)),
          ]),
          _calendar(admin),
          const SizedBox(height: 8),
          Text('Days away ${r['absent_days'] ?? '—'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Periods lost ${r['lost_periods'] ?? '—'} · Make-up ${r['makeup_periods'] ?? '—'}', style: const TextStyle(fontSize: 16)),
          Text('${r['percent_lost'] ?? '—'}% of periods lost', style: const TextStyle(fontSize: 18, color: failRed, fontWeight: FontWeight.w800)),
          if (admin && staffId != null)
            FilledButton(onPressed: makeup, child: const Text('Add make-up periods')),
        ],
      ),
    );
  }

  int _count(String id) => marks.where((m) => m['staff_id'].toString() == id).length;

  String _monthLabel() {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${names[month.month - 1]} ${month.year}';
  }

  Widget _calendar(bool admin) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = <Widget>[];
    for (final name in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']) {
      cells.add(Center(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))));
    }
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= days; d++) {
      final date = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final away = marks.where((m) => m['staff_id'].toString() == staffId && m['date'].toString() == date).toList();
      cells.add(Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: away.isNotEmpty ? failRed : card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: !admin || staffId == null ? null : () => toggle(date, away),
            child: Center(child: Text('$d', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: away.isNotEmpty ? Colors.white : ink))),
          ),
        ),
      ));
    }
    return GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1, children: cells);
  }

  Future<void> toggle(String date, List<Map<String, dynamic>> away) async {
    final model = context.read<AppModel>();
    try {
      if (away.isNotEmpty) {
        final ok = await confirm(context, 'Mark as present?', date);
        if (!ok || !mounted) return;
        await model.ask((api) => api.delete('/api/v1/absences/${away.first['id']}'));
        if (mounted) saved(context, 'Marked present');
      } else {
        final ok = await confirm(context, 'Mark as away?', date);
        if (!ok || !mounted) return;
        await model.ask((api) => api.post('/api/v1/absences', {'staff_id': staffId, 'date': date, 'note': ''}));
        if (mounted) saved(context, 'Marked away');
      }
      await loadMonth();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> makeup() async {
    final n = await askNumber(context, 'How many periods were made up?');
    if (n == null || staffId == null) return;
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/makeups', {'staff_id': staffId, 'date': _today(), 'periods': n.round(), 'note': ''}));
      await loadMonth();
      if (mounted) saved(context, 'Make-up saved');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
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
      final dir = await reportFolder();
      final path = '${dir.path}/SchoolDesk-report.$format';
      await File(path).writeAsBytes(file);
      setState(() => message = 'Saved $path');
      if (mounted) saved(context, 'Report saved');
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

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  Map<String, dynamic> form = {};
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> staff = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    final raw = await model.ask((api) => api.get('/api/v1/settings'));
    form = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
    subjects = asMaps(await model.ask((api) => api.get('/api/v1/subjects')));
    staff = asMaps(await model.ask((api) => api.get('/api/v1/staff')));
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveLabels() async {
    try {
      await context.read<AppModel>().ask((api) => api.put('/api/v1/settings', form));
      if (mounted) saved(context, 'Names saved');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> rename(Map<String, dynamic> cls) async {
    final box = TextEditingController(text: cls['name']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Section name'),
        content: TextField(controller: box, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/classes', {
            'id': cls['id'],
            'name': box.text.trim(),
            'level': cls['level'],
            'grade': cls['grade'],
            'academic_year': cls['academic_year'],
            'homeroom_staff_id': cls['homeroom_staff_id'],
          }));
      if (mounted) saved(context, 'Section renamed');
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return SchoolScaffold(title: 'Set up school', hint: 'Do these once.', school: context.watch<AppModel>().school, body: const Center(child: CircularProgressIndicator()));
    final fee = (form['yearly_fee'] as num?) ?? 0;
    final steps = [
      (classes.isNotEmpty, 'Grades and sections'),
      (subjects.isNotEmpty, 'Subjects'),
      (staff.isNotEmpty, 'Teachers'),
      (fee > 0, 'Yearly fee'),
    ];
    return SchoolScaffold(
      title: 'Set up school',
      hint: 'Tick these off before the first real day.',
      school: context.watch<AppModel>().school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final step in steps)
            ListTile(
              leading: Icon(step.$1 ? Icons.check_circle : Icons.radio_button_unchecked, color: step.$1 ? passGreen : ink, size: 32),
              title: Text(step.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          const Text('Grade names', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('One line each, like 3=Year 3', style: TextStyle(fontSize: 16)),
          TextFormField(
            initialValue: form['grade_labels']?.toString() ?? '',
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Grade names'),
            onChanged: (v) => form['grade_labels'] = v,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: saveLabels, child: const Text('Save grade names')),
          const SizedBox(height: 12),
          const Text('Sections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          for (final cls in classes)
            Card(child: ListTile(
              title: Text(cls['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              subtitle: Text('Grade ${cls['grade']} · ${cls['homeroom_name'] ?? ''}'),
              trailing: const Icon(Icons.edit),
              onTap: () => rename(cls),
            )),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), child: const Text('Fees and mark parts')),
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
