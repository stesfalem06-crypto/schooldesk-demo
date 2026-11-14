import 'dart:convert';
import 'dart:typed_data';

double round2(double x) {
  if (x.isNaN || x.isInfinite) return 0;
  return (x * 100).roundToDouble() / 100;
}

const defaultWeights = {
  'classwork': 10.0,
  'quizzes': 10.0,
  'tests': 10.0,
  'assignments': 10.0,
  'participation': 10.0,
  'homework': 10.0,
};

const caParts = ['classwork', 'quizzes', 'tests', 'assignments', 'participation', 'homework'];

bool weightsValid(Map<String, dynamic> weights) {
  var sum = 0.0;
  for (final key in caParts) {
    final n = (weights[key] as num?)?.toDouble() ?? -1;
    if (n < 0) return false;
    sum += n;
  }
  return round2(sum) == 60;
}

class SubjectMark {
  SubjectMark({required this.mid, required this.continuous, required this.exam, required this.total, required this.examSet, required this.passed});
  final double mid;
  final double continuous;
  final double exam;
  final double total;
  final bool examSet;
  final bool passed;
}

SubjectMark summarize(Map<String, dynamic> weights, List<Map<String, dynamic>> items) {
  if (!weightsValid(weights)) {
    throw StateError('the six parts must add up to 60');
  }
  final got = <String, List<double>>{};
  var examGot = 0.0;
  var examMax = 0.0;
  var examSet = false;
  for (final it in items) {
    if (it['score'] == null) continue;
    final score = (it['score'] as num).toDouble();
    final max = (it['max'] as num).toDouble();
    if (max <= 0) throw StateError('the full mark must be more than zero');
    if (score < 0 || score > max) throw StateError('a mark is outside the allowed range');
    final component = it['component'].toString();
    if (component == 'exam') {
      examGot += score;
      examMax += max;
      examSet = true;
      continue;
    }
    final half = (it['half'] as num).toInt();
    final acc = got['$component|$half'] ?? [0, 0];
    acc[0] += score;
    acc[1] += max;
    got['$component|$half'] = acc;
  }
  var mid = 0.0;
  var second = 0.0;
  for (final component in caParts) {
    final halfW = ((weights[component] as num?)?.toDouble() ?? 0) / 2;
    for (final half in [1, 2]) {
      final acc = got['$component|$half'];
      if (acc == null || acc[1] == 0) continue;
      final part = round2(acc[0] / acc[1] * halfW);
      if (half == 1) {
        mid += part;
      } else {
        second += part;
      }
    }
  }
  mid = round2(mid);
  if (mid > 30) mid = 30;
  var cont = round2(mid + second);
  if (cont > 60) cont = 60;
  var exam = 0.0;
  if (examSet && examMax > 0) {
    exam = round2(examGot / examMax * 40);
    if (exam > 40) exam = 40;
  }
  var total = round2(cont + exam);
  if (total > 100) total = 100;
  return SubjectMark(mid: mid, continuous: cont, exam: exam, total: total, examSet: examSet, passed: total > 50);
}

class PupilStanding {
  PupilStanding({required this.id, required this.average, required this.rank, required this.failedSubjects, required this.passedSubjects, required this.status});
  final String id;
  double average;
  int rank;
  int failedSubjects;
  int passedSubjects;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'average': average,
        'rank': rank,
        'failed_subjects': failedSubjects,
        'passed_subjects': passedSubjects,
        'status': status,
      };
}

int failLimit(Map<String, dynamic> limits, String level) {
  if (level == 'elementary') return (limits['elementary'] as num?)?.toInt() ?? 2;
  if (level == 'junior') return (limits['junior'] as num?)?.toInt() ?? 3;
  return (limits['high'] as num?)?.toInt() ?? 3;
}

