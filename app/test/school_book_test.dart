import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk/api.dart';
import 'package:schooldesk/school_book.dart';
import 'package:schooldesk/school_rules.dart';

void main() {
  test('ranks share a place and skip the next', () {
    final rows = standings([
      {'id': 'a', 'totals': [80], 'dropout': false, 'level': 'junior'},
      {'id': 'b', 'totals': [70], 'dropout': false, 'level': 'junior'},
      {'id': 'c', 'totals': [70], 'dropout': false, 'level': 'junior'},
      {'id': 'd', 'totals': [60], 'dropout': false, 'level': 'junior'},
    ], {'elementary': 2, 'junior': 3, 'high': 3});
    expect(rows.map((r) => r.rank).toList(), [1, 2, 2, 4]);
    expect(rows.every((r) => r.status == 'promoted'), isTrue);
    final edge = standings([
      {'id': 'e', 'totals': [50], 'dropout': false, 'level': 'junior'},
      {'id': 'f', 'totals': [50.01], 'dropout': false, 'level': 'junior'},
    ], {'junior': 3});
    expect(edge.firstWhere((r) => r.id == 'e').status, 'failed');
    expect(edge.firstWhere((r) => r.id == 'f').status, 'promoted');
  });

  test('roll numbers accept commas, spaces and ranges', () {
    expect(parseRollNumbers('3, 7, 12'), [3, 7, 12]);
    expect(parseRollNumbers('3 7 12'), [3, 7, 12]);
    expect(parseRollNumbers('4-6'), [4, 5, 6]);
    expect(parseRollNumbers('6 - 4'), [4, 5, 6]);
  });

  test('sample school keeps the rules and the edits', () async {
    final dir = Directory.systemTemp.createTempSync('sd-book');
    final book = await SchoolBook.open(directory: dir.path);
    expect(book.call('GET', '/api/v1/students', null), throwsA(isA<ApiException>()));
    book.setActor('admin');
    final students = await book.call('GET', '/api/v1/students', null) as List;
    expect(students.length, 240);
    final classes = await book.call('GET', '/api/v1/classes', null) as List;
    final grade8 = classes.cast<Map>().firstWhere((c) => c['name'] == '8-1');
    final class1 = classes.cast<Map>().firstWhere((c) => c['name'] == '1-1');
    final roll = (await book.call('GET', '/api/v1/students?class_id=${class1['id']}', null) as List).cast<Map>();
    expect(roll.map((s) => s['full_name']).toList(), [
      'Amanuel Araya',
      'Biniam Haile',
      'Delina Kifle',
      'Elsa Ogbe',
      'Genet Weldemichael',
      'Henok Beyene',
      'Makda Gebre',
      'Mussie Ghebretinsae',
      'Rahwa Mengistu',
      'Semere Tesfalem',
    ]);
    expect(roll.map((s) => s['roll_no']).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    final marked = await book.call('POST', '/api/v1/attendance/numbers', {'class_id': class1['id'], 'date': '2026-11-18', 'text': '2, 5'}) as Map;
    expect((marked['matched'] as List).map((row) => (row as Map)['full_name']).toList(), ['Biniam Haile', 'Genet Weldemichael']);
    expect(marked['unknown'], isEmpty);
    final day = await book.call('GET', '/api/v1/attendance?class_id=${class1['id']}&date=2026-11-18', null) as Map;
    final absent = (day['marks'] as List).cast<Map>().where((row) => row['present'] == false).toList();
    expect(absent.map((row) => row['roll_number']).toList(), [2, 5]);
    expect(absent.every((row) => row['class_id'] != null && row['student_id'] != null && row['date'] == '2026-11-18' && row['source_id'] == 'mac-demo' && '${row['updated_at']}'.isNotEmpty), isTrue);
    book.setActor('homeroom');
    final results = await book.call('GET', '/api/v1/classes/${grade8['id']}/results', null) as Map;
    final ranks = (results['students'] as List).map((row) => (row as Map)['standing']['rank'] as int).toList();
    expect(ranks.where((r) => r == 1).length, 1);
    expect(ranks.where((r) => r == 2).length, 2);
    expect(ranks.contains(3), isFalse);
    expect(ranks.contains(4), isTrue);
    book.setActor('admin');
    final sheet = await book.call('GET', '/api/v1/classes/${grade8['id']}/sheet', null) as Map;
    final tableRanks = (sheet['rows'] as List).where((row) => (row as Map)['rank'] is int).take(4).map((row) => (row as Map)['rank']).toList();
    expect(tableRanks, [1, 2, 2, 4]);
    final abel = (await book.call('GET', '/api/v1/search?q=Abel%20Tesfamariam', null) as List).cast<Map>().firstWhere((hit) => hit['name'] == 'Abel Tesfamariam');
    final profile = await book.call('GET', '/api/v1/students/${abel['id']}/sheet', null) as Map;
    final marks = (profile['marks'] as List).cast<Map>();
    expect(marks.every((mark) => (mark['total'] as num) > 0), isTrue);
    expect(marks.map((mark) => mark['total']).toSet().length, greaterThan(1));
    expect(profile['student']['father_name'].toString().startsWith('Tesfamariam '), isTrue);
    expect(profile['roll_no'], 1);
    expect(profile['class_name'], '8-1');
    book.setActor('subject');
    final lessons = (await book.call('GET', '/api/v1/class-subjects', null) as List).cast<Map>();
    final english = lessons.firstWhere((l) => l['class_name'] == '8-1' && l['subject_name'] == 'English');
    final assessments = (await book.call('GET', '/api/v1/assessments?class_subject_id=${english['id']}', null) as List).cast<Map>();
    final kept = await book.call('POST', '/api/v1/scores', {'assessment_id': assessments.first['id'], 'student_id': abel['id'], 'score': 1, 'updated_at': '2020-01-01T00:00:00'}) as Map;
    expect(kept['score'] == 1, isFalse);
    expect(kept['source_id'], 'mac-demo');
    book.setActor('admin');
    final pupil = (results['students'] as List).first as Map;
    book.setActor('homeroom');
    expect(
      () => book.call('POST', '/api/v1/students/${pupil['student']['id']}/dropout', {'dropped': true, 'reason': 'away', 'date': '2026-11-01'}),
      returnsNormally,
    );
    book.setActor('admin');
    expect(
      () => book.call('POST', '/api/v1/students/${pupil['student']['id']}/dropout', {'dropped': true, 'reason': '', 'date': '2026-11-01'}),
      throwsA(isA<ApiException>()),
    );
    book.setActor('homeroom');
    final fees = await book.call('GET', '/api/v1/fees?class_id=${grade8['id']}', null) as List;
    final owing = fees.cast<Map>().firstWhere((row) => (row['remaining'] as num) > 0);
    expect(
      () => book.call('POST', '/api/v1/fees', {'student_id': owing['student_id'], 'amount': (owing['remaining'] as num) + 1, 'paid_on': '2026-11-01'}),
      throwsA(isA<ApiException>()),
    );
    await book.call('POST', '/api/v1/fees', {'student_id': owing['student_id'], 'amount': 100, 'paid_on': '2026-11-01'});
    final again = await SchoolBook.open(directory: dir.path);
    again.setActor('homeroom');
    final saved = await again.call('GET', '/api/v1/fees?class_id=${grade8['id']}', null) as List;
    final same = saved.cast<Map>().firstWhere((row) => row['student_id'] == owing['student_id']);
    expect(same['paid'], (owing['paid'] as num) + 100);
    again.setActor('admin');
    await again.call('POST', '/api/v1/timetable/generate', {});
    final week = await again.call('GET', '/api/v1/timetable', null) as Map;
    expect((week['slots'] as List).isNotEmpty, isTrue);
    again.resetNow();
    again.setActor('admin');
    final fresh = await again.call('GET', '/api/v1/students', null) as List;
    expect(fresh.length, 240);
  });
}