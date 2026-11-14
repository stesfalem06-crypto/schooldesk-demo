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

  test('sample school keeps the rules and the edits', () async {
    final dir = Directory.systemTemp.createTempSync('sd-book');
    final book = await SchoolBook.open(directory: dir.path);
    expect(book.call('GET', '/api/v1/students', null), throwsA(isA<ApiException>()));
    book.setActor('admin');
    final students = await book.call('GET', '/api/v1/students', null) as List;
    expect(students.length, 200);
    final classes = await book.call('GET', '/api/v1/classes', null) as List;
    final grade8 = classes.cast<Map>().firstWhere((c) => c['name'] == 'Grade 8A');
    book.setActor('homeroom');
    final results = await book.call('GET', '/api/v1/classes/${grade8['id']}/results', null) as Map;
    final ranks = (results['students'] as List).map((row) => (row as Map)['standing']['rank'] as int).toList();
    expect(ranks.contains(1), isTrue);
    expect(ranks.where((r) => r == 3).length, 2);
    expect(ranks.contains(4), isFalse);
    expect(ranks.contains(5), isTrue);
    final pupil = (results['students'] as List).first as Map;
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
    expect(fresh.length, 200);
  });
}