List<PupilStanding> standings(List<Map<String, dynamic>> pupils, Map<String, dynamic> limits) {
  final out = <PupilStanding>[];
  final ranked = <int>[];
  for (var i = 0; i < pupils.length; i++) {
    final pupil = pupils[i];
    final row = PupilStanding(id: pupil['id'].toString(), average: 0, rank: 0, failedSubjects: 0, passedSubjects: 0, status: 'incomplete');
    final totals = (pupil['totals'] as List?) ?? [];
    if (pupil['dropout'] == true) {
      row.status = 'dropout';
    } else if (totals.isEmpty) {
      row.status = 'incomplete';
    } else {
      var sum = 0.0;
      for (final total in totals) {
        final n = (total as num).toDouble();
        sum += n;
        if (n > 50) {
          row.passedSubjects++;
        } else {
          row.failedSubjects++;
        }
      }
      row.average = round2(sum / totals.length);
      final limit = failLimit(limits, pupil['level']?.toString() ?? 'junior');
      row.status = row.average > 50 && row.failedSubjects < limit ? 'promoted' : 'failed';
      ranked.add(i);
    }
    out.add(row);
  }
  ranked.sort((a, b) {
    final diff = out[b].average.compareTo(out[a].average);
    if (diff != 0) return diff;
    return out[a].id.compareTo(out[b].id);
  });
  for (var n = 0; n < ranked.length; n++) {
    var rank = n + 1;
    if (n > 0 && out[ranked[n]].average == out[ranked[n - 1]].average) {
      rank = out[ranked[n - 1]].rank;
    }
    out[ranked[n]].rank = rank;
  }
  return out;
}

List<Map<String, dynamic>> placeWeek({
  required int days,
  required int periodsPerDay,
  required List<Map<String, dynamic>> lessons,
}) {
  if (days < 1 || days > 7 || periodsPerDay < 1 || periodsPerDay > 16) {
    throw StateError('check the days and the periods in a day');
  }
  final slots = days * periodsPerDay;
  final units = <Map<String, dynamic>>[];
  final classLoad = <String, int>{};
  final teacherLoad = <String, int>{};
  for (final lesson in lessons) {
    final count = (lesson['periods_per_week'] as num?)?.toInt() ?? 0;
    if (count < 1) throw StateError('each subject needs at least one period a week');
    final classId = lesson['class_id'].toString();
    final teacherId = lesson['teacher_staff_id'].toString();
    classLoad[classId] = (classLoad[classId] ?? 0) + count;
    teacherLoad[teacherId] = (teacherLoad[teacherId] ?? 0) + count;
    for (var i = 0; i < count; i++) {
      units.add(lesson);
    }
  }
  for (final n in classLoad.values) {
    if (n > slots) throw StateError('a class has more periods than the week has');
  }
  for (final n in teacherLoad.values) {
    if (n > slots) throw StateError('a teacher has more lessons than free periods');
  }
  units.sort((a, b) => (teacherLoad[b['teacher_staff_id']] ?? 0).compareTo(teacherLoad[a['teacher_staff_id']] ?? 0));
  final classBusy = <String, Set<int>>{};
  final teacherBusy = <String, Set<int>>{};
  final placed = <Map<String, dynamic>>[];
  for (final lesson in units) {
    final classId = lesson['class_id'].toString();
    final teacherId = lesson['teacher_staff_id'].toString();
    var found = false;
    for (var day = 0; day < days && !found; day++) {
      for (var period = 0; period < periodsPerDay && !found; period++) {
        final slot = day * periodsPerDay + period;
        if ((classBusy[classId] ?? {}).contains(slot) || (teacherBusy[teacherId] ?? {}).contains(slot)) continue;
        classBusy.putIfAbsent(classId, () => {}).add(slot);
        teacherBusy.putIfAbsent(teacherId, () => {}).add(slot);
        placed.add({
          'class_id': classId,
          'day': day,
          'period': period,
          'class_subject_id': lesson['id'],
          'teacher_staff_id': teacherId,
          'subject_name': lesson['subject_name'],
          'teacher_name': lesson['teacher_name'],
          'class_name': lesson['class_name'],
        });
        found = true;
      }
    }
    if (!found) throw StateError('no clash-free timetable was found. Free a teacher or lower the periods');
  }
  return placed;
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) == 1) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

