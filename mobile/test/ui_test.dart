import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regstudent_mobile/main.dart';
import 'package:regstudent_mobile/registry.dart';
import 'scenarios.dart';

class MemoryApi extends RegistryApi {
  final List<Student> rows;
  bool offline = false;
  MemoryApi(this.rows) : super(Uri.parse('http://localhost'));
  @override
  Future<void> signIn(String login, String password) async {
    if (offline) throw const RegistryError('Серверге қосылу мүмкін болмады');
    loginName = login;
    admin = login == 'registrar';
  }

  @override
  Future<List<Student>> list() async => List.of(rows);
  @override
  Future<void> save(int? id, String name, String email, String cohort) async {
    if (rows.any((s) => s.email == email && s.id != id))
      throw const RegistryError('Бұл email тіркелген', 409);
    rows.removeWhere((s) => s.id == id);
    rows.add(Student(id ?? 2, name, email, cohort));
  }

  @override
  Future<void> remove(int id) async {
    rows.removeWhere((s) => s.id == id);
  }
}

void main() {
  testWidgets('Five screens, CRUD, validation, persistence and reader rights',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final rows = [const Student(1, 'Dana Ali', 'dana@example.test', 'IT-3')];
    const export = bool.fromEnvironment('CAPTURE');
    if (export) {
      final bytes = File(Platform.environment['LAB_FONT']!).readAsBytesSync();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
    await flows(t, () => MemoryApi(rows), 'temporary-test', (name) async {
      if (!export) return;
      final layer = t.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await t.runAsync(() async {
        final shot = await layer.toImage(pixelRatio: 1.5);
        final data = await shot.toByteData(format: ui.ImageByteFormat.png);
        Directory('shots').createSync();
        File('shots/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
        shot.dispose();
      });
    });
    expect(t.takeException(), isNull);
  });
  testWidgets('Narrow phone layout and retry after offline login', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = MemoryApi([])..offline = true;
    await t.pumpWidget(RegistryApp(api: api));
    await enter(t, 'login', 'registrar');
    await enter(t, 'password', 'example');
    await tap(t, 'enter');
    expect(find.text('Серверге қосылу мүмкін болмады'), findsOneWidget);
    api.offline = false;
    await tap(t, 'enter');
    await tap(t, 'browse');
    await tap(t, 'new');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(key('new'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
