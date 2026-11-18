import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'erp_shell.dart';
import 'money.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

int _classRank(String name) {
  final match = RegExp(r'(\d+)\s*([A-Za-z])?').firstMatch(name);
  if (match == null) return 100000;
  final number = int.parse(match.group(1)!);
  final letter = match.group(2)?.toUpperCase() ?? '';
  return number * 100 + (letter.isEmpty ? 0 : letter.codeUnitAt(0));
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  List<Map<String, dynamic>> classes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    classes = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/classes')));
    classes.sort((a, b) => _classRank(a['name'].toString()).compareTo(_classRank(b['name'].toString())));
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Classes',
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisExtent: 104, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: classes.length,
              itemBuilder: (context, i) {
                final cls = classes[i];
                return Card(
                  child: InkWell(
                    key: Key('class-${cls['name']}'),
                    onTap: () => DeskTrail.push(context, ClassDetailScreen(id: cls['id'].toString(), name: cls['name'].toString()), nav: 'Classes', crumbs: ['Classes', cls['name'].toString()]),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cls['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
                        Text(cls['homeroom_name']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A))),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.id, required this.name, this.focus = 'overview'});
  final String id;
  final String name;
  final String focus;
  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  Map<String, dynamic>? sheet;
  String? error;
  late String section = widget.focus == 'fees' ? 'Fees' : widget.focus == 'marks' ? 'Marks' : 'Teachers';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/classes/${widget.id}/sheet'));
      sheet = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = sheet;
    if (data == null) {
      return SchoolScaffold(title: widget.name, body: error == null ? const Center(child: CircularProgressIndicator()) : ErrorNote(error!, load));
    }
    final head = (data['head'] as Map?) ?? {};
    final teachers = asMaps(data['teachers']);
    final fees = asMaps(data['fees']);
    final rows = asMaps(data['rows']);
    final subjects = (data['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final topRanks = rows.where((row) => row['rank'] is int).take(4).map((row) => row['rank']).join(', ');
    return SchoolScaffold(
      title: widget.name,
      hint: 'Homeroom ${data['homeroom'] ?? ''}',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          Text('${head['active'] ?? 0} students · ${head['male'] ?? 0} boys · ${head['female'] ?? 0} girls · ${head['dropped'] ?? 0} left', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final label in ['Teachers', 'Fees', 'Marks'])
              ChoiceChip(label: Text(label), selected: section == label, onSelected: (_) => setState(() => section = label)),
          ]),
          const SizedBox(height: 12),
          if (section == 'Teachers') ...[
            const Text('Teachers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Homeroom teacher: ${data['homeroom'] ?? ''}', style: const TextStyle(fontSize: 16)),
            for (final lesson in teachers) Text('${lesson['subject']}: ${lesson['teacher']}', style: const TextStyle(fontSize: 16)),
          ],
          if (section == 'Fees') ...[
            const Text('Fees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final fee in fees)
              Card(
                child: ListTile(
                  title: Text(fee['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  subtitle: Text('Expected ${nfk(fee['expected'])} · Paid ${nfk(fee['paid'])} · Left ${nfk(fee['remaining'])}\n${fee['fully_paid']} students fully paid'),
                ),
              ),
          ],
          if (section == 'Marks') ...[
            const Text('Marks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Each mark is out of 100. CA is out of 60 and the final is out of 40.', style: const TextStyle(fontSize: 15, color: Color(0xFF5C6B7A))),
            Text('Ranks $topRanks', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            _marks(subjects, rows),
          ],
        ],
      ),
    );
  }

  Widget _marks(List<String> subjects, List<Map<String, dynamic>> rows) {
    const nameWidth = 170.0;
    const col = 148.0;
    Widget cell(String text, {bool head = false, bool left = false}) {
      return Container(
        width: left ? nameWidth : col,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: head ? FontWeight.w800 : FontWeight.w600, color: left && !head ? failRed : ink)),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            cell('Student', head: true, left: true),
            for (final subject in subjects) cell(subject, head: true),
            cell('Average', head: true),
            cell('Rank', head: true),
          ]),
          const Divider(height: 1),
          for (final row in rows)
            Row(children: [
              cell('${row['name']}${row['dropped'] == true ? ' (left)' : ''}', left: row['dropped'] == true),
              for (final subject in subjects) cell(_mark(row, subject)),
              cell(row['dropped'] == true ? '—' : '${row['average']}'),
              cell(row['dropped'] == true ? '—' : '${row['rank']}'),
            ]),
        ]),
      ),
    );
  }

  String _mark(Map<String, dynamic> row, String subject) {
    final marks = row['marks'];
    if (marks is! Map || marks[subject] is! Map) return '—';
    final mark = Map<String, dynamic>.from(marks[subject] as Map);
    final total = mark['total'];
    if (total == null) return '—';
    return '$total/100';
  }
}

class FeeTypesScreen extends StatefulWidget {
  const FeeTypesScreen({super.key});
  @override
  State<FeeTypesScreen> createState() => _FeeTypesScreenState();
}

class _FeeTypesScreenState extends State<FeeTypesScreen> {
  List<Map<String, dynamic>> types = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    types = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/fee-types')));
    if (mounted) setState(() {});
  }

  Future<void> edit([Map<String, dynamic>? current]) async {
    final name = TextEditingController(text: current?['name']?.toString() ?? '');
    final amount = TextEditingController(text: current == null ? '' : '${current['amount']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? 'New fee type' : 'Edit fee type'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount per year'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(amount.text.trim());
    if (name.text.trim().isEmpty || value == null) {
      toast(context, 'Type a name and an amount');
      return;
    }
    try {
      final body = {'name': name.text.trim(), 'amount': value};
      if (current == null) {
        await context.read<AppModel>().ask((api) => api.post('/api/v1/fee-types', body));
      } else {
        await context.read<AppModel>().ask((api) => api.put('/api/v1/fee-types/${current['id']}', body));
      }
      if (mounted) saved(context, 'Fee type saved');
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Fee types',
      actions: [IconButton(tooltip: 'Add', onPressed: () => edit(), icon: const Icon(Icons.add))],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Only the school admin sets these. They are the same for every student, for the year.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          for (final type in types)
            Card(
              child: ListTile(
                title: Text(type['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                subtitle: Text(nfk(type['amount'])),
                trailing: const Icon(Icons.edit),
                onTap: () => edit(type),
              ),
            ),
        ],
      ),
    );
  }
}
