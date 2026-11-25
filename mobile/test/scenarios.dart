import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regstudent_mobile/main.dart';
import 'package:regstudent_mobile/registry.dart';

typedef Capture = Future<void> Function(String name);
Finder key(String name) => find.byKey(ValueKey(name));
Future<void> tap(WidgetTester t, String name) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  final target = key(name);
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String name, String text) async {
  await t.ensureVisible(key(name));
  await t.enterText(key(name), text);
  await t.pumpAndSettle();
}

Future<void> signed(WidgetTester t, String user, String password) async {
  await enter(t, 'login', user);
  await enter(t, 'password', password);
  await tap(t, 'enter');
  await until(t, find.text('Студенттер тізілімі'));
}

Future<void> until(WidgetTester t, Finder target) async {
  for (int i = 0; i < 100 && target.evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(target, findsWidgets);
  await t.pumpAndSettle();
}

Future<void> flows(WidgetTester t, RegistryApi Function() api, String password,
    Capture capture) async {
  await t.pumpWidget(RegistryApp(api: api()));
  await t.pumpAndSettle();
  expect(
      t
          .widget<EditableText>(find.descendant(
              of: key('password'), matching: find.byType(EditableText)))
          .obscureText,
      true);
  await capture('01-login');
  await signed(t, 'registrar', password);
  await capture('02-home');
  await tap(t, 'browse');
  await until(t, find.text('Dana Ali'));
  await capture('03-directory');
  await tap(t, 'new');
  await capture('04-form');
  await tap(t, 'save');
  expect(find.text('Аты-жөнін енгізіңіз'), findsOneWidget);
  await enter(t, 'name', 'A' * 81);
  await enter(t, 'email', 'broken');
  await enter(t, 'cohort', 'A' * 25);
  await tap(t, 'save');
  expect(find.text('Ең көбі 80 таңба'), findsOneWidget);
  expect(find.text('Дұрыс email енгізіңіз'), findsOneWidget);
  expect(find.text('Топ атауы 1–24 таңба болуы керек'), findsOneWidget);
  await capture('06-invalid');
  await enter(t, 'name', 'Aman Nur');
  await enter(t, 'email', 'dana@example.test');
  await enter(t, 'cohort', 'IT-2');
  await tap(t, 'save');
  await until(t, find.text('Бұл email тіркелген'));
  await enter(t, 'email', 'aman@example.test');
  await tap(t, 'save');
  await until(t, key('new'));
  await until(t, find.text('Aman Nur'));
  await enter(t, 'search', ' AMAN ');
  expect(find.text('Aman Nur'), findsOneWidget);
  expect(find.text('Dana Ali'), findsNothing);
  await enter(t, 'search', 'absent');
  expect(find.text('Сәйкес жазба жоқ'), findsOneWidget);
  await enter(t, 'search', '');
  await tap(t, 'sort');
  expect(t.getTopLeft(find.text('Dana Ali')).dy,
      lessThan(t.getTopLeft(find.text('Aman Nur')).dy));
  await t.tap(find.text('Aman Nur'));
  await t.pumpAndSettle();
  await enter(t, 'cohort', 'IT-4');
  await tap(t, 'save');
  await until(t, key('new'));
  await until(t, find.textContaining('IT-4'));
  await tap(t, 'profileTab');
  await capture('05-profile');
  await tap(t, 'logout');
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  await t.pumpWidget(RegistryApp(api: api()));
  await t.pumpAndSettle();
  await signed(t, 'registrar', password);
  await tap(t, 'browse');
  await until(t, key('new'));
  await until(t, find.textContaining('IT-4'));
  await t.tap(find.text('Aman Nur'));
  await t.pumpAndSettle();
  await tap(t, 'delete');
  await tap(t, 'cancelDelete');
  expect(key('save'), findsOneWidget);
  await tap(t, 'delete');
  await tap(t, 'confirmDelete');
  await until(t, find.text('Dana Ali'));
  expect(find.text('Aman Nur'), findsNothing);
  await tap(t, 'profileTab');
  await tap(t, 'logout');
  await signed(t, 'observer', password);
  await tap(t, 'browse');
  await until(t, find.text('Dana Ali'));
  expect(key('new'), findsNothing);
  expect(t.widget<ListTile>(key('student-1')).onTap, isNull);
}