List<int> zipStore(Map<String, String> files) {
  final local = BytesBuilder();
  final central = BytesBuilder();
  var offset = 0;
  for (final name in files.keys) {
    final nameBytes = utf8.encode(name);
    final data = utf8.encode(files[name]!);
    final crc = _crc32(data);
    final head = BytesBuilder();
    void u16(BytesBuilder b, int n) => b.add([n & 255, (n >> 8) & 255]);
    void u32(BytesBuilder b, int n) => b.add([n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >> 24) & 255]);
    head.add([0x50, 0x4b, 0x03, 0x04]);
    u16(head, 20);
    u16(head, 0);
    u16(head, 0);
    u16(head, 0);
    u16(head, 0);
    u32(head, crc);
    u32(head, data.length);
    u32(head, data.length);
    u16(head, nameBytes.length);
    u16(head, 0);
    head.add(nameBytes);
    head.add(data);
    final bytes = head.toBytes();
    local.add(bytes);
    final cen = BytesBuilder();
    cen.add([0x50, 0x4b, 0x01, 0x02]);
    u16(cen, 20);
    u16(cen, 20);
    u16(cen, 0);
    u16(cen, 0);
    u16(cen, 0);
    u16(cen, 0);
    u32(cen, crc);
    u32(cen, data.length);
    u32(cen, data.length);
    u16(cen, nameBytes.length);
    u16(cen, 0);
    u16(cen, 0);
    u16(cen, 0);
    u16(cen, 0);
    u32(cen, 0);
    u32(cen, offset);
    cen.add(nameBytes);
    central.add(cen.toBytes());
    offset += bytes.length;
  }
  final centralBytes = central.toBytes();
  final end = BytesBuilder();
  void u16(int n) => end.add([n & 255, (n >> 8) & 255]);
  void u32(int n) => end.add([n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >> 24) & 255]);
  end.add([0x50, 0x4b, 0x05, 0x06]);
  u16(0);
  u16(0);
  u16(files.length);
  u16(files.length);
  u32(centralBytes.length);
  u32(offset);
  u16(0);
  return local.toBytes() + centralBytes + end.toBytes();
}

List<int> simplePdf(String title, List<String> lines) {
  final text = StringBuffer('BT /F1 16 Tf 72 740 Td ($title) Tj ');
  for (final line in lines.take(40)) {
    final clean = line.replaceAll('(', '[').replaceAll(')', ']');
    text.write('0 -22 Td ($clean) Tj ');
  }
  text.write('ET');
  final stream = text.toString();
  final objects = <String>[
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n',
    '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n',
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n',
    '4 0 obj<</Length ${stream.length}>>stream\n$stream\nendstream\nendobj\n',
    '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final xref = <int>[0];
  for (final obj in objects) {
    xref.add(out.length);
    out.write(obj);
  }
  final start = out.length;
  out.write('xref\n0 ${xref.length}\n');
  out.write('0000000000 65535 f \n');
  for (var i = 1; i < xref.length; i++) {
    out.write('${xref[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer<</Size ${xref.length}/Root 1 0 R>>\nstartxref\n$start\n%%EOF');
  return latin1.encode(out.toString());
}

List<int> simpleDocx(String title, List<String> lines) {
  final body = StringBuffer('<w:p><w:r><w:t>${_xml(title)}</w:t></w:r></w:p>');
  for (final line in lines) {
    body.write('<w:p><w:r><w:t>${_xml(line)}</w:t></w:r></w:p>');
  }
  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>';
  return zipStore({
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>',
    'word/document.xml': document,
  });
}

List<int> simplePptx(String title, List<String> lines) {
  final text = ([title, ...lines]).map(_xml).join(' &#10; ');
  final slide = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
      '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
      '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Text"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
      '<p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="8000000" cy="4000000"/></a:xfrm></p:spPr>'
      '<p:txBody><a:bodyPr/><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody></p:sp>'
      '</p:spTree></p:cSld></p:sld>';
  return zipStore({
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
        '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
        '</Relationships>',
    'ppt/presentation.xml': '<?xml version="1.0" encoding="UTF-8"?>'
        '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst></p:presentation>',
    'ppt/_rels/presentation.xml.rels': '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>'
        '</Relationships>',
    'ppt/slides/slide1.xml': slide,
  });
}

String _xml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
