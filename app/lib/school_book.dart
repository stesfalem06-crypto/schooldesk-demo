import 'dart:convert';
import 'dart:io';

import 'api.dart';
import 'school_rules.dart';

class SchoolBook {
  SchoolBook(this.directory);

  final String directory;
  Map<String, dynamic> state = {};
  Map<String, dynamic>? actor;

  static SchoolBook? _current;
  static SchoolBook get instance {
    final book = _current;
    if (book == null) throw StateError('The sample school is not open');
    return book;
  }

  static Future<SchoolBook> open({String? directory}) async {
    final dir = directory ?? await _defaultDir();
    final book = SchoolBook(dir);
    await book.load();
    _current = book;
    return book;
  }

  static Future<String> _defaultDir() async {
    final home = Platform.environment['HOME'] ?? '';
    final folder = Platform.isMacOS
        ? '$home/Library/Application Support/SchoolDesk Demo'
        : Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}\\SchoolDesk Demo'
            : '$home/.local/share/SchoolDesk Demo';
    await Directory(folder).create(recursive: true);
    return folder;
  }

  File get _file => File('$directory/school.json');

  Future<void> load() async {
    if (await _file.exists()) {
      try {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is Map && decoded['seed'] == 5) {
          state = Map<String, dynamic>.from(_norm(decoded) as Map);
          return;
        }
      } catch (_) {}
    }
    await reset();
  }

  Future<void> reset() async {
    state = _fresh();
    await _save();
  }

  Future<void> _save() async {
    await Directory(directory).create(recursive: true);
    await _file.writeAsString(jsonEncode(state));
  }

  String get schoolName => 'Hope Academy';

  void setActor(String key) {
    actor = _person(key);
  }

  Map<String, dynamic> _person(String key) {
    if (key == 'admin') {
      return {'role': 'admin', 'display_name': 'School admin', 'staff_id': '', 'homeroom_class_ids': <String>[], 'teaching_ids': <String>[]};
    }
    if (key == 'director') {
      return {'role': 'director', 'display_name': 'Director', 'staff_id': '', 'homeroom_class_ids': <String>[], 'teaching_ids': <String>[]};
    }
    if (key == 'homeroom') {
      final cls = _byName(_classes(), 'Grade 8A');
      final staffId = cls['homeroom_staff_id'].toString();
      return {
        'role': 'teacher',
        'display_name': 'Samuel',
        'staff_id': staffId,
        'homeroom_class_ids': [cls['id'].toString()],
        'teaching_ids': _teachingIds(staffId),
      };
    }
    final meron = _byName(_staff(), 'Meron Alemu');
    final staffId = meron['id'].toString();
    return {
      'role': 'teacher',
      'display_name': 'Meron',
      'staff_id': staffId,
      'homeroom_class_ids': <String>[],
      'teaching_ids': _teachingIds(staffId),
    };
  }

  Future<dynamic> call(String method, String path, Object? body) async {
    final uri = Uri.parse('http://local$path');
    final parts = uri.pathSegments;
    final tail = parts.length < 3 ? '' : parts.sublist(2).join('/');
    final query = uri.queryParameters;
    final data = body is Map ? body.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
    final result = _route(method, tail, query, data);
    if (method != 'GET') await _save();
    return result;
  }

  dynamic _route(String method, String tail, Map<String, String> query, Map<String, dynamic> body) {
    if (method == 'GET' && tail == 'dashboard') return _dashboard();
    if (method == 'GET' && tail == 'classes') return _visibleClasses();
    if (method == 'POST' && tail == 'classes') return _saveClass(body);
    if (method == 'GET' && tail == 'subjects') return _subjects();
    if (method == 'POST' && tail == 'subjects') return _addSubject(body);
    if (method == 'GET' && tail == 'class-subjects') return _visibleLessons();
    if (method == 'POST' && tail == 'class-subjects') return _addLesson(body);
    if (method == 'GET' && tail == 'students') return _students(query['class_id']);
    if (method == 'POST' && tail == 'students') return _addStudent(body);
    if (method == 'POST' && tail.startsWith('students/') && tail.endsWith('/dropout')) {
      return _dropout(tail.split('/')[1], body);
    }
    if (method == 'GET' && tail.startsWith('classes/') && tail.endsWith('/results')) {
      return _results(tail.split('/')[1]);
    }
    if (method == 'GET' && tail.startsWith('classes/') && tail.endsWith('/summary')) {
      return _summary(tail.split('/')[1]);
    }
    if (method == 'GET' && tail == 'assessments') return _assessments(query['class_subject_id']);
    if (method == 'POST' && tail == 'assessments') return _addAssessment(body);
    if (method == 'GET' && tail == 'scores') return _scores(query['assessment_id']);
    if (method == 'POST' && tail == 'scores') return _setScore(body);
    if (method == 'POST' && tail == 'scores/undo') return {'ok': true};
    if (method == 'GET' && tail == 'fees') return _fees(query['class_id']);
    if (method == 'GET' && tail == 'payments') return _rows('payments');
    if (method == 'POST' && tail == 'fees') return _pay(body);
    if (method == 'GET' && tail == 'summary/fees') return _feeSummary();
    if (method == 'GET' && tail == 'summary/results') return _resultSummary();
    if (method == 'GET' && tail == 'finance') return _finance();
    if (method == 'GET' && (tail == 'incomes' || tail == 'expenses' || tail == 'workshops' || tail == 'sports')) return _rows(tail);
    if (method == 'POST' && (tail == 'incomes' || tail == 'expenses' || tail == 'workshops' || tail == 'sports')) return _addMoney(tail, body);
    if (method == 'GET' && tail == 'staff') return _staff();
    if (method == 'POST' && tail == 'staff') return _addStaff(body);
    if (method == 'GET' && tail == 'staff/stats') return _staffStats();
    if (method == 'GET' && tail == 'absences') return _absences(query['year'], query['month']);
    if (method == 'POST' && tail == 'absences') return _addAbsence(body);
    if (method == 'DELETE' && tail.startsWith('absences/')) return _deleteAbsence(tail.split('/')[1]);
    if (method == 'GET' && tail.startsWith('staff/') && tail.endsWith('/absence')) {
      return _absenceReport(tail.split('/')[1], query['year'], query['month']);
    }
    if (method == 'POST' && tail == 'makeups') return _addMakeup(body);
    if (method == 'GET' && tail == 'settings') return state['settings'];
    if (method == 'PUT' && tail == 'settings') return _saveSettings(body);
    if (method == 'POST' && tail == 'sample/clear') {
      state = _fresh();
      return {'ok': true};
    }
    if (method == 'GET' && tail == 'backups') return _backupList();
    if (method == 'POST' && tail == 'backup') return _backup();
    if (method == 'POST' && tail == 'backups/restore') return _restore(body);
    if (method == 'GET' && tail == 'meetings') return _rows('meetings');
    if (method == 'POST' && tail == 'meetings') return _addMeeting(body);
    if (method == 'GET' && tail == 'users') return _rows('users');
    if (method == 'POST' && tail == 'users') return _addUser(body);
    if (method == 'GET' && tail == 'timetable') return {'bell': state['bell'], 'slots': state['slots']};
    if (method == 'PUT' && tail == 'timetable/bell') return _saveBell(body);
    if (method == 'POST' && tail == 'timetable/generate') return _generate();
    if (method == 'POST' && tail == 'timetable/move') return _move(body);
    if (method == 'GET' && tail == 'timetable.pdf') return _timetablePdf();
    if (method == 'POST' && tail == 'reports/export') return _export(body);
    if (method == 'POST' && tail == 'semester/close') return _closeSemester();
    if (method == 'GET' && tail == 'reports/semester') return _rows('reports');
    if (method == 'GET' && tail.startsWith('reports/semester/')) return _reportBytes(tail.split('/').last);
    if (method == 'GET' && tail == 'search') return _search(query['q'] ?? '');
    if (method == 'GET' && tail == 'notices') return _rows('notices');
    if (method == 'POST' && tail == 'notices') return _addNotice(body);
    if (method == 'GET' && tail == 'calendar') return _rows('calendar');
    if (method == 'POST' && tail == 'calendar') return _addCalendar(body);
    if (method == 'GET' && tail == 'charts') return _charts();
    if (method == 'GET' && tail == 'matrix') return _matrix();
    if (method == 'GET' && tail == 'fees/defaulters') return _defaulters();
    if (method == 'GET' && tail.startsWith('fees/receipt/')) return _receipt(tail.split('/').last);
    if (method == 'GET' && tail.startsWith('students/') && tail.endsWith('/report.pdf')) return _reportCard(tail.split('/')[1]);
    if (method == 'GET' && tail.startsWith('students/') && tail.endsWith('/card.pdf')) return _idCard(tail.split('/')[1]);
    if (method == 'GET' && tail.startsWith('classes/') && tail.endsWith('/roster.pdf')) return _roster(tail.split('/')[1]);
    if (method == 'POST' && tail == 'promote') return _promote(body);
    if (method == 'GET' && tail == 'attendance') return _attendance(query['class_id'], query['date']);
    if (method == 'POST' && tail == 'attendance') return _markAttendance(body);
    if (method == 'PUT' && tail.startsWith('students/') && tail.endsWith('/profile')) return _saveProfile(tail.split('/')[1], body);
    throw ApiException('That did not work');
  }

  Map<String, dynamic> _require() {
    final who = actor;
    if (who == null) throw ApiException('Choose who you are first');
    return who;
  }

  bool _seesSchool() {
    final role = _require()['role'];
    return role == 'admin' || role == 'director';
  }

  bool _isAdmin() => _require()['role'] == 'admin';

  List<String> _homes() => ((_require()['homeroom_class_ids'] as List?) ?? []).map((e) => e.toString()).toList();

  String _id(String prefix) {
    final n = ((state['seq'] as num?)?.toInt() ?? 0) + 1;
    state['seq'] = n;
    return '$prefix$n';
  }

  List<Map<String, dynamic>> _rows(String key) => ((state[key] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  List<Map<String, dynamic>> _classes() => _rows('classes');
  List<Map<String, dynamic>> _staff() => _rows('staff');
  List<Map<String, dynamic>> _subjects() => _rows('subjects');
  List<Map<String, dynamic>> _lessons() => _rows('class_subjects');
  List<Map<String, dynamic>> _pupils() => _rows('students');

  Map<String, dynamic> _byId(List<Map<String, dynamic>> rows, String id) {
    for (final row in rows) {
      if (row['id'].toString() == id) return row;
    }
    throw ApiException('That record was not found');
  }

  Map<String, dynamic> _byName(List<Map<String, dynamic>> rows, String name) {
    for (final row in rows) {
      if (row['name']?.toString() == name || row['full_name']?.toString() == name) return row;
    }
    throw ApiException('$name was not found');
  }

  void _replace(String key, Map<String, dynamic> row) {
    final rows = _rows(key);
    final next = <Map<String, dynamic>>[];
    for (final item in rows) {
      next.add(item['id'].toString() == row['id'].toString() ? row : item);
    }
    state[key] = next;
  }

  List<String> _teachingIds(String staffId) => _lessons().where((l) => l['teacher_staff_id'].toString() == staffId).map((l) => l['id'].toString()).toList();

  List<Map<String, dynamic>> _visibleClasses() {
    final who = _require();
    final all = _classes();
    if (_seesSchool()) return all;
    final homes = _homes().toSet();
    final taught = _lessons().where((l) => l['teacher_staff_id'].toString() == who['staff_id']).map((l) => l['class_id'].toString()).toSet();
    return all.where((c) => homes.contains(c['id'].toString()) || taught.contains(c['id'].toString())).toList();
  }

  List<Map<String, dynamic>> _visibleLessons() {
    final who = _require();
    final homes = _homes().toSet();
    final staffId = who['staff_id']?.toString() ?? '';
    final all = _lessons();
    if (_seesSchool()) {
      return all.map((l) => {...l, 'can_edit': false}).toList();
    }
    return all.where((l) => l['teacher_staff_id'].toString() == staffId || homes.contains(l['class_id'].toString())).map((l) {
      return {...l, 'can_edit': l['teacher_staff_id'].toString() == staffId};
    }).toList();
  }

  bool _canTeach(String lessonId) {
    final lesson = _byId(_lessons(), lessonId);
    return lesson['teacher_staff_id'].toString() == _require()['staff_id'].toString();
  }

  List<Map<String, dynamic>> _students(String? classId) {
    _require();
    var rows = _pupils();
    if (classId != null && classId.isNotEmpty) {
      rows = rows.where((s) => s['class_id'].toString() == classId).toList();
    }
    if (!_seesSchool()) {
      final homes = _homes().toSet();
      final taught = _lessons().where((l) => l['teacher_staff_id'].toString() == _require()['staff_id']).map((l) => l['class_id'].toString()).toSet();
      rows = rows.where((s) => homes.contains(s['class_id'].toString()) || taught.contains(s['class_id'].toString())).toList();
    }
    return rows;
  }

  Map<String, dynamic> _addStudent(Map<String, dynamic> body) {
    final classId = body['class_id']?.toString() ?? '';
    if (!_homes().contains(classId) && !_isAdmin()) {
      throw ApiException('Only the homeroom teacher can change this list');
    }
    final row = {
      'id': _id('p'),
      'full_name': body['full_name']?.toString() ?? '',
      'sex': body['sex']?.toString() ?? 'F',
      'mother_name': body['mother_name']?.toString() ?? '',
      'class_id': classId,
      'dropped_out': false,
      'dropout_reason': '',
      'dropout_date': '',
    };
    if (row['full_name'] == '') throw ApiException('Type the student\'s name');
    state['students'] = [..._pupils(), row];
    return row;
  }

  Map<String, dynamic> _dropout(String id, Map<String, dynamic> body) {
    final student = _byId(_pupils(), id);
    if (!_homes().contains(student['class_id'].toString())) {
      throw ApiException('Only the homeroom teacher can do that');
    }
    final left = body['dropped'] == true;
    student['dropped_out'] = left;
    student['dropout_reason'] = left ? (body['reason']?.toString() ?? '') : '';
    student['dropout_date'] = left ? (body['date']?.toString() ?? '') : '';
    _replace('students', student);
    return student;
  }

  Map<String, dynamic> _saveClass(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can change classes');
    final id = body['id']?.toString() ?? '';
    final homeroom = body['homeroom_staff_id']?.toString() ?? '';
    if (homeroom.isEmpty) throw ApiException('Choose the teacher who looks after this class');
    for (final cls in _classes()) {
      if (cls['homeroom_staff_id'].toString() == homeroom && cls['id'].toString() != id) {
        final teacher = _byId(_staff(), homeroom)['full_name'];
        throw ApiException('$teacher already looks after ${cls['name']}. A teacher can look after only one class.');
      }
    }
    final named = _staff().where((s) => s['id'].toString() == homeroom);
    final name = named.isEmpty ? '' : named.first['full_name'].toString();
    if (id.isEmpty) {
      final row = {
        'id': _id('c'),
        'name': body['name']?.toString() ?? '',
        'level': body['level']?.toString() ?? 'elementary',
        'grade': (body['grade'] as num?)?.toInt() ?? 1,
        'academic_year': body['academic_year']?.toString() ?? state['settings']['academic_year'],
        'homeroom_staff_id': homeroom,
        'homeroom_name': name,
      };
      state['classes'] = [..._classes(), row];
      return row;
    }
    final row = _byId(_classes(), id);
    row['name'] = body['name']?.toString() ?? row['name'];
    row['level'] = body['level']?.toString() ?? row['level'];
    row['grade'] = (body['grade'] as num?)?.toInt() ?? row['grade'];
    row['academic_year'] = body['academic_year']?.toString() ?? row['academic_year'];
    row['homeroom_staff_id'] = homeroom;
    row['homeroom_name'] = name;
    _replace('classes', row);
    return row;
  }

  Map<String, dynamic> _addSubject(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can add a subject');
    final row = {'id': _id('sub'), 'name': body['name']?.toString() ?? '', 'code': ''};
    state['subjects'] = [..._subjects(), row];
    return row;
  }

  Map<String, dynamic> _addStaff(Map<String, dynamic> body) {
    if (!_isAdmin() && _require()['role'] != 'admin') {
      if (!_isAdmin()) throw ApiException('Only the school admin can add a person');
    }
    final row = {
      'id': _id('st'),
      'full_name': body['full_name']?.toString() ?? '',
      'sex': body['sex']?.toString() ?? 'F',
      'staff_type': body['staff_type']?.toString() ?? 'teaching',
      'employee_id': body['employee_id']?.toString() ?? '',
      'qualification': body['qualification']?.toString() ?? 'diploma',
      'phone': '',
      'village': '',
    };
    state['staff'] = [..._staff(), row];
    return row;
  }

  Map<String, dynamic> _addLesson(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can add a lesson');
    final cls = _byId(_classes(), body['class_id'].toString());
    final subject = _byId(_subjects(), body['subject_id'].toString());
    final teacher = _byId(_staff(), body['teacher_staff_id'].toString());
    final row = {
      'id': _id('ls'),
      'class_id': cls['id'],
      'class_name': cls['name'],
      'subject_id': subject['id'],
      'subject_name': subject['name'],
      'teacher_staff_id': teacher['id'],
      'teacher_name': teacher['full_name'],
      'periods_per_week': (body['periods_per_week'] as num?)?.toInt() ?? 2,
      'semester': 1,
      'weights': Map<String, dynamic>.from(defaultWeights),
    };
    state['class_subjects'] = [..._lessons(), row];
    _ensureColumns(row['id'].toString());
    return row;
  }

  List<Map<String, dynamic>> _assessments(String? lessonId) {
    _require();
    return _rows('assessments').where((a) => lessonId == null || a['class_subject_id'].toString() == lessonId).toList();
  }

  Map<String, dynamic> _addAssessment(Map<String, dynamic> body) {
    final lessonId = body['class_subject_id'].toString();
    if (!_canTeach(lessonId)) throw ApiException('You do not teach this subject');
    final row = {
      'id': _id('as'),
      'class_subject_id': lessonId,
      'component': body['component']?.toString() ?? 'classwork',
      'half': (body['half'] as num?)?.toInt() ?? 1,
      'title': body['title']?.toString() ?? 'Mark',
      'max_marks': (body['max_marks'] as num?)?.toDouble() ?? 10,
      'assessment_date': '',
      'revision': 1,
    };
    state['assessments'] = [..._rows('assessments'), row];
    return row;
  }

  List<Map<String, dynamic>> _scores(String? assessmentId) {
    _require();
    return _rows('scores').where((s) => assessmentId == null || s['assessment_id'].toString() == assessmentId).toList();
  }

  Map<String, dynamic> _setScore(Map<String, dynamic> body) {
    final assessment = _byId(_rows('assessments'), body['assessment_id'].toString());
    if (!_canTeach(assessment['class_subject_id'].toString())) throw ApiException('You do not teach this subject');
    final max = (assessment['max_marks'] as num).toDouble();
    final score = (body['score'] as num?)?.toDouble();
    if (score == null || score < 0 || score > max) throw ApiException('Enter a number from 0 to $max');
    final existing = _rows('scores').where((s) => s['assessment_id'] == assessment['id'] && s['student_id'] == body['student_id']).toList();
    final row = {
      'id': existing.isEmpty ? _id('sc') : existing.first['id'],
      'assessment_id': assessment['id'],
      'student_id': body['student_id'],
      'score': score,
      'revision': ((existing.isEmpty ? 0 : existing.first['revision'] as num?)?.toInt() ?? 0) + 1,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final next = _rows('scores').where((s) => s['id'] != row['id']).toList()..add(row);
    state['scores'] = next;
    return row;
  }

  double get _fee => ((state['settings'] as Map)['yearly_fee'] as num?)?.toDouble() ?? 0;

  double _paid(String studentId) {
    var sum = 0.0;
    for (final row in _rows('payments')) {
      if (row['student_id'].toString() == studentId) sum += (row['amount'] as num).toDouble();
    }
    return round2(sum);
  }

  List<Map<String, dynamic>> _fees(String? classId) {
    _require();
    final rows = <Map<String, dynamic>>[];
    for (final student in _students(classId)) {
      final paid = _paid(student['id'].toString());
      rows.add({
        'student_id': student['id'],
        'full_name': student['full_name'],
        'sex': student['sex'],
        'due': _fee,
        'paid': paid,
        'remaining': round2(_fee - paid),
      });
    }
    return rows;
  }

  Map<String, dynamic> _pay(Map<String, dynamic> body) {
    final student = _byId(_pupils(), body['student_id'].toString());
    if (!_homes().contains(student['class_id'].toString())) {
      throw ApiException('Only the homeroom teacher can record a payment');
    }
    final amount = (body['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) throw ApiException('Type the amount');
    final remaining = round2(_fee - _paid(student['id'].toString()));
    if (amount > remaining) throw ApiException('that is more than the fee still owed');
    final row = {
      'id': _id('pay'),
      'student_id': student['id'],
      'academic_year': (state['settings'] as Map)['academic_year'],
      'amount': amount,
      'paid_on': body['paid_on']?.toString() ?? '',
    };
    state['payments'] = [..._rows('payments'), row];
    return row;
  }

  Map<String, dynamic> _feeSummary() {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final grades = <int, Map<String, dynamic>>{};
    var students = 0;
    var collected = 0.0;
    var remaining = 0.0;
    for (final cls in _classes()) {
      final grade = (cls['grade'] as num).toInt();
      final bucket = grades.putIfAbsent(grade, () => {
            'grade': grade,
            'name': _gradeTitle(grade),
            'classes': 0,
            'students': 0,
            'collected': 0.0,
            'remaining': 0.0,
            'sections': <Map<String, dynamic>>[],
          });
      bucket['classes'] = (bucket['classes'] as int) + 1;
      final section = {'id': cls['id'], 'name': cls['name'], 'students': 0, 'collected': 0.0, 'remaining': 0.0};
      for (final student in _pupils().where((s) => s['class_id'] == cls['id'])) {
        final paid = _paid(student['id'].toString());
        final left = round2(_fee - paid);
        section['students'] = (section['students'] as int) + 1;
        section['collected'] = round2((section['collected'] as num).toDouble() + paid);
        section['remaining'] = round2((section['remaining'] as num).toDouble() + left);
        bucket['students'] = (bucket['students'] as int) + 1;
        bucket['collected'] = round2((bucket['collected'] as num).toDouble() + paid);
        bucket['remaining'] = round2((bucket['remaining'] as num).toDouble() + left);
        students++;
        collected = round2(collected + paid);
        remaining = round2(remaining + left);
      }
      (bucket['sections'] as List).add(section);
    }
    final ordered = grades.keys.toList()..sort();
    return {'grades': [for (final g in ordered) grades[g]], 'students': students, 'collected': collected, 'remaining': remaining};
  }

  String _gradeTitle(int grade) {
    final labels = (state['settings'] as Map)['grade_labels']?.toString() ?? '';
    for (final line in labels.split('\n')) {
      final bits = line.split('=');
      if (bits.length == 2 && bits[0].trim() == '$grade' && bits[1].trim().isNotEmpty) return bits[1].trim();
    }
    return 'Grade $grade';
  }

  Map<String, dynamic> _results(String classId) {
    _require();
    final cls = _byId(_classes(), classId);
    final limits = Map<String, dynamic>.from((state['settings'] as Map)['fail_limits'] as Map);
    final pupils = <Map<String, dynamic>>[];
    final detail = <String, List<Map<String, dynamic>>>{};
    for (final student in _pupils().where((s) => s['class_id'] == classId)) {
      final totals = <double>[];
      final subjects = <Map<String, dynamic>>[];
      for (final lesson in _lessons().where((l) => l['class_id'] == classId)) {
        final mark = _subjectMark(lesson, student['id'].toString());
        totals.add(mark.total);
        subjects.add({'class_subject': lesson, 'result': {'mid': mark.mid, 'continuous': mark.continuous, 'exam': mark.exam, 'total': mark.total, 'exam_set': mark.examSet, 'passed': mark.passed}});
      }
      pupils.add({'id': student['id'], 'totals': totals, 'dropout': student['dropped_out'] == true, 'level': cls['level']});
      detail[student['id'].toString()] = subjects;
    }
    final ranks = standings(pupils, limits);
    final students = <Map<String, dynamic>>[];
    for (final rank in ranks) {
      final student = _byId(_pupils(), rank.id);
      students.add({'student': student, 'subjects': detail[rank.id] ?? [], 'standing': rank.toJson()});
    }
    return {'class': cls, 'semester': (state['settings'] as Map)['semester'], 'students': students};
  }

  SubjectMark _subjectMark(Map<String, dynamic> lesson, String studentId) {
    final weights = Map<String, dynamic>.from((lesson['weights'] as Map?) ?? defaultWeights);
    final items = <Map<String, dynamic>>[];
    for (final assessment in _rows('assessments').where((a) => a['class_subject_id'] == lesson['id'])) {
      final scores = _rows('scores').where((s) => s['assessment_id'] == assessment['id'] && s['student_id'] == studentId).toList();
      items.add({
        'component': assessment['component'],
        'half': assessment['half'],
        'max': assessment['max_marks'],
        'score': scores.isEmpty ? null : scores.first['score'],
      });
    }
    return summarize(weights, items);
  }

  Map<String, dynamic> _resultSummary() {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final grades = <int, Map<String, dynamic>>{};
    var students = 0, promoted = 0, failed = 0, dropouts = 0;
    for (final cls in _classes()) {
      final grade = (cls['grade'] as num).toInt();
      final bucket = grades.putIfAbsent(grade, () => {
            'grade': grade,
            'name': _gradeTitle(grade),
            'students': 0,
            'promoted': 0,
            'failed': 0,
            'dropouts': 0,
            'sections': <Map<String, dynamic>>[],
          });
      final result = _results(cls['id'].toString());
      final section = {'id': cls['id'], 'name': cls['name'], 'students': 0, 'promoted': 0, 'failed': 0, 'dropouts': 0};
      for (final row in (result['students'] as List)) {
        final status = (row as Map)['standing']['status'];
        section['students'] = (section['students'] as int) + 1;
        bucket['students'] = (bucket['students'] as int) + 1;
        students++;
        if (status == 'promoted') {
          section['promoted'] = (section['promoted'] as int) + 1;
          bucket['promoted'] = (bucket['promoted'] as int) + 1;
          promoted++;
        } else if (status == 'failed') {
          section['failed'] = (section['failed'] as int) + 1;
          bucket['failed'] = (bucket['failed'] as int) + 1;
          failed++;
        } else if (status == 'dropout') {
          section['dropouts'] = (section['dropouts'] as int) + 1;
          bucket['dropouts'] = (bucket['dropouts'] as int) + 1;
          dropouts++;
        }
      }
      (bucket['sections'] as List).add(section);
    }
    final ordered = grades.keys.toList()..sort();
    return {'grades': [for (final g in ordered) grades[g]], 'students': students, 'promoted': promoted, 'failed': failed, 'dropouts': dropouts};
  }

  Map<String, dynamic> _summary(String classId) {
    final pupils = _pupils().where((s) => s['class_id'] == classId).toList();
    var male = 0, female = 0, dropped = 0;
    for (final student in pupils) {
      if (student['sex'] == 'M') male++;
      if (student['sex'] == 'F') female++;
      if (student['dropped_out'] == true) dropped++;
    }
    final fees = _fees(classId);
    return {
      'head': {'students': pupils.length, 'male': male, 'female': female, 'dropped': dropped},
      'fees': fees,
    };
  }

  Map<String, dynamic> _finance() {
    double sum(String key) {
      var total = 0.0;
      for (final row in _rows(key)) {
        total += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return round2(total);
    }

    var collected = 0.0;
    var remaining = 0.0;
    for (final student in _pupils()) {
      final paid = _paid(student['id'].toString());
      collected = round2(collected + paid);
      remaining = round2(remaining + (_fee - paid));
    }
    final income = sum('incomes');
    final expenses = sum('expenses');
    final workshops = sum('workshops');
    final sports = sum('sports');
    final utility = ((state['settings'] as Map)['utility_fee'] as num?)?.toDouble() ?? 0;
    final totalIncome = round2(collected + income);
    final totalExpense = round2(expenses + workshops + sports + utility);
    return {
      'fees_collected': collected,
      'fees_remaining': remaining,
      'manual_income': income,
      'total_income': totalIncome,
      'expenses': expenses,
      'workshops': workshops,
      'sports': sports,
      'utility_fee': utility,
      'total_expense': totalExpense,
      'balance': round2(totalIncome - totalExpense),
    };
  }

  Map<String, dynamic> _addMoney(String kind, Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can change the money book');
    final row = {'id': _id('m'), ...body, 'amount': (body['amount'] as num?)?.toDouble() ?? 0};
    state[kind] = [..._rows(kind), row];
    return row;
  }

  Map<String, dynamic> _dashboard() {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final today = _today();
    final away = _rows('absences').where((a) => a['date'] == today).length;
    return {'head': _summary(_classes().first['id'].toString())['head']..['students'] = _pupils().length, 'finance': _finance(), 'absent_today': away};
  }

  Map<String, dynamic> _staffStats() {
    var tm = 0, tf = 0, nm = 0, nf = 0;
    final quals = <String, Map<String, dynamic>>{};
    for (final person in _staff()) {
      final teaching = person['staff_type'] == 'teaching';
      final male = person['sex'] == 'M';
      if (teaching && male) tm++;
      if (teaching && !male) tf++;
      if (!teaching && male) nm++;
      if (!teaching && !male) nf++;
      final q = person['qualification']?.toString() ?? '';
      final row = quals.putIfAbsent(q, () => {'qualification': q, 'male': 0, 'female': 0});
      if (male) {
        row['male'] = (row['male'] as int) + 1;
      } else {
        row['female'] = (row['female'] as int) + 1;
      }
    }
    return {'teaching_male': tm, 'teaching_female': tf, 'non_teaching_male': nm, 'non_teaching_female': nf, 'by_qualification': quals.values.toList()};
  }

  List<Map<String, dynamic>> _absences(String? year, String? month) {
    _require();
    return _rows('absences').where((a) {
      final date = a['date']?.toString() ?? '';
      if (year != null && !date.startsWith(year)) return false;
      if (month != null && date.length >= 7 && int.tryParse(date.substring(5, 7)) != int.tryParse(month)) return false;
      return true;
    }).toList();
  }

  Map<String, dynamic> _addAbsence(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can mark absence');
    final row = {'id': _id('ab'), 'staff_id': body['staff_id'], 'date': body['date']?.toString() ?? '', 'note': body['note']?.toString() ?? ''};
    state['absences'] = [..._rows('absences'), row];
    return row;
  }

  Map<String, dynamic> _deleteAbsence(String id) {
    if (!_isAdmin()) throw ApiException('Only the school admin can mark absence');
    state['absences'] = _rows('absences').where((a) => a['id'].toString() != id).toList();
    return {'ok': true};
  }

  Map<String, dynamic> _addMakeup(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can record make-up periods');
    final row = {'id': _id('mk'), 'staff_id': body['staff_id'], 'date': body['date']?.toString() ?? '', 'periods': (body['periods'] as num?)?.toInt() ?? 0, 'note': body['note']?.toString() ?? ''};
    state['makeups'] = [..._rows('makeups'), row];
    return row;
  }

  Map<String, dynamic> _absenceReport(String staffId, String? year, String? month) {
    _require();
    final y = int.tryParse(year ?? '') ?? DateTime.now().year;
    final m = int.tryParse(month ?? '') ?? DateTime.now().month;
    final days = _rows('absences').where((a) => a['staff_id'].toString() == staffId && a['date'].toString().startsWith('${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}')).toList();
    final bell = state['bell'] as Map;
    final dayCount = (bell['days'] as num?)?.toInt() ?? 5;
    var missed = 0;
    var scheduled = 0;
    final last = DateTime(y, m + 1, 0).day;
    for (var d = 1; d <= last; d++) {
      final date = DateTime(y, m, d);
      final weekday = date.weekday - 1;
      if (weekday < 0 || weekday >= dayCount) continue;
      final periods = _rows('slots').where((s) => s['teacher_staff_id'].toString() == staffId && (s['day'] as num).toInt() == weekday).length;
      scheduled += periods;
      if (days.any((a) => a['date'] == '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}')) {
        missed += periods;
      }
    }
    var makeup = 0;
    for (final row in _rows('makeups').where((r) => r['staff_id'].toString() == staffId)) {
      makeup += (row['periods'] as num?)?.toInt() ?? 0;
    }
    final lost = missed - makeup < 0 ? 0 : missed - makeup;
    final percent = scheduled == 0 ? 0 : round2(lost / scheduled * 100);
    return {'absent_days': days.length, 'lost_periods': lost, 'makeup_periods': makeup, 'percent_lost': percent};
  }

  Map<String, dynamic> _saveSettings(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can change settings');
    final weights = Map<String, dynamic>.from((body['weights'] as Map?) ?? defaultWeights);
    if (!weightsValid(weights)) throw ApiException('the six parts must add up to 60');
    final current = Map<String, dynamic>.from(state['settings'] as Map);
    current.addAll(body);
    current['weights'] = weights;
    state['settings'] = current;
    return current;
  }

  List<Map<String, dynamic>> _backupList() {
    final dir = Directory('$directory/backups');
    if (!dir.existsSync()) return [];
    return dir.listSync().whereType<File>().map((f) => {'name': f.uri.pathSegments.last}).toList();
  }

  Map<String, dynamic> _backup() {
    if (!_isAdmin()) throw ApiException('Only the school admin can make a backup');
    final dir = Directory('$directory/backups');
    dir.createSync(recursive: true);
    final name = 'school-${DateTime.now().millisecondsSinceEpoch}.json';
    File('${dir.path}/$name').writeAsStringSync(jsonEncode(state));
    return {'name': name};
  }

  Map<String, dynamic> _restore(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can restore a backup');
    final name = body['name']?.toString() ?? '';
    final file = File('$directory/backups/$name');
    if (!file.existsSync()) throw ApiException('That backup was not found');
    state = Map<String, dynamic>.from(_norm(jsonDecode(file.readAsStringSync())) as Map);
    return {'ok': true};
  }

  Map<String, dynamic> _addMeeting(Map<String, dynamic> body) {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final row = {
      'id': _id('mt'),
      'meeting_date': body['meeting_date']?.toString() ?? _today(),
      'title': body['title']?.toString() ?? '',
      'attendees': body['attendees']?.toString() ?? '',
      'notes': body['notes']?.toString() ?? '',
    };
    state['meetings'] = [..._rows('meetings'), row];
    return row;
  }

  Map<String, dynamic> _addUser(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can add a login');
    final row = {
      'id': _id('u'),
      'username': body['username']?.toString() ?? '',
      'role': body['role']?.toString() ?? 'teacher',
      'display_name': body['display_name']?.toString() ?? '',
      'staff_id': body['staff_id']?.toString() ?? '',
      'active': true,
    };
    state['users'] = [..._rows('users'), row];
    return row;
  }

  Map<String, dynamic> _saveBell(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can change the week');
    state['bell'] = {'days': (body['days'] as num?)?.toInt() ?? 5, 'periods_per_day': (body['periods_per_day'] as num?)?.toInt() ?? 6};
    return state['bell'] as Map<String, dynamic>;
  }

  Map<String, dynamic> _generate() {
    if (!_isAdmin()) throw ApiException('Only the school admin can make the week');
    final bell = state['bell'] as Map;
    try {
      final placed = placeWeek(days: (bell['days'] as num).toInt(), periodsPerDay: (bell['periods_per_day'] as num).toInt(), lessons: _lessons());
      final slots = <Map<String, dynamic>>[];
      for (final row in placed) {
        slots.add({'id': _id('sl'), ...row});
      }
      state['slots'] = slots;
      return {'ok': true, 'slots': slots.length};
    } on StateError catch (e) {
      throw ApiException(e.message);
    }
  }

  Map<String, dynamic> _move(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can move a lesson');
    final slots = _rows('slots');
    final day = (body['to_day'] as num? ?? body['day'] as num).toInt();
    final period = (body['to_period'] as num? ?? body['period'] as num).toInt();
    final from = slots.where((s) {
      if (body['slot_id'] != null) return s['id'].toString() == body['slot_id'].toString();
      return s['class_id'].toString() == body['class_id'].toString() && (s['day'] as num).toInt() == (body['from_day'] as num).toInt() && (s['period'] as num).toInt() == (body['from_period'] as num).toInt();
    }).toList();
    if (from.isEmpty) throw ApiException('That lesson was not found');
    final moving = from.first;
    for (final slot in slots) {
      if (slot['id'] == moving['id']) continue;
      final sameTime = (slot['day'] as num).toInt() == day && (slot['period'] as num).toInt() == period;
      if (!sameTime) continue;
      if (slot['class_id'] == moving['class_id'] || slot['teacher_staff_id'] == moving['teacher_staff_id']) {
        throw ApiException('That period is already taken');
      }
    }
    moving['day'] = day;
    moving['period'] = period;
    _replace('slots', moving);
    return moving;
  }

  List<int> _timetablePdf() {
    final lines = <String>['Hope Academy week'];
    for (final slot in _rows('slots').take(30)) {
      lines.add('${slot['class_name']} day ${slot['day']} period ${slot['period']} ${slot['subject_name']}');
    }
    return simplePdf('Hope Academy', lines);
  }

  List<int> _export(Map<String, dynamic> body) {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final format = body['format']?.toString() ?? 'pdf';
    final lines = _reportLines();
    if (format == 'docx') return simpleDocx('Hope Academy', lines);
    if (format == 'pptx') return simplePptx('Hope Academy', lines);
    return simplePdf('Hope Academy', lines);
  }

  List<String> _reportLines() {
    final finance = _finance();
    return [
      'Hope Academy',
      'Students ${_pupils().length}',
      'Fees in ${finance['fees_collected']} still to pay ${finance['fees_remaining']}',
      'Balance ${finance['balance']}',
      'Developed by 9 Multimedia and IT Solutions · SHAMM TESFALEM · 07162947',
    ];
  }

  Map<String, dynamic> _closeSemester() {
    if (!_isAdmin()) throw ApiException('Only the school admin can make the statistics');
    final files = <Map<String, dynamic>>[];
    for (final cls in _classes()) {
      final id = _id('rp');
      final title = '${cls['name']} statistics';
      final bytes = simplePdf(title, ['Hope Academy', title, 'Students in this section are listed in the results.']);
      Directory('$directory/reports').createSync(recursive: true);
      File('$directory/reports/$id.pdf').writeAsBytesSync(bytes);
      files.add({'id': id, 'title': title, 'class_id': cls['id']});
    }
    state['reports'] = files;
    return {'ok': true, 'count': files.length};
  }

  List<int> _reportBytes(String id) {
    final file = File('$directory/reports/$id.pdf');
    if (!file.existsSync()) throw ApiException('Could not open the file');
    return file.readAsBytesSync();
  }

  void _push(String key, Map<String, dynamic> row) {
    (state[key] as List).add(row);
  }

  void _ensureColumns(String lessonId) {
    final columns = state['assessments'] as List;
    for (final component in caParts) {
      for (final half in [1, 2]) {
        columns.add({
          'id': _id('as'),
          'class_subject_id': lessonId,
          'component': component,
          'half': half,
          'title': '$component $half',
          'max_marks': 10,
          'assessment_date': '',
          'revision': 1,
        });
      }
    }
    columns.add({
      'id': _id('as'),
      'class_subject_id': lessonId,
      'component': 'exam',
      'half': 0,
      'title': 'Exam',
      'max_marks': 40,
      'assessment_date': '',
      'revision': 1,
    });
    state['assessments'] = columns;
  }

  Map<String, dynamic> _fresh() {
    state = {
      'seed': 5,
      'seq': 0,
      'settings': {
        'academic_year': '2026',
        'semester': 1,
        'semester_end': '2026-06-30',
        'yearly_fee': 4500,
        'utility_fee': 800,
        'ca_locked': true,
        'weights': Map<String, dynamic>.from(defaultWeights),
        'fail_limits': {'elementary': 2, 'junior': 3, 'high': 3},
        'backup_dir': '',
        'sample_data': true,
        'grade_labels': '',
      },
      'bell': {'days': 5, 'periods_per_day': 6},
      'staff': <Map<String, dynamic>>[],
      'classes': <Map<String, dynamic>>[],
      'subjects': <Map<String, dynamic>>[],
      'class_subjects': <Map<String, dynamic>>[],
      'students': <Map<String, dynamic>>[],
      'assessments': <Map<String, dynamic>>[],
      'scores': <Map<String, dynamic>>[],
      'payments': <Map<String, dynamic>>[],
      'incomes': <Map<String, dynamic>>[],
      'expenses': <Map<String, dynamic>>[],
      'workshops': <Map<String, dynamic>>[],
      'sports': <Map<String, dynamic>>[],
      'absences': <Map<String, dynamic>>[],
      'makeups': <Map<String, dynamic>>[],
      'meetings': <Map<String, dynamic>>[],
      'users': <Map<String, dynamic>>[],
      'slots': <Map<String, dynamic>>[],
      'reports': <Map<String, dynamic>>[],
      'notices': <Map<String, dynamic>>[],
      'calendar': <Map<String, dynamic>>[],
      'attendance': <Map<String, dynamic>>[],
    };
    _seed();
    return state;
  }

  void _seed() {
    const subjects = ['Mathematics', 'English', 'Science', 'Social studies'];
    for (final name in subjects) {
      state['subjects'] = [
        ..._subjects(),
        {'id': _id('sub'), 'name': name, 'code': ''},
      ];
    }
    final subjectRows = _subjects();
    final first = ['Abel', 'Hanna', 'Dawit', 'Sara', 'Yonas', 'Liya', 'Nahom', 'Bethel', 'Kaleb', 'Helen', 'Ruth', 'Elias', 'Marta', 'Noah', 'Eden', 'Tigist', 'Biruk', 'Selam', 'Henok', 'Mahlet'];
    final last = ['Tesfaye', 'Bekele', 'Hailu', 'Tadesse', 'Kebede', 'Alemu', 'Girma', 'Desta', 'Worku', 'Mengistu'];
    final classes = <Map<String, dynamic>>[];
    for (var grade = 1; grade <= 12; grade++) {
      final sections = grade <= 8 ? ['A', 'B'] : ['A'];
      for (final section in sections) {
        classes.add({'grade': grade, 'section': section, 'name': 'Grade $grade$section'});
      }
    }
    Map<String, dynamic> person(String name, String sex, String kind, String qual) {
      final row = {'id': _id('st'), 'full_name': name, 'sex': sex, 'staff_type': kind, 'employee_id': 'E${(_staff().length + 1).toString().padLeft(3, '0')}', 'qualification': qual, 'phone': '0911${(100000 + _staff().length).toString().padLeft(6, '0')}', 'village': 'Addis Ababa'};
      _push('staff', row);
      return row;
    }

    final samuel = person('Samuel Bekele', 'M', 'teaching', 'degree');
    final meron = person('Meron Alemu', 'F', 'teaching', 'degree');
    final extraScience = person('Sara Tesfaye', 'F', 'teaching', 'degree');
    final extraSocial = person('Yonas Bekele', 'M', 'teaching', 'degree');
    var teacherNo = 0;
    for (final cls in classes) {
      final grade = cls['grade'] as int;
      final level = grade <= 6 ? 'elementary' : (grade <= 8 ? 'junior' : 'high');
      final isSamuel = cls['name'] == 'Grade 8A';
      final teacher = isSamuel
          ? samuel
          : person('${first[teacherNo % first.length]} ${last[teacherNo % last.length]}', teacherNo.isEven ? 'F' : 'M', 'teaching', grade >= 9 ? 'degree' : 'diploma');
      if (!isSamuel) teacherNo++;
      final classRow = {
        'id': _id('c'),
        'name': cls['name'],
        'level': level,
        'grade': grade,
        'academic_year': '2026',
        'homeroom_staff_id': teacher['id'],
        'homeroom_name': teacher['full_name'],
      };
      _push('classes', classRow);
      for (final subject in subjectRows) {
        var who = teacher;
        if (subject['name'] == 'Mathematics' && (cls['name'] == 'Grade 6A' || cls['name'] == 'Grade 7A' || cls['name'] == 'Grade 8A' || cls['name'] == 'Grade 8B')) {
          who = _byName(_staff(), 'Samuel Bekele');
        }
        if (subject['name'] == 'English' && (grade >= 8 && cls['section'] == 'A' || cls['name'] == 'Grade 8A')) {
          who = meron;
        }
        if (cls['name'] == 'Grade 8A' && subject['name'] == 'Science') who = extraScience;
        if (cls['name'] == 'Grade 8A' && subject['name'] == 'Social studies') who = extraSocial;
        final lesson = {
          'id': _id('ls'),
          'class_id': classRow['id'],
          'class_name': classRow['name'],
          'subject_id': subject['id'],
          'subject_name': subject['name'],
          'teacher_staff_id': who['id'],
          'teacher_name': who['full_name'],
          'periods_per_week': 2,
          'semester': 1,
          'weights': Map<String, dynamic>.from(defaultWeights),
        };
        _push('class_subjects', lesson);
        _ensureColumns(lesson['id'] as String);
      }
    }
    person('Hanna Desta', 'F', 'non-teaching', 'diploma');
    person('Kaleb Worku', 'M', 'non-teaching', 'certificate');
    const factors = [1.0, 0.85, 0.85, 0.70, 0.50, 0.40, 0.95, 0.60, 0.30, 0.75];
    final classList = _classes();
    var pupilNo = 0;
    for (final cls in classList) {
      for (var n = 0; n < 10; n++) {
        final name = '${first[pupilNo % first.length]} ${last[(pupilNo ~/ first.length) % last.length]}';
        final unique = pupilNo < first.length * last.length ? name : '$name $pupilNo';
        final student = {
          'id': _id('p'),
          'full_name': unique,
          'sex': pupilNo % 3 == 0 ? 'M' : 'F',
          'mother_name': '${first[(pupilNo + 3) % first.length]} ${last[pupilNo % last.length]}',
          'class_id': cls['id'],
          'dropped_out': cls['name'] == 'Grade 12A' && n == 9,
          'dropout_reason': cls['name'] == 'Grade 12A' && n == 9 ? 'Moved away' : '',
          'dropout_date': cls['name'] == 'Grade 12A' && n == 9 ? '2026-10-02' : '',
          'father_name': '${first[(pupilNo + 5) % first.length]} ${last[(pupilNo + 2) % last.length]}',
          'phone': '09${(11000000 + pupilNo).toString()}',
          'address': 'Hope neighbourhood',
          'remark': n == 0 ? 'A steady worker. Keep it up.' : '',
        };
        _push('students', student);
        final factor = factors[n];
        for (final lesson in _lessons().where((l) => l['class_id'] == cls['id'])) {
          for (final assessment in (state['assessments'] as List).where((a) => (a as Map)['class_subject_id'] == lesson['id'])) {
            final max = ((assessment as Map)['max_marks'] as num).toDouble();
            final score = round2(max * factor);
            _push('scores', {'id': _id('sc'), 'assessment_id': assessment['id'], 'student_id': student['id'], 'score': score > max ? max : score, 'revision': 1, 'updated_at': ''});
          }
        }
        final pay = n % 3 == 0 ? 4500 : (n % 3 == 1 ? 1500 : 0);
        if (pay > 0) {
          _push('payments', {'id': _id('pay'), 'student_id': student['id'], 'academic_year': '2026', 'amount': pay, 'paid_on': '2026-09-12'});
        }
        if (cls['name'] == 'Grade 8A') {
          for (final day in ['2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05']) {
            _push('attendance', {'id': _id('at'), 'student_id': student['id'], 'class_id': cls['id'], 'date': day, 'present': n == 4 && day == '2026-11-03' ? false : true});
          }
        }
        pupilNo++;
      }
    }
    state['incomes'] = [
      {'id': _id('m'), 'amount': 12000, 'source': 'Registration', 'received_on': '2026-09-01', 'note': ''},
    ];
    state['expenses'] = [
      {'id': _id('m'), 'amount': 3500, 'reason': 'Chalk and paper', 'spent_on': '2026-09-04', 'receipt_number': 'R-14', 'cheque_number': ''},
    ];
    state['workshops'] = [
      {'id': _id('m'), 'amount': 800, 'description': 'Science workshop', 'attended_on': '2026-10-03', 'days': 1},
    ];
    state['sports'] = [
      {'id': _id('m'), 'amount': 600, 'reason': 'Balls', 'spent_on': '2026-10-11'},
    ];
    state['meetings'] = [
      {'id': _id('mt'), 'meeting_date': '2026-09-15', 'title': 'Opening meeting', 'attendees': 'All teachers', 'notes': 'Term dates and fees'},
    ];
    state['users'] = [
      {'id': _id('u'), 'username': 'admin', 'role': 'admin', 'display_name': 'School admin', 'staff_id': '', 'active': true},
      {'id': _id('u'), 'username': 'director', 'role': 'director', 'display_name': 'Director', 'staff_id': '', 'active': true},
    ];
    state['absences'] = [
      {'id': _id('ab'), 'staff_id': _byName(_staff(), 'Samuel Bekele')['id'], 'date': '2026-11-02', 'note': ''},
    ];
    final placed = placeWeek(days: 5, periodsPerDay: 6, lessons: _lessons());
    state['slots'] = [for (final row in placed) {'id': _id('sl'), ...row}];
    _push('notices', {'id': _id('nt'), 'title': 'Staff meeting Friday', 'body': 'Meet in the hall at 4. Bring the class lists.', 'date': '2026-11-12', 'audience': 'staff'});
    _push('notices', {'id': _id('nt'), 'title': 'Fee reminder', 'body': 'Please remind families who still owe the yearly fee.', 'date': '2026-11-08', 'audience': 'staff'});
    _push('calendar', {'id': _id('cal'), 'date': '2026-09-01', 'title': 'Term 1 starts', 'kind': 'term'});
    _push('calendar', {'id': _id('cal'), 'date': '2026-11-20', 'title': 'Mid exam', 'kind': 'exam'});
    _push('calendar', {'id': _id('cal'), 'date': '2026-12-24', 'title': 'Holiday', 'kind': 'holiday'});
  }

  List<Map<String, dynamic>> _search(String q) {
    _require();
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return [];
    final hits = <Map<String, dynamic>>[];
    for (final student in _pupils()) {
      if (student['full_name'].toString().toLowerCase().contains(needle)) {
        hits.add({'kind': 'student', 'id': student['id'], 'name': student['full_name'], 'detail': 'Student'});
      }
    }
    for (final person in _staff()) {
      if (person['full_name'].toString().toLowerCase().contains(needle)) {
        hits.add({'kind': 'staff', 'id': person['id'], 'name': person['full_name'], 'detail': person['staff_type'] == 'teaching' ? 'Teacher' : 'Office'});
      }
    }
    return hits;
  }

  Map<String, dynamic> _addNotice(Map<String, dynamic> body) {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final row = {'id': _id('nt'), 'title': body['title']?.toString() ?? '', 'body': body['body']?.toString() ?? '', 'date': body['date']?.toString() ?? _today(), 'audience': 'staff'};
    _push('notices', row);
    return row;
  }

  Map<String, dynamic> _addCalendar(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can change the calendar');
    final row = {'id': _id('cal'), 'date': body['date']?.toString() ?? _today(), 'title': body['title']?.toString() ?? '', 'kind': body['kind']?.toString() ?? 'term'};
    _push('calendar', row);
    return row;
  }

  Map<String, dynamic> _charts() {
    if (!_seesSchool()) throw ApiException('That is for the office');
    final summary = _resultSummary();
    final fees = _feeSummary();
    var male = 0, female = 0;
    for (final student in _pupils()) {
      if (student['sex'] == 'M') male++;
      if (student['sex'] == 'F') female++;
    }
    final trend = <Map<String, dynamic>>[];
    for (final day in ['2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05']) {
      final rows = (state['attendance'] as List).where((a) => (a as Map)['date'] == day).toList();
      final present = rows.where((a) => (a as Map)['present'] == true).length;
      trend.add({'date': day, 'present': present, 'total': rows.length});
    }
    return {
      'pass_by_grade': summary['grades'],
      'fees_by_grade': fees['grades'],
      'male': male,
      'female': female,
      'attendance': trend,
    };
  }

  List<Map<String, dynamic>> _matrix() {
    _require();
    return _lessons();
  }

  List<Map<String, dynamic>> _defaulters() {
    if (!_seesSchool() && _homes().isEmpty) throw ApiException('That is for the office');
    return _fees(null).where((row) => ((row['remaining'] as num?) ?? 0) > 0).toList();
  }

  List<int> _receipt(String paymentId) {
    final pay = _byId(_rows('payments'), paymentId);
    final student = _byId(_pupils(), pay['student_id'].toString());
    return simplePdf('Fee receipt', ['Hope Academy', student['full_name'].toString(), 'Paid ${pay['amount']} on ${pay['paid_on']}', 'Yearly fee $_fee']);
  }

  List<int> _reportCard(String studentId) {
    final student = _byId(_pupils(), studentId);
    final result = _results(student['class_id'].toString());
    Map<String, dynamic>? row;
    for (final item in (result['students'] as List)) {
      if ((item as Map)['student']['id'] == studentId) row = Map<String, dynamic>.from(item);
    }
    final standing = (row?['standing'] as Map?) ?? {};
    return simplePdf('Report card', [
      'Hope Academy',
      student['full_name'].toString(),
      'Average ${standing['average'] ?? '—'}  Rank ${standing['rank'] ?? '—'}',
      'Remark: ${student['remark'] ?? ''}',
    ]);
  }

  List<int> _idCard(String studentId) {
    final student = _byId(_pupils(), studentId);
    final cls = _byId(_classes(), student['class_id'].toString());
    return simplePdf('Student card', ['Hope Academy', student['full_name'].toString(), cls['name'].toString(), 'Mother ${student['mother_name']}', 'Phone ${student['phone'] ?? ''}']);
  }

  List<int> _roster(String classId) {
    final cls = _byId(_classes(), classId);
    final lines = <String>['Hope Academy', cls['name'].toString(), 'Homeroom ${cls['homeroom_name']}'];
    for (final student in _pupils().where((s) => s['class_id'] == classId)) {
      lines.add('${student['full_name']}  ${student['sex']}');
    }
    return simplePdf('Class list', lines);
  }

  Map<String, dynamic> _promote(Map<String, dynamic> body) {
    if (!_isAdmin()) throw ApiException('Only the school admin can promote a class');
    final cls = _byId(_classes(), body['class_id'].toString());
    final nextGrade = (cls['grade'] as num).toInt() + 1;
    final letter = cls['name'].toString().replaceAll(RegExp(r'[^A-Z]'), '');
    final next = _classes().where((c) => (c['grade'] as num).toInt() == nextGrade && c['name'].toString().endsWith(letter)).toList();
    if (next.isEmpty) throw ApiException('There is no next grade for this class');
    var moved = 0;
    for (final student in _pupils()) {
      if (student['class_id'] != cls['id'] || student['dropped_out'] == true) continue;
      student['class_id'] = next.first['id'];
      _replace('students', student);
      moved++;
    }
    return {'ok': true, 'moved': moved, 'to': next.first['name']};
  }

  Map<String, dynamic> _attendance(String? classId, String? date) {
    final who = _require();
    final day = date ?? _today();
    final id = classId ?? (_homes().isNotEmpty ? _homes().first : '');
    if (id.isEmpty) throw ApiException('Choose a class');
    if (!_seesSchool() && !_homes().contains(id) && who['staff_id']?.toString() != _byId(_classes(), id)['homeroom_staff_id'].toString()) {
      throw ApiException('Only the homeroom teacher can take attendance');
    }
    final pupils = _pupils().where((s) => s['class_id'] == id && s['dropped_out'] != true).toList();
    final marks = (state['attendance'] as List).where((a) => (a as Map)['class_id'] == id && a['date'] == day).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    var present = 0;
    for (final mark in marks) {
      if (mark['present'] == true) present++;
    }
    final month = day.length >= 7 ? day.substring(0, 7) : '';
    final monthMarks = (state['attendance'] as List).where((a) {
      final row = a as Map;
      return row['class_id'] == id && row['date'].toString().startsWith(month);
    }).toList();
    final monthPresent = monthMarks.where((a) => (a as Map)['present'] == true).length;
    final percent = monthMarks.isEmpty ? 0 : round2(monthPresent / monthMarks.length * 100);
    return {'class_id': id, 'date': day, 'students': pupils, 'marks': marks, 'present': present, 'percent': percent};
  }

  Map<String, dynamic> _markAttendance(Map<String, dynamic> body) {
    final classId = body['class_id']?.toString() ?? '';
    if (!_homes().contains(classId)) throw ApiException('Only the homeroom teacher can take attendance');
    final date = body['date']?.toString() ?? _today();
    final studentId = body['student_id'].toString();
    final present = body['present'] == true;
    final rows = (state['attendance'] as List).cast<Map>();
    for (final row in rows) {
      if (row['student_id'] == studentId && row['date'] == date) {
        row['present'] = present;
        return Map<String, dynamic>.from(row);
      }
    }
    final row = {'id': _id('at'), 'student_id': studentId, 'class_id': classId, 'date': date, 'present': present};
    _push('attendance', row);
    return row;
  }

  Map<String, dynamic> _saveProfile(String id, Map<String, dynamic> body) {
    final student = _byId(_pupils(), id);
    final classId = student['class_id'].toString();
    if (!_isAdmin() && !_homes().contains(classId)) throw ApiException('Only the homeroom teacher can change this list');
    for (final key in ['phone', 'address', 'father_name', 'mother_name', 'remark']) {
      if (body.containsKey(key)) student[key] = body[key]?.toString() ?? '';
    }
    _replace('students', student);
    return student;
  }
}

dynamic _norm(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _norm(v)));
  }
  if (value is List) return value.map(_norm).toList();
  return value;
}

String _today() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

