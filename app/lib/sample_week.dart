class WeekCell {
  const WeekCell({
    required this.subject,
    required this.short,
    required this.teacher,
  });

  final String subject;
  final String short;
  final String teacher;

  /// A label that stays a whole word inside a phone timetable cell.
  String get subjectLabel {
    if (subject.contains(' ') || subject.length <= 9) return subject;
    return short;
  }
}

class WeekChoice {
  const WeekChoice({required this.id, required this.label});

  final String id;
  final String label;
}

/// A solved week from sample-school.json. Days are columns and periods are rows.
class SampleWeek {
  const SampleWeek({
    required this.school,
    required this.days,
    required this.periodCount,
    required this.breakAfter,
    required this.classes,
    required this.teachers,
    required this.byClass,
    required this.byTeacher,
  });

  final String school;
  final List<String> days;
  final int periodCount;

  /// 0-based period after which the break falls. 3 means a break after period 4.
  final int breakAfter;
  final List<WeekChoice> classes;
  final List<WeekChoice> teachers;
  final Map<String, List<List<WeekCell?>>> byClass;
  final Map<String, List<List<WeekCell?>>> byTeacher;

  factory SampleWeek.parse(Map<String, dynamic> json) {
    final dayList = (json['days'] as List).cast<Map>();
    final days = [
      for (final day in dayList) (day['short'] ?? day['name']).toString(),
    ];
    final bell = (json['bell'] as Map);
    final periodCount = (bell['periodCount'] as num).toInt();
    final breakAfter = (bell['breakAfter'] as num).toInt();
    final subjects = {
      for (final subject in (json['subjects'] as List).cast<Map>())
        subject['id'].toString(): subject,
    };
    final teacherMaps = (json['teachers'] as List).cast<Map>();
    final teachers = {
      for (final teacher in teacherMaps) teacher['id'].toString(): teacher,
    };
    final classMaps = (json['classes'] as List).cast<Map>();
    final lessons = {
      for (final lesson in (json['lessons'] as List).cast<Map>())
        lesson['id'].toString(): lesson,
    };

    List<List<WeekCell?>> blank() => [
      for (var day = 0; day < days.length; day++)
        [for (var period = 0; period < periodCount; period++) null],
    ];

    final byClass = <String, List<List<WeekCell?>>>{
      for (final item in classMaps) item['id'].toString(): blank(),
    };
    final byTeacher = <String, List<List<WeekCell?>>>{
      for (final item in teacherMaps) item['id'].toString(): blank(),
    };

    String classLabel(Map item) {
      final label = '${item['grade']}-${item['section']}';
      final stream = item['stream'];
      if (stream == 'SCIENCE') return '$label (Science)';
      if (stream == 'ART') return '$label (Art)';
      if (stream != null) return '$label ($stream)';
      return label;
    }

    final classLabels = {
      for (final item in classMaps) item['id'].toString(): classLabel(item),
    };
    final placements = ((json['timetable'] as Map)['placements'] as List)
        .cast<Map>();
    for (final placement in placements) {
      final lesson = lessons[placement['lessonId'].toString()];
      if (lesson == null) continue;
      final subject = subjects[lesson['subjectId'].toString()];
      final teacher = teachers[lesson['teacherId'].toString()];
      if (subject == null || teacher == null) continue;
      final day = (placement['day'] as num).toInt();
      final period = (placement['period'] as num).toInt();
      final duration = (lesson['duration'] as num?)?.toInt() ?? 1;
      final classId = lesson['classId'].toString();
      final teacherId = lesson['teacherId'].toString();
      for (var offset = 0; offset < duration; offset++) {
        final slot = period + offset;
        if (day < 0 || day >= days.length || slot < 0 || slot >= periodCount)
          continue;
        byClass[classId]?[day][slot] = WeekCell(
          subject: subject['name'].toString(),
          short: subject['short'].toString(),
          teacher: teacher['short'].toString(),
        );
        byTeacher[teacherId]?[day][slot] = WeekCell(
          subject: subject['name'].toString(),
          short: subject['short'].toString(),
          teacher: classLabels[classId] ?? classId,
        );
      }
    }

    return SampleWeek(
      school: json['name'].toString(),
      days: days,
      periodCount: periodCount,
      breakAfter: breakAfter,
      classes: [
        for (final item in classMaps)
          WeekChoice(id: item['id'].toString(), label: classLabel(item)),
      ],
      teachers: [
        for (final item in teacherMaps)
          WeekChoice(id: item['id'].toString(), label: item['name'].toString()),
      ],
      byClass: byClass,
      byTeacher: byTeacher,
    );
  }
}
