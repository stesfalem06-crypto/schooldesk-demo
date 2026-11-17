import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'edition.dart';
import 'saved_files.dart';
import 'school_book.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

int _classOrder(String name) {
  final match = RegExp(r'(\d+)\s*([A-Za-z])?').firstMatch(name);
  if (match == null) return 100000;
  final number = int.parse(match.group(1)!);
  final letter = match.group(2)?.toUpperCase() ?? '';
  return number * 100 + (letter.isEmpty ? 0 : letter.codeUnitAt(0));
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<Map<String, dynamic>> slots = [];
  List<Map<String, dynamic>> lessons = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> staff = [];
  int days = 5;
  int periods = 6;
  int step = 1;
  bool stepChosen = false;
  bool byTeacher = false;
  String? focusId;
  bool loading = true;
  String? error;
  String? note;
  final className = TextEditingController();
  final subjectName = TextEditingController();
  final teacherName = TextEditingController();
  int grade = 3;
  int lessonPeriods = 4;
  String? teacherId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final model = context.read<AppModel>();
      final raw = await model.ask((api) => api.get('/api/v1/timetable'));
      final data = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      final bell = (data['bell'] as Map?) ?? {};
      days = (bell['days'] as num?)?.toInt() ?? 5;
      periods = (bell['periods_per_day'] as num?)?.toInt() ?? 6;
      if (days < 1) days = 5;
      if (periods < 1) periods = 6;
      slots = asMaps(data['slots']);
      if (!stepChosen && slots.isNotEmpty) step = 3;
      stepChosen = true;
      if (model.isAdmin) {
        lessons = asMaps(await model.ask((api) => api.get('/api/v1/class-subjects')));
        classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
        staff = asMaps(await model.ask((api) => api.get('/api/v1/staff'))).where((p) => p['staff_type'] == 'teaching').toList();
        if (teacherId == null && staff.isNotEmpty) teacherId = staff.first['id'].toString();
      }
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  List<Map<String, dynamic>> get shown {
    final model = context.read<AppModel>();
    if (!model.seesSchool && !model.isAdmin) {
      final mine = model.user['staff_id']?.toString() ?? '';
      return slots.where((s) => s['teacher_staff_id']?.toString() == mine || _teachesClass(s['class_id']?.toString())).toList();
    }
    if (focusId == null) return slots;
    if (byTeacher) return slots.where((s) => s['teacher_staff_id']?.toString() == focusId).toList();
    return slots.where((s) => s['class_id']?.toString() == focusId).toList();
  }

  bool _teachesClass(String? id) {
    if (id == null) return false;
    final homes = context.read<AppModel>().homerooms;
    if (homes.contains(id)) return true;
    final staffId = context.read<AppModel>().user['staff_id']?.toString();
    return lessons.any((l) => l['class_id']?.toString() == id && l['teacher_staff_id']?.toString() == staffId);
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppModel>().isAdmin;
    return SchoolScaffold(
      title: 'Week',
      school: context.watch<AppModel>().school,
      actions: admin
          ? [
              FilledButton(onPressed: loading ? null : generate, child: const Text('Make the week')),
              const SizedBox(width: 8),
            ]
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (note != null) Text(note!, style: const TextStyle(fontSize: 16)),
                    if (admin) ..._wizard(),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _choice('By class', !byTeacher, () => setState(() { byTeacher = false; focusId = null; }))),
                      const SizedBox(width: 8),
                      Expanded(child: _choice('By teacher', byTeacher, () => setState(() { byTeacher = true; focusId = null; }))),
                    ]),
                    const SizedBox(height: 8),
                    _focusRow(),
                    const SizedBox(height: 8),
                    if (shown.isEmpty && slots.isEmpty) const EmptyNote('No week yet. Follow the steps above, then tap Make the week.'),
                    _grid(admin && !byTeacher),
                    if (slots.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: printWeek, icon: const Icon(Icons.print), label: const Text('Print')),
                    ],
                  ],
                ),
    );
  }

  List<Widget> _wizard() {
    return [
      Text('Step $step of 3', style: const TextStyle(fontSize: 16, color: leaf, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (step == 1) ...[
        const Text('How many school days?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _choice('5 days', days == 5, () => setState(() => days = 5))),
          const SizedBox(width: 8),
          Expanded(child: _choice('6 days', days == 6, () => setState(() => days = 6))),
        ]),
        const SizedBox(height: 12),
        const Text('How many periods in a day?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final n in [4, 5, 6, 7])
            ChoiceChip(label: Text('$n', style: const TextStyle(fontSize: 20)), selected: periods == n, onSelected: (_) => setState(() => periods = n)),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: saveWeek, child: const Text('Next')),
      ],
      if (step == 2) ...[
        const Text('Add one lesson', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: className, decoration: const InputDecoration(labelText: 'Class name, like Grade 3A')),
        const SizedBox(height: 8),
        const Text('Grade', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(spacing: 6, children: [
          for (var g = 1; g <= 12; g++)
            ChoiceChip(label: Text('$g'), selected: grade == g, onSelected: (_) => setState(() => grade = g)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: subjectName, decoration: const InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 8),
        if (staff.isEmpty)
          TextField(controller: teacherName, decoration: const InputDecoration(labelText: 'Teacher name'))
        else
          DropdownButton<String>(
            isExpanded: true,
            value: teacherId,
            items: [for (final p in staff) DropdownMenuItem(value: p['id'].toString(), child: Text(p['full_name'].toString(), style: const TextStyle(fontSize: 18)))],
            onChanged: (v) => setState(() => teacherId = v),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final n in [1, 2, 3, 4, 5, 6])
            ChoiceChip(label: Text('$n a week'), selected: lessonPeriods == n, onSelected: (_) => setState(() => lessonPeriods = n)),
        ]),
        const SizedBox(height: 8),
        FilledButton(onPressed: addLesson, child: const Text('Add this lesson')),
        const SizedBox(height: 8),
        Text('${lessons.length} lessons ready', style: const TextStyle(fontSize: 16)),
        FilledButton(onPressed: lessons.isEmpty ? null : () => setState(() => step = 3), child: const Text('Next')),
      ],
      if (step == 3) ...[
        const Text('Make the week', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Each class gets one lesson at a time. A teacher is never in two classes at once.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        FilledButton(onPressed: generate, child: const Text('Make the week')),
        TextButton(onPressed: () => setState(() { stepChosen = true; step = 1; }), child: const Text('Start again')),
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _choice(String label, bool on, VoidCallback tap) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: on ? leaf : const Color(0xFFD9E8E4), foregroundColor: on ? Colors.white : ink),
      onPressed: tap,
      child: Text(label),
    );
  }

  Widget _focusRow() {
    final items = <Map<String, dynamic>>[];
    if (byTeacher) {
      final seen = <String>{};
      for (final s in slots) {
        final id = s['teacher_staff_id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        items.add({'id': id, 'name': s['teacher_name']});
      }
    } else {
      final seen = <String>{};
      for (final s in slots) {
        final id = s['class_id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        items.add({'id': id, 'name': s['class_name']});
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    items.sort((a, b) => _classOrder(a['name'].toString()).compareTo(_classOrder(b['name'].toString())));
    return Wrap(spacing: 8, children: [
      for (final item in items)
        ChoiceChip(
          label: Text(item['name'].toString(), style: const TextStyle(fontSize: 16)),
          selected: focusId == item['id'],
          onSelected: (_) => setState(() => focusId = item['id'].toString()),
        ),
    ]);
  }

  Widget _grid(bool canDrag) {
    final rows = <Widget>[];
    rows.add(Row(children: [
      const SizedBox(width: 36),
      for (var d = 0; d < days; d++)
        Expanded(child: Text(_dayNames[d], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
    ]));
    for (var p = 0; p < periods; p++) {
      rows.add(const SizedBox(height: 6));
      rows.add(Row(children: [
        SizedBox(width: 36, child: Text('${p + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        for (var d = 0; d < days; d++) Expanded(child: _cell(d, p, canDrag)),
      ]));
    }
    return Column(children: rows);
  }

  Widget _cell(int day, int period, bool canDrag) {
    Map<String, dynamic>? slot;
    for (final s in shown) {
      if ((s['day'] as num?)?.toInt() == day && (s['period'] as num?)?.toInt() == period) {
        slot = s;
        break;
      }
    }
    final label = slot == null
        ? ''
        : (byTeacher ? '${slot['class_name']}\n${slot['subject_name']}' : '${slot['subject_name']}\n${slot['teacher_name']}');
    final box = Container(
      height: 64,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: slot == null ? const Color(0xFFF7F4EE) : card, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
      child: Text(label, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
    if (!canDrag || focusId == null) return box;
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => slot == null && details.data['class_id']?.toString() == focusId,
      onAcceptWithDetails: (details) => move(details.data, day, period),
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        final child = Container(
          height: 64,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: hot ? const Color(0xFFD9E8E4) : (slot == null ? const Color(0xFFF7F4EE) : card), borderRadius: BorderRadius.circular(10), border: Border.all(color: hot ? leaf : line)),
          child: Text(label, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        );
        if (slot == null) return child;
        return Draggable<Map<String, dynamic>>(
          data: slot,
          feedback: Material(child: Text(slot['subject_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          child: child,
        );
      },
    );
  }

  Future<void> saveWeek() async {
    try {
      await context.read<AppModel>().ask((api) => api.put('/api/v1/timetable/bell', {'days': days, 'periods_per_day': periods}));
      if (mounted) {
        saved(context, 'Week saved');
        setState(() => step = 2);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> addLesson() async {
    final model = context.read<AppModel>();
    try {
      var tid = teacherId;
      if (staff.isEmpty) {
        if (teacherName.text.trim().isEmpty) {
          toast(context, 'Type the teacher name');
          return;
        }
        final made = await model.ask((api) => api.post('/api/v1/staff', {
              'full_name': teacherName.text.trim(),
              'sex': 'F',
              'staff_type': 'teaching',
              'qualification': 'diploma',
            }));
        tid = (made as Map)['id'].toString();
      }
      if (className.text.trim().isEmpty || subjectName.text.trim().isEmpty || tid == null) {
        toast(context, 'Fill in the class, the subject, and the teacher');
        return;
      }
      final level = grade <= 6 ? 'elementary' : (grade <= 8 ? 'junior' : 'high');
      String? classId;
      for (final c in classes) {
        if (c['name'].toString().toLowerCase() == className.text.trim().toLowerCase()) classId = c['id'].toString();
      }
      if (classId == null) {
        final made = await model.ask((api) => api.post('/api/v1/classes', {
              'name': className.text.trim(),
              'level': level,
              'grade': grade,
              'academic_year': '2026-2027',
              'homeroom_staff_id': tid,
            }));
        classId = (made as Map)['id'].toString();
      }
      final subject = await model.ask((api) => api.post('/api/v1/subjects', {'name': subjectName.text.trim()}));
      await model.ask((api) => api.post('/api/v1/class-subjects', {
            'class_id': classId,
            'subject_id': (subject as Map)['id'],
            'teacher_staff_id': tid,
            'periods_per_week': lessonPeriods,
            'semester': 1,
          }));
      subjectName.clear();
      if (mounted) saved(context, 'Lesson added');
      await load();
      if (mounted) setState(() => step = 2);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> generate() async {
    try {
      if (demoEdition && Platform.environment['FLUTTER_TEST'] == 'true') {
        SchoolBook.instance.callNow('POST', '/api/v1/timetable/generate', {});
        if (mounted) {
          setState(() => note = 'The week is ready');
          saved(context, 'The week is ready');
        }
        return;
      }
      await context.read<AppModel>().ask((api) => api.post('/api/v1/timetable/generate', {}));
      await load();
      if (mounted) saved(context, 'The week is ready');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> move(Map<String, dynamic> from, int day, int period) async {
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/timetable/move', {
            'class_id': from['class_id'],
            'from_day': from['day'],
            'from_period': from['period'],
            'to_day': day,
            'to_period': period,
          }));
      await load();
      if (mounted) saved(context, 'Moved');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> printWeek() async {
    try {
      final query = focusId == null ? '' : (byTeacher ? '?teacher_id=$focusId' : '?class_id=$focusId');
      final bytes = await context.read<AppModel>().api!.bytes('/api/v1/timetable.pdf$query');
      final dir = await reportFolder();
      final file = File('${dir.path}/SchoolDesk-week.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) saved(context, 'Saved ${file.path}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, 'The printout could not be saved');
    }
  }
}
