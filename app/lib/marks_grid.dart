import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'roll_entry.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

class MarkGridScreen extends StatefulWidget {
  const MarkGridScreen({super.key, required this.subject});
  final Map<String, dynamic> subject;
  @override
  State<MarkGridScreen> createState() => _MarkGridScreenState();
}

class _MarkGridScreenState extends State<MarkGridScreen> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> columns = [];
  Map<String, Map<String, dynamic>> scores = {};
  bool loading = true;
  String? error;
  String? saving;

  bool get canEdit => widget.subject['can_edit'] == true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final model = context.read<AppModel>();
      students = asMaps(await model.ask((api) => api.get('/api/v1/students?class_id=${widget.subject['class_id']}')));
      columns = asMaps(await model.ask((api) => api.get('/api/v1/assessments?class_subject_id=${widget.subject['id']}')));
      scores = {};
      for (final col in columns) {
        final marks = asMaps(await model.ask((api) => api.get('/api/v1/scores?assessment_id=${col['id']}')));
        for (final mark in marks) {
          scores['${col['id']}|${mark['student_id']}'] = mark;
        }
      }
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save(Map<String, dynamic> student, Map<String, dynamic> column, String raw) async {
    if (!canEdit) return;
    final key = '${column['id']}|${student['id']}';
    final current = scores[key];
    final max = (column['max_marks'] as num?)?.toDouble() ?? 10;
    if (raw.trim().isEmpty) return;
    final value = double.tryParse(raw.trim());
    if (value == null || value < 0 || value > max) {
      toast(context, 'Enter a number from 0 to $max');
      return;
    }
    setState(() => saving = key);
    try {
      final saved = await context.read<AppModel>().ask((api) => api.post('/api/v1/scores', {
            'assessment_id': column['id'],
            'student_id': student['id'],
            'score': value,
            'base_revision': current?['revision'] ?? 0,
          }));
      if (saved is Map) scores[key] = saved.map((k, v) => MapEntry(k.toString(), v));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => saving = null);
  }

  @override
  Widget build(BuildContext context) {
    final active = students.where((s) => s['dropped_out'] != true).toList()
      ..sort((a, b) => ((a['roll_no'] as num?) ?? 0).compareTo((b['roll_no'] as num?) ?? 0));
    return SchoolScaffold(
      title: widget.subject['subject_name']?.toString() ?? 'Marks',
      hint: canEdit ? 'Type a mark and move to the next box. It saves itself.' : 'You can look. Only the subject teacher changes these marks.',
      actions: [
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RollMarkScreen(smokeClassName: widget.subject['class_name']?.toString()))), child: const Text('By roll number')),
      ],
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 64,
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 96,
                        columns: [
                          const DataColumn(label: Text('No.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          for (final col in columns)
                            DataColumn(label: Text(_colTitle(col), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        ],
                        rows: [
                          for (final student in active)
                            DataRow(cells: [
                              DataCell(Text('${student['roll_no'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              DataCell(Text(student['full_name'].toString(), style: const TextStyle(fontSize: 16))),
                              for (final col in columns) DataCell(_box(student, col)),
                              DataCell(Text(_total(student), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _failing(student) ? failRed : passGreen))),
                            ]),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  String _colTitle(Map<String, dynamic> col) {
    if (col['component'] == 'exam') return 'Exam';
    return '${col['component']}\nH${col['half']}';
  }

  Widget _box(Map<String, dynamic> student, Map<String, dynamic> column) {
    final key = '${column['id']}|${student['id']}';
    final score = scores[key]?['score']?.toString() ?? '';
    final max = (column['max_marks'] as num?)?.toDouble() ?? 10;
    final value = double.tryParse(score);
    final bad = value != null && (value < 0 || value > max);
    final controller = TextEditingController(text: score);
    return SizedBox(
      width: 72,
      child: Focus(
        onFocusChange: (has) {
          if (!has) save(student, column, controller.text);
        },
        child: TextFormField(
          key: ValueKey('$key-$score'),
          controller: controller,
          enabled: canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: bad ? failRed : ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: bad ? const Color(0xFFFFE8E8) : card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          onFieldSubmitted: (raw) => save(student, column, raw),
        ),
      ),
    );
  }

  String _total(Map<String, dynamic> student) {
    var sum = 0.0;
    var any = false;
    for (final col in columns) {
      final raw = scores['${col['id']}|${student['id']}']?['score'];
      final n = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (n == null) continue;
      any = true;
      sum += n;
    }
    if (!any) return '—';
    return sum.toStringAsFixed(sum == sum.roundToDouble() ? 0 : 1);
  }

  bool _failing(Map<String, dynamic> student) {
    final exam = columns.where((c) => c['component'] == 'exam').toList();
    if (exam.isEmpty) return false;
    final raw = scores['${exam.first['id']}|${student['id']}']?['score'];
    final n = raw is num ? raw.toDouble() : double.tryParse('$raw');
    return n != null && n < 20;
  }
}
