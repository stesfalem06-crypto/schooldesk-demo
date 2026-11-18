import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'shell.dart';
import 'widgets.dart';

class RollMarkScreen extends StatefulWidget {
  const RollMarkScreen({super.key, this.smokeClassName});
  final String? smokeClassName;

  @override
  State<RollMarkScreen> createState() => _RollMarkScreenState();
}

class _RollMarkScreenState extends State<RollMarkScreen> {
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> lessons = [];
  List<Map<String, dynamic>> assessments = [];
  List<Map<String, dynamic>> students = [];
  Map<String, String> scores = {};
  String? classId;
  String? lessonId;
  String? assessmentId;
  bool loading = true;
  String? note;
  final rollBox = TextEditingController();
  final scoreBox = TextEditingController();
  final scoreFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    rollBox.dispose();
    scoreBox.dispose();
    scoreFocus.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
    classes.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    lessons = asMaps(await model.ask((api) => api.get('/api/v1/class-subjects')));
    classId ??= _pickClass();
    final mine = lessons.where((l) => l['class_id'].toString() == classId).toList();
    if (lessonId == null || mine.every((l) => l['id'].toString() != lessonId)) {
      lessonId = mine.isEmpty ? null : mine.first['id'].toString();
    }
    await loadAssessments();
  }

  String? _pickClass() {
    final wanted = widget.smokeClassName;
    if (wanted != null) {
      final match = classes.where((c) => c['name'] == wanted).toList();
      if (match.isNotEmpty) return match.first['id'].toString();
    }
    final homes = context.read<AppModel>().homerooms;
    if (homes.isNotEmpty) return homes.first;
    return classes.isEmpty ? null : classes.first['id'].toString();
  }

  Future<void> loadAssessments() async {
    final model = context.read<AppModel>();
    if (lessonId == null) {
      assessments = [];
      students = [];
      if (mounted) setState(() => loading = false);
      return;
    }
    assessments = asMaps(await model.ask((api) => api.get('/api/v1/assessments?class_subject_id=$lessonId')));
    if (assessmentId == null || assessments.every((a) => a['id'].toString() != assessmentId)) {
      assessmentId = assessments.isEmpty ? null : assessments.first['id'].toString();
    }
    students = asMaps(await model.ask((api) => api.get('/api/v1/students?class_id=$classId')));
    students.sort((a, b) => ((a['roll_no'] as num?) ?? 0).compareTo((b['roll_no'] as num?) ?? 0));
    if (assessmentId != null) {
      final marks = asMaps(await model.ask((api) => api.get('/api/v1/scores?assessment_id=$assessmentId')));
      scores = {for (final mark in marks) mark['student_id'].toString(): '${mark['score']}'};
    }
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic>? get lesson => lessons.cast<Map<String, dynamic>?>().firstWhere((l) => l?['id'].toString() == lessonId, orElse: () => null);

  Future<void> saveScore(Map<String, dynamic> student, String raw) async {
    final value = double.tryParse(raw.trim());
    if (value == null || assessmentId == null) {
      toast(context, 'Type the roll number, then the score');
      return;
    }
    final body = {'assessment_id': assessmentId, 'student_id': student['id'], 'score': value};
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/scores', body));
      scores[student['id'].toString()] = raw.trim();
      if (mounted) setState(() => note = 'Saved ${student['roll_no']} ${student['full_name']}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> saveQuick() async {
    final roll = int.tryParse(rollBox.text.trim());
    final match = students.where((s) => (s['roll_no'] as num?)?.toInt() == roll && s['dropped_out'] != true).toList();
    if (roll == null || match.isEmpty) {
      setState(() => note = roll == null ? 'Type a roll number' : 'No student with number $roll');
      return;
    }
    await saveScore(match.first, scoreBox.text);
    rollBox.clear();
    scoreBox.clear();
    if (mounted) FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    final mine = lessons.where((l) => l['class_id'].toString() == classId).toList();
    final canEdit = lesson?['can_edit'] == true;
    return SchoolScaffold(
      title: 'Marks by number',
      hint: 'Type the roll number, press Tab, then the score',
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Text('Class', style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButton<String>(
                    value: classId,
                    items: [for (final cls in classes) DropdownMenuItem(value: cls['id'].toString(), child: Text(cls['name'].toString()))],
                    onChanged: (value) async {
                      classId = value;
                      lessonId = null;
                      assessmentId = null;
                      loading = true;
                      setState(() {});
                      await loadAssessments();
                    },
                  ),
                  const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButton<String>(
                    value: lessonId,
                    items: [for (final item in mine) DropdownMenuItem(value: item['id'].toString(), child: Text(item['subject_name'].toString()))],
                    onChanged: (value) async {
                      lessonId = value;
                      assessmentId = null;
                      await loadAssessments();
                    },
                  ),
                  const Text('Assessment', style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButton<String>(
                    value: assessmentId,
                    items: [for (final item in assessments) DropdownMenuItem(value: item['id'].toString(), child: Text(item['title'].toString()))],
                    onChanged: (value) async {
                      assessmentId = value;
                      await loadAssessments();
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(width: 140, child: TextField(controller: rollBox, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Roll number'), onSubmitted: (_) => scoreFocus.requestFocus())),
                  const SizedBox(width: 8),
                  SizedBox(width: 140, child: TextField(controller: scoreBox, focusNode: scoreFocus, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Score'), onSubmitted: (_) => saveQuick())),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: canEdit ? saveQuick : null, child: const Text('Save score')),
                ]),
                if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                const SizedBox(height: 8),
                const Text('Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                for (final student in students)
                  if (student['dropped_out'] != true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 48, child: Text('${student['roll_no']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(student['full_name'].toString(), style: const TextStyle(fontSize: 16))),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            key: ValueKey('score-${student['roll_no']}'),
                            initialValue: scores[student['id'].toString()] ?? '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true, labelText: 'Score'),
                            onFieldSubmitted: canEdit ? (value) => saveScore(student, value) : null,
                          ),
                        ),
                      ]),
                    ),
              ],
            ),
    );
  }
}
