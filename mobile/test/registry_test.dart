import 'package:flutter_test/flutter_test.dart';
import 'package:regstudent_mobile/registry.dart';

void main() {
  test('Names use Unicode code points and include both boundaries', () {
    expect(validateName(' '), isNotNull);
    expect(validateName('Ә'), isNull);
    expect(validateName('Ә' * 80), isNull);
    expect(validateName('A' * 81), isNotNull);
    expect(validateName('😀' * 80), isNull);
  });
  test('Email and group validation match supported forms', () {
    expect(validateEmail(' a@b.test '), isNull);
    expect(validateEmail('a@b'), isNotNull);
    expect(validateGroup('IT-3'), isNull);
    expect(validateGroup(''), isNotNull);
    expect(validateGroup('A' * 25), isNotNull);
  });
  test('Search trims and ignores case; sort leaves source order intact', () {
    final rows = [
      const Student(1, 'Dana', 'd@example.test', 'IT'),
      const Student(2, 'Aman', 'a@example.test', 'CS')
    ];
    expect(filtered(rows, ' AM ', true).single.id, 2);
    expect(filtered(rows, 'it', true).single.id, 1);
    expect(filtered(rows, '', true).first.id, 2);
    expect(filtered(rows, '', false).first.id, 1);
    expect(rows.first.id, 1);
  });
}
